-- 마주 열기: Couple 단위 하루 한 질문. 질문 문구는 생성 시점의 스냅샷으로 보존한다.
CREATE TABLE IF NOT EXISTS two_answers (
  id BIGINT NOT NULL AUTO_INCREMENT,
  couple_id INT NOT NULL,
  business_date DATE NOT NULL,
  question_id VARCHAR(64) NOT NULL,
  category VARCHAR(20) NOT NULL,
  question_text VARCHAR(300) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_two_answers_couple_date (couple_id, business_date),
  KEY idx_two_answers_couple_question (couple_id, question_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS two_answer_responses (
  id BIGINT NOT NULL AUTO_INCREMENT,
  two_answer_id BIGINT NOT NULL,
  couple_id INT NOT NULL,
  user_id INT NOT NULL,
  body VARCHAR(2000) NOT NULL,
  is_late TINYINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_two_answer_user (two_answer_id, user_id),
  KEY idx_two_answer_responses_couple (couple_id, two_answer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
