CREATE TABLE IF NOT EXISTS afterglow_visits (
  id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  map_pin_id INT NOT NULL,
  visit_date DATE NOT NULL,
  marked_by_user_id INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_afterglow_visit_pin (map_pin_id),
  INDEX idx_afterglow_visit_couple_date (couple_id, visit_date)
);

CREATE TABLE IF NOT EXISTS afterglow_contributions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  visit_id INT NOT NULL,
  user_id INT NOT NULL,
  setlog_post_id INT NULL,
  caption VARCHAR(120) NULL,
  emotion_tag VARCHAR(24) NULL,
  deleted_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_afterglow_contribution_user (visit_id, user_id),
  UNIQUE KEY uq_afterglow_contribution_post (setlog_post_id),
  INDEX idx_afterglow_contribution_visit (visit_id)
);
