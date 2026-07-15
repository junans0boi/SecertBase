ALTER TABLE Couples
  ADD COLUMN IF NOT EXISTS PairKey VARCHAR(64) NULL,
  ADD COLUMN IF NOT EXISTS Status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS ActivatedAt DATETIME NULL,
  ADD COLUMN IF NOT EXISTS DeactivatedAt DATETIME NULL,
  ADD COLUMN IF NOT EXISTS ReunionCount INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ReunionNoticeUser1SeenAt DATETIME NULL,
  ADD COLUMN IF NOT EXISTS ReunionNoticeUser2SeenAt DATETIME NULL,
  ADD COLUMN IF NOT EXISTS updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

UPDATE Couples
SET PairKey = CONCAT(LEAST(User1Id, User2Id), ':', GREATEST(User1Id, User2Id)),
    ActivatedAt = COALESCE(ActivatedAt, created_at)
WHERE PairKey IS NULL OR ActivatedAt IS NULL;

CREATE TEMPORARY TABLE provable_orphan_couples AS
SELECT history.couple_id,
       MIN(history.user_id) AS user1_id,
       MAX(history.user_id) AS user2_id
FROM (
  SELECT couple_id, user_id FROM setlog_posts
  WHERE couple_id IS NOT NULL AND user_id IS NOT NULL
  UNION ALL
  SELECT couple_id, user_id FROM map_pins
  WHERE couple_id IS NOT NULL AND user_id IS NOT NULL
) history
LEFT JOIN Couples existing ON existing.CoupleId = history.couple_id
WHERE existing.CoupleId IS NULL
GROUP BY history.couple_id
HAVING COUNT(DISTINCT history.user_id) = 2;

INSERT INTO Couples
  (CoupleId, RoomCode, RoomSecret, User1Id, User2Id, PairKey, Status,
   ActivatedAt, DeactivatedAt)
SELECT orphan.couple_id,
       CONCAT('archive_orphan_', orphan.couple_id),
       SHA2(CONCAT(UUID(), orphan.couple_id), 256),
       LEAST(orphan.user1_id, orphan.user2_id),
       GREATEST(orphan.user1_id, orphan.user2_id),
       CONCAT(LEAST(orphan.user1_id, orphan.user2_id), ':', GREATEST(orphan.user1_id, orphan.user2_id)),
       'inactive', NULL, CURRENT_TIMESTAMP
FROM provable_orphan_couples orphan
LEFT JOIN Couples same_pair
  ON same_pair.PairKey = CONCAT(LEAST(orphan.user1_id, orphan.user2_id), ':', GREATEST(orphan.user1_id, orphan.user2_id))
WHERE same_pair.CoupleId IS NULL;

DROP TEMPORARY TABLE provable_orphan_couples;

ALTER TABLE Couples MODIFY COLUMN PairKey VARCHAR(64) NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_couples_pair_key ON Couples (PairKey);
CREATE INDEX IF NOT EXISTS idx_couples_status_users ON Couples (Status, User1Id, User2Id);
