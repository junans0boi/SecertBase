-- Epic 3: Milestone item rewards + owned_items schema fix

-- 1. owned_items: couple_id → nullable, switch unique key to (user_id, item_id)
--    (skins are per-user since shop v2; couple_id was the old model)
ALTER TABLE owned_items MODIFY COLUMN couple_id INT NULL;

-- Drop old unique key (couple_id, item_id) — can't dedupe by user with it
ALTER TABLE owned_items DROP INDEX uq_owned;

-- New unique key: one of each item per user
ALTER TABLE owned_items
  ADD UNIQUE KEY IF NOT EXISTS uq_user_item (user_id, item_id);

-- 2. Track which milestone rewards have been claimed per couple
CREATE TABLE IF NOT EXISTS milestone_claims (
  id             BIGINT AUTO_INCREMENT PRIMARY KEY,
  couple_id      INT         NOT NULL,
  milestone_type VARCHAR(40) NOT NULL,
  item_id        INT         NOT NULL,
  claimed_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_couple_milestone (couple_id, milestone_type),
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE
);

-- 3. Fix StartDate for existing couples (use ActivatedAt as the couple start date)
--    d100/d200/d365 milestones were always null because StartDate was never set.
UPDATE Couples
  SET StartDate = DATE(ActivatedAt)
  WHERE StartDate IS NULL AND ActivatedAt IS NOT NULL;
