-- Epic 2: Level / Mission / Gacha system

-- 1. 가챠 티켓 컬럼 (wallets 테이블에 추가)
ALTER TABLE wallets
  ADD COLUMN IF NOT EXISTS gacha_tickets INT NOT NULL DEFAULT 0;

-- 2. 유저 레벨/XP
CREATE TABLE IF NOT EXISTS user_levels (
  user_id      INT  PRIMARY KEY,
  level        INT  NOT NULL DEFAULT 1,
  xp           INT  NOT NULL DEFAULT 0,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE
);

-- 3. 미션 템플릿 (서버 정의, 주간/달성)
CREATE TABLE IF NOT EXISTS mission_templates (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  type            ENUM('weekly','achievement') NOT NULL DEFAULT 'weekly',
  title           VARCHAR(80)  NOT NULL,
  description     VARCHAR(200) NOT NULL DEFAULT '',
  game            VARCHAR(20)  NULL,           -- null = 전체
  event_key       VARCHAR(40)  NOT NULL,       -- 'game_win','game_play','item_buy','gacha_pull'
  target_count    INT          NOT NULL DEFAULT 1,
  reward_coins    INT          NOT NULL DEFAULT 0,
  reward_tickets  INT          NOT NULL DEFAULT 0,
  reward_xp       INT          NOT NULL DEFAULT 100,
  active          TINYINT(1)   NOT NULL DEFAULT 1,
  sort_order      INT          NOT NULL DEFAULT 0
);

-- 4. 유저 미션 진행 상태
--    period_key: 주간미션은 'YYYY-WW', 달성미션은 'all'
CREATE TABLE IF NOT EXISTS user_missions (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT         NOT NULL,
  template_id INT         NOT NULL,
  period_key  VARCHAR(10) NOT NULL DEFAULT 'all',
  progress    INT         NOT NULL DEFAULT 0,
  claimed_at  DATETIME    NULL,
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_user_mission_period (user_id, template_id, period_key),
  FOREIGN KEY (user_id)     REFERENCES Users(UserId)             ON DELETE CASCADE,
  FOREIGN KEY (template_id) REFERENCES mission_templates(id) ON DELETE CASCADE
);

-- 5. 미션 템플릿 시드
INSERT IGNORE INTO mission_templates
  (id, type, title, description, game, event_key, target_count, reward_coins, reward_tickets, reward_xp, sort_order)
VALUES
  -- 주간 미션
  (1, 'weekly', '게임 5판 하기',          '이번 주 아무 게임이나 5판 플레이하세요',    NULL,      'game_play',  5,  500,  0, 100, 10),
  (2, 'weekly', '원카드 3판 이기기',        '이번 주 원카드에서 3번 승리하세요',         'onecard', 'game_win',   3,  300,  1, 150, 20),
  (3, 'weekly', '윷놀이 3판 이기기',        '이번 주 윷놀이에서 3번 승리하세요',         'yut',     'game_win',   3,  300,  1, 150, 30),
  (4, 'weekly', '상점 아이템 구매하기',     '이번 주 상점에서 아이템을 1개 구매하세요',  NULL,      'item_buy',   1,  200,  0, 80,  40),
  (5, 'weekly', '가챠 1회 뽑기',           '이번 주 가챠를 1회 뽑으세요',               NULL,      'gacha_pull', 1,  100,  0, 80,  50),
  -- 달성 미션 (누적)
  (10, 'achievement', '첫 게임 플레이',     '첫 번째 게임을 플레이하세요',               NULL,      'game_play',  1,  200,  1, 50,  1),
  (11, 'achievement', '게임 10판 달성',     '총 10판 게임을 플레이하세요',               NULL,      'game_play',  10, 500,  1, 100, 2),
  (12, 'achievement', '게임 50판 달성',     '총 50판 게임을 플레이하세요',               NULL,      'game_play',  50, 2000, 2, 200, 3),
  (13, 'achievement', '첫 승리',           '첫 번째 게임에서 승리하세요',               NULL,      'game_win',   1,  300,  1, 50,  4),
  (14, 'achievement', '10승 달성',         '총 10번 승리하세요',                        NULL,      'game_win',   10, 1000, 2, 150, 5),
  (15, 'achievement', '첫 가챠',           '가챠를 처음으로 뽑아보세요',                NULL,      'gacha_pull', 1,  500,  1, 50,  6);
