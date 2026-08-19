-- Older builds allowed more than one active play session for an account. Keep
-- only the most recently started one active before enforcing the invariant.
UPDATE play_sessions AS stale
SET ended_at = CAST(strftime('%s', 'now') AS INTEGER)
WHERE stale.ended_at IS NULL
  AND EXISTS (
      SELECT 1
      FROM play_sessions AS newer
      WHERE newer.user_id = stale.user_id
        AND newer.ended_at IS NULL
        AND (
            newer.started_at > stale.started_at
            OR (newer.started_at = stale.started_at AND newer.id > stale.id)
        )
  );

CREATE UNIQUE INDEX play_sessions_one_active_user_idx
    ON play_sessions(user_id) WHERE ended_at IS NULL;
