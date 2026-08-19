ALTER TABLE play_sessions
ADD COLUMN crediting_active INTEGER NOT NULL DEFAULT 0
    CHECK(crediting_active IN (0, 1));
