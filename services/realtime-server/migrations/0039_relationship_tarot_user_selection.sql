-- Distinguish a user's explicit card choice from legacy automatically seeded rows.
ALTER TABLE relationship_tarot_contents
  ADD COLUMN selected_by_user TINYINT(1) NOT NULL DEFAULT 0 AFTER card_key;
