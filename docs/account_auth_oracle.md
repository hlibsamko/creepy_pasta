# Google accounts on the Oracle game server

The account system is a separate Python service on the same Oracle VM as the
Godot dedicated server. It stores its SQLite database outside both deployment
directories, so replacing the game binary or Web export cannot erase account
data.

## Production topology

- Public Web/API origin: `https://creepy-pasta.duckdns.org`
- Public account routes: `/api/v1/*`, `/privacy`, and `/terms`
- Public game transport: `wss://creepy-pasta.duckdns.org`
- Account listener: `127.0.0.1:8080` (never exposed directly)
- Godot listener: `127.0.0.1:24567` (never exposed directly)
- Account service: `creepy-pasta-account.service`
- Database: `/var/lib/creepy-pasta/accounts.db`
- Daily backups: `/var/backups/creepy-pasta/accounts-*.db`
- Root-only account environment: `/etc/creepy-pasta/account.env`
- Root-only game bridge environment: `/etc/creepy-pasta/game-server.env`

Caddy is the only public application listener. Oracle VCN and host firewall
rules should allow `80` and `443` (plus administrative SSH `22`), not `24567`
or `8080`.

## Authentication flow

1. The Web client asks the account API to start a Google OpenID Connect login.
2. It opens Google's authorization page in a separate browser window and polls
   the API with a one-time, high-entropy poll token.
3. Google returns an authorization code to
   `https://creepy-pasta.duckdns.org/api/v1/auth/google/callback`.
4. The account service validates state, PKCE, nonce, the signed ID token,
   issuer, exact audience, lifetime, and verified email. Google `sub`, not the
   email address, is the permanent identity key.
5. The service discards the Google tokens and issues opaque Creepy Pasta access
   and refresh tokens. Only their SHA-256 hashes are stored. The current Web
   client keeps both tokens in memory and requires a new login after a reload.
6. Before opening WSS, the client creates a 60-second, single-use game ticket.
   The Godot server redeems it over loopback and maps the transient peer ID to
   the account UUID. All other client RPCs are rejected until this succeeds.

The implementation requests only `openid email profile`. It never receives a
Google password and does not keep a Google access or refresh token.

Google reference documentation:

- <https://developers.google.com/identity/openid-connect/openid-connect>
- <https://developers.google.com/identity/protocols/oauth2/policies>

## Google Cloud setup

Create a Google OAuth client for a Web application. Configure:

- Authorized JavaScript origin:
  `https://creepy-pasta.duckdns.org`
- Authorized redirect URI:
  `https://creepy-pasta.duckdns.org/api/v1/auth/google/callback`
- Homepage:
  `https://creepy-pasta.duckdns.org`
- Privacy policy:
  `https://creepy-pasta.duckdns.org/privacy`
- Terms:
  `https://creepy-pasta.duckdns.org/terms`

Keep the client secret outside the repository. A supported local input file is:

```text
CREEPY_GOOGLE_CLIENT_ID="...apps.googleusercontent.com"
CREEPY_GOOGLE_CLIENT_SECRET="..."
```

Save it outside the project (or as `deploy/*.local.env`, which is ignored),
restrict its ACL, and deploy with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_full_oracle.ps1 `
  -AccountEnvPath 'D:\private\creepy-pasta-google.local.env'
```

For infrastructure preparation before Google credentials exist, the account
service alone may be installed in explicit setup-pending mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_account.ps1 `
  -AllowSetupPending
```

`/healthz` remains healthy in that mode, while `/readyz` returns `503` and login
start returns `503`. Do not deploy the authenticated Web/game release as a
working production release until the real Google credentials are installed.

## Stored account data and trust boundaries

SQLite stores the Google subject mapping, private verified-email snapshot,
display name/avatar URL, random friend code, hashed sessions, friend requests
and friendships, verified online play seconds, death count, achievements,
one-time tickets, play sessions, and idempotent progress events.

Friends are added by an explicit request/accept flow using an exact random
friend code. Email and display-name search are deliberately unavailable.

Playtime is credited from server-owned heartbeats only while the account is a
member of a non-finished online game session; lobby, finished-screen, disconnected,
and offline time is not uploaded as verified time. Credit is capped when heartbeats
are missed. Deaths are counted
only at a server-authoritative kill decision; currently that means The Unlit's
online contact kill. Other monsters remain client-authoritative and therefore
do not increment the trusted counter yet. Achievement and death event IDs make
retries idempotent.

Seeded achievements are `first_record`, `first_death`, `field_researcher`, and
`escaped`.

## Verification and operations

Run the backend tests and deployment validation without changing Oracle:

```powershell
python -B -m unittest discover -s .\backend\tests -t .\backend -v
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_account.ps1 `
  -ValidateOnly -AllowSetupPending
```

After a real deployment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\smoke_account.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\smoke_test_server.ps1
```

Inspect the services without printing their environment files:

```bash
sudo systemctl status creepy-pasta-account creepy-pasta-server caddy
sudo journalctl -u creepy-pasta-account --since=-15min --no-pager
sudo systemctl status creepy-pasta-account-backup.timer
```

The backup timer uses SQLite's online backup API and keeps the newest 14 daily
snapshots. Test restores on a separate path. To restore production, stop the
account and game services, make an additional copy of the current database and
its WAL/SHM files, install a verified snapshot as
`/var/lib/creepy-pasta/accounts.db` owned by `creepy-pasta-account` with mode
`0600`, then restart the account service before the game service.
