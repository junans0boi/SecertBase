CREATE TABLE IF NOT EXISTS today_loop_views (
  id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  user_id INT NOT NULL,
  business_date DATE NOT NULL,
  viewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_today_loop_view (couple_id, user_id, business_date),
  INDEX idx_today_loop_view_couple_date (couple_id, business_date)
);
