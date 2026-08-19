CREATE TABLE users (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL CHECK(length(display_name) BETWEEN 1 AND 64),
    avatar_url TEXT,
    friend_code TEXT NOT NULL UNIQUE CHECK(length(friend_code) = 19),
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'disabled', 'deleted')),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    last_login_at INTEGER NOT NULL
) STRICT;

CREATE TABLE oauth_identities (
    provider TEXT NOT NULL,
    provider_subject TEXT NOT NULL,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email_snapshot TEXT,
    email_verified INTEGER NOT NULL DEFAULT 0 CHECK(email_verified IN (0, 1)),
    created_at INTEGER NOT NULL,
    last_login_at INTEGER NOT NULL,
    PRIMARY KEY(provider, provider_subject)
) STRICT;
CREATE INDEX oauth_identities_user_idx ON oauth_identities(user_id);

CREATE TABLE oauth_login_attempts (
    id TEXT PRIMARY KEY,
    state_hash BLOB NOT NULL UNIQUE CHECK(length(state_hash) = 32),
    poll_token_hash BLOB NOT NULL CHECK(length(poll_token_hash) = 32),
    nonce TEXT NOT NULL CHECK(length(nonce) BETWEEN 32 AND 256),
    code_verifier TEXT NOT NULL CHECK(length(code_verifier) BETWEEN 43 AND 128),
    status TEXT NOT NULL CHECK(status IN ('pending', 'exchanging', 'complete', 'failed')),
    user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    error_code TEXT,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    completed_at INTEGER,
    consumed_at INTEGER
) STRICT;
CREATE INDEX oauth_login_attempts_expiry_idx ON oauth_login_attempts(expires_at);

CREATE TABLE auth_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    access_token_hash BLOB NOT NULL UNIQUE CHECK(length(access_token_hash) = 32),
    refresh_token_hash BLOB NOT NULL UNIQUE CHECK(length(refresh_token_hash) = 32),
    access_expires_at INTEGER NOT NULL,
    refresh_expires_at INTEGER NOT NULL,
    token_family_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    revoked_at INTEGER,
    replaced_by TEXT REFERENCES auth_sessions(id) ON DELETE SET NULL
) STRICT;
CREATE INDEX auth_sessions_user_idx ON auth_sessions(user_id);
CREATE INDEX auth_sessions_family_idx ON auth_sessions(token_family_id);
CREATE INDEX auth_sessions_refresh_idx ON auth_sessions(refresh_token_hash);

CREATE TABLE player_stats (
    user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    verified_playtime_seconds INTEGER NOT NULL DEFAULT 0 CHECK(verified_playtime_seconds >= 0),
    death_count INTEGER NOT NULL DEFAULT 0 CHECK(death_count >= 0),
    updated_at INTEGER NOT NULL
) STRICT;

CREATE TABLE achievement_definitions (
    code TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    hidden INTEGER NOT NULL DEFAULT 0 CHECK(hidden IN (0, 1)),
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1))
) STRICT;

INSERT INTO achievement_definitions(code, title, description, hidden, active) VALUES
    ('first_record', 'First Record', 'Recover your first record.', 0, 1),
    ('first_death', 'First Death', 'Die for the first time.', 0, 1),
    ('field_researcher', 'Field Researcher', 'Complete the field research objective.', 0, 1),
    ('escaped', 'Escaped', 'Escape the final room.', 0, 1);

CREATE TABLE user_achievements (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_code TEXT NOT NULL REFERENCES achievement_definitions(code) ON DELETE RESTRICT,
    unlocked_at INTEGER NOT NULL,
    source_event_id TEXT NOT NULL,
    PRIMARY KEY(user_id, achievement_code)
) STRICT;

CREATE TABLE friend_requests (
    id TEXT PRIMARY KEY,
    requester_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pair_low_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pair_high_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK(status IN ('pending', 'accepted', 'declined', 'cancelled')),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    responded_at INTEGER,
    CHECK(requester_id <> recipient_id),
    CHECK(pair_low_id < pair_high_id)
) STRICT;
CREATE UNIQUE INDEX friend_requests_pending_pair_idx
    ON friend_requests(pair_low_id, pair_high_id) WHERE status = 'pending';
CREATE INDEX friend_requests_recipient_idx ON friend_requests(recipient_id, status);
CREATE INDEX friend_requests_requester_idx ON friend_requests(requester_id, status);

CREATE TABLE friendships (
    user_low_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_high_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    CHECK(user_low_id < user_high_id),
    PRIMARY KEY(user_low_id, user_high_id)
) STRICT;

CREATE TABLE user_blocks (
    blocker_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    CHECK(blocker_id <> blocked_id),
    PRIMARY KEY(blocker_id, blocked_id)
) STRICT;

CREATE TABLE game_tickets (
    token_hash BLOB PRIMARY KEY CHECK(length(token_hash) = 32),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    consumed_at INTEGER
) STRICT;
CREATE INDEX game_tickets_expiry_idx ON game_tickets(expires_at);

CREATE TABLE play_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_server_id TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    last_heartbeat_at INTEGER NOT NULL,
    last_credited_at INTEGER NOT NULL,
    credited_seconds INTEGER NOT NULL DEFAULT 0 CHECK(credited_seconds >= 0),
    ended_at INTEGER
) STRICT;
CREATE INDEX play_sessions_user_idx ON play_sessions(user_id, started_at);

CREATE TABLE progress_events (
    play_session_id TEXT NOT NULL REFERENCES play_sessions(id) ON DELETE CASCADE,
    event_id TEXT NOT NULL,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK(event_type IN ('death', 'achievement')),
    achievement_code TEXT REFERENCES achievement_definitions(code) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL,
    PRIMARY KEY(play_session_id, event_id),
    CHECK(
        (event_type = 'death' AND achievement_code IS NULL) OR
        (event_type = 'achievement' AND achievement_code IS NOT NULL)
    )
) STRICT;
CREATE INDEX progress_events_user_idx ON progress_events(user_id, created_at);
