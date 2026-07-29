CREATE TABLE IF NOT EXISTS today_moments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  user_id INT NOT NULL,
  business_date DATE NOT NULL,
  setlog_post_id INT NULL,
  selected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revealed_at DATETIME NULL,
  deleted_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_today_moment_user_date (couple_id, user_id, business_date),
  UNIQUE KEY uq_today_moment_post (setlog_post_id),
  INDEX idx_today_moment_couple_date (couple_id, business_date),
  INDEX idx_today_moment_post (setlog_post_id)
);
