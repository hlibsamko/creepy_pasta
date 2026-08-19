# Creepy Pasta account service

This directory contains a dependency-free Python 3.12 HTTP service for Google-backed
game accounts. It owns account persistence; the Godot client and dedicated server
must never open its SQLite database directly.

## Runtime

Run from this directory so the package and migration files are available:

```bash
cd backend
python3 -m creepy_accounts
```

Production should run it as an unprivileged systemd user, bind it to
`127.0.0.1:8080`, and let Caddy proxy `/api/*` without stripping the `/api` prefix.
Do not proxy `/internal/*`; those endpoints additionally require a loopback source
and `X-Internal-Secret`.

Required environment variables:

- `CREEPY_ACCOUNT_DB_PATH` — production recommendation:
  `/var/lib/creepy-pasta/accounts.db`.
- `CREEPY_ACCOUNT_PUBLIC_BASE_URL` — e.g.
  `https://creepy-pasta.duckdns.org`; it determines the exact Google callback URL.
- `CREEPY_GOOGLE_CLIENT_ID` and `CREEPY_GOOGLE_CLIENT_SECRET` — a Google OAuth
  **Web application** client whose authorized redirect URI is
  `<public-base-url>/api/v1/auth/google/callback`.
- `CREEPY_ACCOUNT_INTERNAL_SECRET` — at least 32 random characters, delivered via a
  root-readable systemd environment/credential file and shared only with the Godot
  dedicated server.
- `CREEPY_ACCOUNT_ALLOWED_ORIGINS` — comma-separated exact browser origins, normally
  `https://creepy-pasta.duckdns.org`.

Optional environment variables:

- `CREEPY_ACCOUNT_BIND_HOST` (default `127.0.0.1`) and
  `CREEPY_ACCOUNT_PORT` (default `8080`).
- `CREEPY_ACCOUNT_ALLOW_SETUP_PENDING=1` allows the process to start before Google
  credentials exist. `/healthz`, `/privacy`, and `/terms` remain available;
  `/readyz` returns `503 setup_pending` and login fails closed. The internal secret
  is still mandatory.
- `CREEPY_ACCOUNT_ACCESS_TTL_SECONDS` (default 900),
  `CREEPY_ACCOUNT_REFRESH_TTL_SECONDS` (default 2592000),
  `CREEPY_ACCOUNT_LOGIN_TTL_SECONDS` (default 600), and
  `CREEPY_ACCOUNT_TICKET_TTL_SECONDS` (default 60).
- `CREEPY_ACCOUNT_HEARTBEAT_CREDIT_CAP_SECONDS` (default 120) limits playtime that
  can be credited after a missed heartbeat.
- `CREEPY_ACCOUNT_PLAY_SESSION_IDLE_TTL_SECONDS` (default 600) expires a play
  session that stops sending heartbeats.
- `CREEPY_ACCOUNT_MAX_BODY_BYTES` (default 16384),
  `CREEPY_GOOGLE_HTTP_TIMEOUT_SECONDS` (default 10), and
  `CREEPY_ACCOUNT_CONTACT_EMAIL`.

The database uses WAL mode, foreign keys, strict tables, transactional migrations,
opaque credentials stored only as SHA-256 hashes, rotating refresh sessions, and
single-use game tickets. Back up the database plus WAL consistently (for example
with SQLite's online backup command), never by copying only the main file while the
service is active.

## HTTP contract

The service accepts and returns JSON unless noted. Every JSON `POST` requires
`Content-Type: application/json` and a bounded `Content-Length`. Unknown request
fields are rejected. Public authenticated methods use
`Authorization: Bearer <access_token>`.

Public endpoints:

- `POST /api/v1/auth/google/start` with `{}` returns `login_id`, `poll_token`, and
  `authorization_url`. Open the URL in the user's system browser.
- `GET /api/v1/auth/google/callback?code=...&state=...` is called by Google and
  returns only a browser-safe HTML result. It never exposes game credentials.
- `POST /api/v1/auth/google/poll` with `{login_id,poll_token}` returns `202` while
  pending and, once, returns account access/refresh credentials when complete.
- `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`, `GET /api/v1/me`, and
  `GET /api/v1/me/progress`.
- `POST /api/v1/game-tickets` with `{}` creates a 60-second one-use ticket.
- `GET /api/v1/friends`, `GET /api/v1/friend-requests`,
  `POST /api/v1/friend-requests`, `POST /api/v1/friend-requests/accept`,
  `POST /api/v1/friend-requests/decline`, and
  `DELETE /api/v1/friends/{friend_code}`.
- `GET /healthz`, `GET /readyz`, `GET /privacy`, and `GET /terms`. The legal pages
  are also available through the Caddy-guaranteed aliases `/api/v1/privacy` and
  `/api/v1/terms`.

Exact successful response bodies (timestamps are Unix seconds):

```text
POST /api/v1/auth/google/start {}
201 {"login_id":"uuid","poll_token":"opaque","authorization_url":"https://...","expires_in":600}

POST /api/v1/auth/google/poll {"login_id":"uuid","poll_token":"opaque"}
202 {"status":"pending"}
200 {"status":"complete","access_token":"opaque","access_expires_in":900,
     "refresh_token":"opaque","refresh_expires_in":2592000,"user":User}

POST /api/v1/auth/refresh {"refresh_token":"opaque"}
200 {"access_token":"opaque","access_expires_in":900,"refresh_token":"opaque",
     "refresh_expires_in":2592000,"user":User}

POST /api/v1/auth/logout {}       -> 204 empty
GET  /api/v1/me                   -> 200 User (also includes the signed-in user's email)
GET  /api/v1/me/progress          -> 200 Progress
POST /api/v1/game-tickets {}      -> 201 {"ticket":"opaque","expires_in":60,"expires_at":...}
GET  /api/v1/friends              -> 200 {"friends":[Friend,...]}
GET  /api/v1/friend-requests      -> 200 {"incoming":[Friend,...],"outgoing":[Friend,...],
                                           "friend_requests":[Friend,...]}
POST /api/v1/friend-requests {"friend_code":"CP-..."}
                                    -> 201/200 {"status":"pending","created":true/false,"user":Friend}
POST /api/v1/friend-requests/accept {"friend_code":"CP-..."}
                                    -> 200 {"status":"accepted","user":Friend}
POST /api/v1/friend-requests/decline {"friend_code":"CP-..."}
                                    -> 200 {"status":"declined","user":Friend}
DELETE /api/v1/friends/{friend_code} -> 204 empty
```

`User` is `{id,display_name,avatar_url,friend_code}`. `Friend` uses the same public
fields and may add `requested_at` or `friends_since`. `Progress` is
`{verified_playtime_seconds,death_count,achievements}`; each unlocked achievement is
`{code,title,description,unlocked_at}`.

Failures use an appropriate 4xx/5xx status and this bounded shape; secrets are never
placed in the error or request log:

```json
{"error":"stable_machine_code","message":"Safe human-readable message","request_id":"hex"}
```

Internal endpoints (loopback plus `X-Internal-Secret`):

- `POST /internal/v1/game-tickets/redeem` with `{ticket}` returns
  `{user,play_session_id}`. Optional `X-Game-Server-ID` identifies the server. A
  successful reconnect atomically supersedes that account's previous active play
  session; concurrent redeems still leave exactly one active session.
- `POST /internal/v1/play-sessions/{id}/heartbeat` with the required Boolean
  `{active}`. The call always keeps the session alive, but its elapsed interval is
  credited according to the previously reported activity state, then `active`
  becomes the state for the next interval. New sessions begin inactive; the
  dedicated server should send true when gameplay starts and false when it enters
  the lobby or a run finishes.
- `POST /internal/v1/play-sessions/{id}/events` with
  `{event_id,type,achievement_code?}`. Types are `death` and `achievement`;
  duplicate event IDs are successful no-ops. Unknown achievement codes are also
  non-fatal no-ops. The first accepted `death` event atomically unlocks
  `first_death` with that same event ID as its source.
- `POST /internal/v1/play-sessions/{id}/end` with `{}`.

Heartbeat and event calls fail with `410 play_session_expired` after the configured
idle timeout. Ending such a session is safe and credits no unattended time.

Exact principal internal responses are:

```text
POST /internal/v1/game-tickets/redeem {"ticket":"opaque"}
200 {"user":{"id":"uuid","display_name":"...","avatar_url":null,"friend_code":"CP-..."},
     "play_session_id":"uuid"}

POST /internal/v1/play-sessions/{id}/heartbeat {"active":true}
200 {"active":true,"credited_seconds":60,"session_credited_seconds":120,
     "verified_playtime_seconds":120}

POST /internal/v1/play-sessions/{id}/events {"event_id":"unique","type":"death"}
POST /internal/v1/play-sessions/{id}/events
     {"event_id":"unique","type":"achievement","achievement_code":"first_record"}
200 {"applied":true,"duplicate":false,...}

POST /internal/v1/play-sessions/{id}/end {}
200 {"ended":true,"credited_seconds":...,"session_credited_seconds":...,
     "verified_playtime_seconds":...}
```

Seeded achievement codes are `first_record`, `first_death`, `field_researcher`, and
`escaped`.

For compatibility with the current Godot client, `POST /api/v1/logout` aliases the
canonical `/api/v1/auth/logout`; progress also includes `verified_play_seconds` and
`deaths` aliases, incoming request lists are repeated as `friend_requests`, and a
game-ticket response includes both `expires_in` and the Unix timestamp `expires_at`.

## Tests

The tests make no Google or other network calls:

```bash
cd backend
python3 -m unittest discover -s tests -v
```

The privacy notice and terms are operational starting points and should receive the
project owner's legal review before a public launch.
