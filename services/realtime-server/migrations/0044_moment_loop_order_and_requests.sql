-- Position is local to one author's upload group. Re-running this SQL must not
-- overwrite a user's later ordering, even though numbered migrations run once.
SET @backfill_moment_positions = (
  SELECT COUNT(*) = 0 FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'setlog_posts' AND COLUMN_NAME = 'position'
);

ALTER TABLE setlog_posts
  ADD COLUMN IF NOT EXISTS position SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS client_request_id VARCHAR(64) COLLATE utf8mb4_bin DEFAULT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_req ON setlog_posts (user_id, client_request_id);

-- A legacy standalone record gets its own stable group, without merging it
-- with unrelated NULL sessions or changing any existing reaction/session key.
UPDATE setlog_posts SET session_id = CONCAT('legacy-post-', id)
WHERE @backfill_moment_positions AND (session_id IS NULL OR TRIM(session_id) = '');

UPDATE setlog_posts p
JOIN (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY couple_id, user_id, session_id ORDER BY id
  ) - 1 AS ordered_position
  FROM setlog_posts
) ranked ON ranked.id = p.id
SET p.position = ranked.ordered_position
WHERE @backfill_moment_positions;
