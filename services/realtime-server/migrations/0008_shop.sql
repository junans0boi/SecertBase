-- Shop items catalog (static; seeded below)
CREATE TABLE IF NOT EXISTS shop_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  category ENUM('skin','booster','gacha','coupon') NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  price INT NOT NULL DEFAULT 0,
  icon VARCHAR(50),               -- emoji or asset key
  metadata JSON,                  -- extra config (e.g. coupon template id)
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Owned items per couple
CREATE TABLE IF NOT EXISTS owned_items (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  item_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  acquired_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES shop_items(id),
  INDEX idx_owned_couple (couple_id),
  UNIQUE KEY uq_owned (couple_id, item_id)
);

-- Date coupons issued between couple members
CREATE TABLE IF NOT EXISTS date_coupons (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  issuer_user_code VARCHAR(10) NOT NULL,   -- who created/gave the coupon
  receiver_user_code VARCHAR(10) NOT NULL, -- who received it
  template_id INT,                         -- NULL for custom
  title VARCHAR(100) NOT NULL,
  description TEXT,
  status ENUM('pending','redeemed','expired') NOT NULL DEFAULT 'pending',
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,            -- issued_at + 30 days
  redeemed_at DATETIME,
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE,
  INDEX idx_dc_couple (couple_id),
  INDEX idx_dc_receiver (receiver_user_code, status)
);

-- Seed default shop items
INSERT IGNORE INTO shop_items (id, category, name, description, price, icon) VALUES
  (1,  'coupon',  '데이트 쿠폰',     '상대방에게 주는 특별한 약속 쿠폰', 500,  '🎟️'),
  (2,  'booster', '데일리 보너스 2배', '오늘 하루 데일리 보너스 2배 지급', 1000, '⚡'),
  (3,  'skin',    '황금 윷',         '윷놀이 말 황금 스킨',              2000, '✨'),
  (4,  'skin',    '꽃 테마',          '게임 배경 꽃 테마',                3000, '🌸'),
  (5,  'gacha',   '아이템 뽑기',      '랜덤 아이템 1개 획득',             800,  '🎰');
