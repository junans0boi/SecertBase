ALTER TABLE map_pins
  ADD COLUMN IF NOT EXISTS archived_at DATETIME NULL,
  ADD INDEX IF NOT EXISTS idx_map_couple_active (couple_id, archived_at);
