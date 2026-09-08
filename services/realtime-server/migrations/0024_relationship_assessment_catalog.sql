-- 관계 이해 심리검사 카탈로그의 버전·차원·문항 pool을 정의한다.
CREATE TABLE IF NOT EXISTS relationship_assessment_catalog (
  assessment_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  audience ENUM('individual', 'couple') NOT NULL,
  title VARCHAR(120) NOT NULL,
  description VARCHAR(255) NOT NULL DEFAULT '',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS relationship_assessment_versions (
  version_id INT AUTO_INCREMENT PRIMARY KEY,
  assessment_id INT NOT NULL,
  version_label VARCHAR(32) NOT NULL,
  candidate_question_count INT NOT NULL,
  active_question_count INT NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_assessment_version (assessment_id, version_label),
  FOREIGN KEY (assessment_id) REFERENCES relationship_assessment_catalog(assessment_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS relationship_assessment_dimensions (
  dimension_id INT AUTO_INCREMENT PRIMARY KEY,
  version_id INT NOT NULL,
  dimension_key VARCHAR(64) NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  sort_order INT NOT NULL,
  UNIQUE KEY uq_relationship_assessment_dimension (version_id, dimension_key),
  FOREIGN KEY (version_id) REFERENCES relationship_assessment_versions(version_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS relationship_assessment_questions (
  question_id INT AUTO_INCREMENT PRIMARY KEY,
  version_id INT NOT NULL,
  question_key VARCHAR(64) NOT NULL,
  prompt VARCHAR(500) NOT NULL,
  dimension_id INT NOT NULL,
  reverse_scored TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 0,
  question_order INT NOT NULL,
  UNIQUE KEY uq_relationship_assessment_question (version_id, question_key),
  INDEX idx_relationship_assessment_active_questions (version_id, is_active, question_order),
  FOREIGN KEY (version_id) REFERENCES relationship_assessment_versions(version_id) ON DELETE CASCADE,
  FOREIGN KEY (dimension_id) REFERENCES relationship_assessment_dimensions(dimension_id) ON DELETE CASCADE
);

INSERT IGNORE INTO relationship_assessment_catalog
  (code, audience, title, description, sort_order)
VALUES
  ('attachment', 'individual', '애착과 안정감', '가까운 관계에서 안정감을 느끼고 표현하는 방식을 살펴봅니다.', 10),
  ('social_bonding', 'individual', '사회적 유대와 연결', '관계를 맺고 깊이를 느끼며 혼자임을 알아차리는 방식을 살펴봅니다.', 20),
  ('emotional_regulation', 'individual', '감정 해소와 조절', '감정을 안에서 처리하거나 외부 자극과 대화로 풀어내는 경향을 살펴봅니다.', 30),
  ('relationship_deficiency', 'individual', '관계의 결핍 인식', '관계에서 느끼는 부족함과 기대, 다른 지지 자원을 인식하는 방식을 살펴봅니다.', 40),
  ('conflict_repair', 'couple', '갈등과 회복 방식', '갈등이 생겼을 때 반응하고 다시 연결되는 두 사람의 방식을 살펴봅니다.', 50),
  ('togetherness_personal_time', 'couple', '함께 있음과 개인 시간', '함께 보내는 시간과 각자의 자율성을 조율하는 방식을 살펴봅니다.', 60),
  ('affection_alignment', 'couple', '애정 표현과 기대의 일치', '사랑을 표현하고 받아들이는 방식이 얼마나 맞닿아 있는지 살펴봅니다.', 70);

INSERT IGNORE INTO relationship_assessment_versions
  (assessment_id, version_label, candidate_question_count, active_question_count)
SELECT assessment_id, 'v1', 24, 12
FROM relationship_assessment_catalog
WHERE is_active = 1;

INSERT IGNORE INTO relationship_assessment_dimensions
  (version_id, dimension_key, display_name, sort_order)
SELECT v.version_id, seed.dimension_key, seed.display_name, seed.sort_order
FROM relationship_assessment_versions v
JOIN relationship_assessment_catalog a ON a.assessment_id = v.assessment_id
JOIN (
  SELECT 'attachment' AS code, 'reassurance' AS dimension_key, '확인과 안심' AS display_name, 1 AS sort_order UNION ALL
  SELECT 'attachment' AS code, 'distance' AS dimension_key, '거리와 자율성' AS display_name, 2 AS sort_order UNION ALL
  SELECT 'attachment' AS code, 'expression' AS dimension_key, '감정 표현' AS display_name, 3 AS sort_order UNION ALL
  SELECT 'social_bonding' AS code, 'depth' AS dimension_key, '관계의 깊이' AS display_name, 1 AS sort_order UNION ALL
  SELECT 'social_bonding' AS code, 'dependence' AS dimension_key, '의존과 균형' AS display_name, 2 AS sort_order UNION ALL
  SELECT 'social_bonding' AS code, 'isolation' AS dimension_key, '고립감 인식' AS display_name, 3 AS sort_order UNION ALL
  SELECT 'emotional_regulation' AS code, 'internal' AS dimension_key, '내부 처리' AS display_name, 1 AS sort_order UNION ALL
  SELECT 'emotional_regulation' AS code, 'stimulation' AS dimension_key, '외부 자극' AS display_name, 2 AS sort_order UNION ALL
  SELECT 'emotional_regulation' AS code, 'dialogue' AS dimension_key, '대화 선호' AS display_name, 3 AS sort_order UNION ALL
  SELECT 'relationship_deficiency' AS code, 'self_awareness' AS dimension_key, '자기 인식' AS display_name, 1 AS sort_order UNION ALL
  SELECT 'relationship_deficiency' AS code, 'partner_expectation' AS dimension_key, '파트너 기대' AS display_name, 2 AS sort_order UNION ALL
  SELECT 'relationship_deficiency' AS code, 'alternative_resources' AS dimension_key, '대안 자원 인식' AS display_name, 3 AS sort_order UNION ALL
  SELECT 'conflict_repair' AS code, 'conflict_signal' AS dimension_key, '갈등 신호' AS display_name, 1 AS sort_order UNION ALL
  SELECT 'conflict_repair' AS code, 'repair_action' AS dimension_key, '회복 행동' AS display_name, 2 AS sort_order UNION ALL
  SELECT 'conflict_repair' AS code, 'safety' AS dimension_key, '대화 안전감' AS display_name, 3 AS sort_order UNION ALL
  SELECT 'togetherness_personal_time' AS code, 'togetherness' AS dimension_key, '함께 있음' AS display_name, 1 AS sort_order UNION ALL
  SELECT 'togetherness_personal_time' AS code, 'personal_time' AS dimension_key, '개인 시간' AS display_name, 2 AS sort_order UNION ALL
  SELECT 'togetherness_personal_time' AS code, 'coordination' AS dimension_key, '조율' AS display_name, 3 AS sort_order UNION ALL
  SELECT 'affection_alignment' AS code, 'expression' AS dimension_key, '애정 표현' AS display_name, 1 AS sort_order UNION ALL
  SELECT 'affection_alignment' AS code, 'expectation' AS dimension_key, '기대' AS display_name, 2 AS sort_order UNION ALL
  SELECT 'affection_alignment' AS code, 'alignment' AS dimension_key, '일치와 조율' AS display_name, 3 AS sort_order
) seed ON seed.code = a.code
WHERE v.version_label = 'v1' AND v.is_active = 1;

INSERT IGNORE INTO relationship_assessment_questions
  (version_id, question_key, prompt, dimension_id, reverse_scored, is_active, question_order)
SELECT v.version_id,
       CONCAT('q', LPAD(seed.question_number, 2, '0')),
       seed.prompt,
       d.dimension_id,
       seed.reverse_scored,
       seed.is_active,
       seed.question_number
FROM relationship_assessment_versions v
JOIN relationship_assessment_catalog a ON a.assessment_id = v.assessment_id
JOIN (
  SELECT 'attachment' AS code, 1 AS question_number, '상대의 답장이 늦으면 무슨 일이 있는지 걱정된다.' AS prompt, 'reassurance' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 2 AS question_number, '관계가 안정적인지 말이나 행동으로 확인받고 싶다.' AS prompt, 'reassurance' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 3 AS question_number, '상대가 다른 사람과 가까워지면 불안해진다.' AS prompt, 'reassurance' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 4 AS question_number, '다툰 뒤 상대가 먼저 다가오면 안심된다.' AS prompt, 'reassurance' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 5 AS question_number, '비슷한 상황이 반복될 때도 상대의 답장이 늦으면 무슨 일이 있는지 걱정된다.' AS prompt, 'reassurance' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 6 AS question_number, '비슷한 상황이 반복될 때도 관계가 안정적인지 말이나 행동으로 확인받고 싶다.' AS prompt, 'reassurance' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 7 AS question_number, '비슷한 상황이 반복될 때도 상대가 다른 사람과 가까워지면 불안해진다.' AS prompt, 'reassurance' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 8 AS question_number, '비슷한 상황이 반복될 때도 다툰 뒤 상대가 먼저 다가오면 안심된다.' AS prompt, 'reassurance' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 9 AS question_number, '상대가 혼자만의 시간을 원하면 존중할 수 있다.' AS prompt, 'distance' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 10 AS question_number, '나만의 시간과 취미를 꾸준히 유지한다.' AS prompt, 'distance' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 11 AS question_number, '갈등이 생겨도 잠시 거리를 두고 생각할 수 있다.' AS prompt, 'distance' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 12 AS question_number, '혼자 보내는 시간이 관계를 위협한다고 생각하지 않는다.' AS prompt, 'distance' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 13 AS question_number, '비슷한 상황이 반복될 때도 상대가 혼자만의 시간을 원하면 존중할 수 있다.' AS prompt, 'distance' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 14 AS question_number, '비슷한 상황이 반복될 때도 나만의 시간과 취미를 꾸준히 유지한다.' AS prompt, 'distance' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 15 AS question_number, '비슷한 상황이 반복될 때도 갈등이 생겨도 잠시 거리를 두고 생각할 수 있다.' AS prompt, 'distance' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 16 AS question_number, '비슷한 상황이 반복될 때도 혼자 보내는 시간이 관계를 위협한다고 생각하지 않는다.' AS prompt, 'distance' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 17 AS question_number, '불편한 감정을 숨기기보다 말로 설명하는 편이다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 18 AS question_number, '사랑받고 싶은 마음을 상대에게 구체적으로 표현한다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 19 AS question_number, '서운함이 생기면 비난보다 내 감정 중심으로 말한다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 20 AS question_number, '가까운 사람에게도 내 약한 모습을 보이기 어렵다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'attachment' AS code, 21 AS question_number, '비슷한 상황이 반복될 때도 불편한 감정을 숨기기보다 말로 설명하는 편이다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 22 AS question_number, '비슷한 상황이 반복될 때도 사랑받고 싶은 마음을 상대에게 구체적으로 표현한다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 23 AS question_number, '비슷한 상황이 반복될 때도 서운함이 생기면 비난보다 내 감정 중심으로 말한다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'attachment' AS code, 24 AS question_number, '비슷한 상황이 반복될 때도 가까운 사람에게도 내 약한 모습을 보이기 어렵다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 1 AS question_number, '마음속 이야기를 나눌 수 있는 사람이 있다.' AS prompt, 'depth' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 2 AS question_number, '진솔한 대화를 나누는 관계를 선호한다.' AS prompt, 'depth' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 3 AS question_number, '서로의 약한 모습을 보여도 관계가 유지된다고 느낀다.' AS prompt, 'depth' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 4 AS question_number, '중요한 사람들과 정기적으로 안부를 나눈다.' AS prompt, 'depth' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 5 AS question_number, '비슷한 상황이 반복될 때도 마음속 이야기를 나눌 수 있는 사람이 있다.' AS prompt, 'depth' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 6 AS question_number, '비슷한 상황이 반복될 때도 진솔한 대화를 나누는 관계를 선호한다.' AS prompt, 'depth' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 7 AS question_number, '비슷한 상황이 반복될 때도 서로의 약한 모습을 보여도 관계가 유지된다고 느낀다.' AS prompt, 'depth' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 8 AS question_number, '비슷한 상황이 반복될 때도 중요한 사람들과 정기적으로 안부를 나눈다.' AS prompt, 'depth' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 9 AS question_number, '힘든 일이 생기면 한 사람에게만 기대는 편이다.' AS prompt, 'dependence' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 10 AS question_number, '내 기분을 바꾸는 데 특정 사람의 반응이 크게 영향을 준다.' AS prompt, 'dependence' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 11 AS question_number, '여러 사람에게 서로 다른 방식으로 도움을 요청할 수 있다.' AS prompt, 'dependence' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 12 AS question_number, '한 관계가 흔들려도 나를 지지하는 다른 자원이 있다.' AS prompt, 'dependence' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 13 AS question_number, '비슷한 상황이 반복될 때도 힘든 일이 생기면 한 사람에게만 기대는 편이다.' AS prompt, 'dependence' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 14 AS question_number, '비슷한 상황이 반복될 때도 내 기분을 바꾸는 데 특정 사람의 반응이 크게 영향을 준다.' AS prompt, 'dependence' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 15 AS question_number, '비슷한 상황이 반복될 때도 여러 사람에게 서로 다른 방식으로 도움을 요청할 수 있다.' AS prompt, 'dependence' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 16 AS question_number, '비슷한 상황이 반복될 때도 한 관계가 흔들려도 나를 지지하는 다른 자원이 있다.' AS prompt, 'dependence' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 17 AS question_number, '외로워도 그것이 언제 시작됐는지 알아차릴 수 있다.' AS prompt, 'isolation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 18 AS question_number, '사람들 사이에 있어도 혼자라고 느끼는 순간이 있다.' AS prompt, 'isolation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 19 AS question_number, '고립감을 느낄 때 먼저 할 수 있는 행동을 알고 있다.' AS prompt, 'isolation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 20 AS question_number, '혼자 있는 시간과 외로운 감정을 구분하기 어렵다.' AS prompt, 'isolation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 21 AS question_number, '비슷한 상황이 반복될 때도 외로워도 그것이 언제 시작됐는지 알아차릴 수 있다.' AS prompt, 'isolation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 22 AS question_number, '비슷한 상황이 반복될 때도 사람들 사이에 있어도 혼자라고 느끼는 순간이 있다.' AS prompt, 'isolation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 23 AS question_number, '비슷한 상황이 반복될 때도 고립감을 느낄 때 먼저 할 수 있는 행동을 알고 있다.' AS prompt, 'isolation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'social_bonding' AS code, 24 AS question_number, '비슷한 상황이 반복될 때도 혼자 있는 시간과 외로운 감정을 구분하기 어렵다.' AS prompt, 'isolation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 1 AS question_number, '감정이 생기면 먼저 혼자 생각을 정리한다.' AS prompt, 'internal' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 2 AS question_number, '감정의 원인을 스스로 찾아보려 한다.' AS prompt, 'internal' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 3 AS question_number, '감정을 말로 풀기 전에 내 감정을 이름 붙여 본다.' AS prompt, 'internal' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 4 AS question_number, '문제를 작은 단계로 나누면 마음이 안정된다.' AS prompt, 'internal' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 5 AS question_number, '비슷한 상황이 반복될 때도 감정이 생기면 먼저 혼자 생각을 정리한다.' AS prompt, 'internal' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 6 AS question_number, '비슷한 상황이 반복될 때도 감정의 원인을 스스로 찾아보려 한다.' AS prompt, 'internal' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 7 AS question_number, '비슷한 상황이 반복될 때도 감정을 말로 풀기 전에 내 감정을 이름 붙여 본다.' AS prompt, 'internal' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 8 AS question_number, '비슷한 상황이 반복될 때도 문제를 작은 단계로 나누면 마음이 안정된다.' AS prompt, 'internal' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 9 AS question_number, '기분이 가라앉으면 산책이나 활동으로 분위기를 바꾼다.' AS prompt, 'stimulation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 10 AS question_number, '새로운 장소나 콘텐츠가 감정을 전환하는 데 도움이 된다.' AS prompt, 'stimulation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 11 AS question_number, '기분이 나쁘면 쇼핑이나 게임으로 잊으려 한다.' AS prompt, 'stimulation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 12 AS question_number, '혼자 정리하기보다 환경을 바꾸는 것이 먼저 떠오른다.' AS prompt, 'stimulation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 13 AS question_number, '비슷한 상황이 반복될 때도 기분이 가라앉으면 산책이나 활동으로 분위기를 바꾼다.' AS prompt, 'stimulation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 14 AS question_number, '비슷한 상황이 반복될 때도 새로운 장소나 콘텐츠가 감정을 전환하는 데 도움이 된다.' AS prompt, 'stimulation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 15 AS question_number, '비슷한 상황이 반복될 때도 기분이 나쁘면 쇼핑이나 게임으로 잊으려 한다.' AS prompt, 'stimulation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 16 AS question_number, '비슷한 상황이 반복될 때도 혼자 정리하기보다 환경을 바꾸는 것이 먼저 떠오른다.' AS prompt, 'stimulation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 17 AS question_number, '마음이 힘들 때 믿을 수 있는 사람에게 이야기한다.' AS prompt, 'dialogue' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 18 AS question_number, '상대가 해결책보다 내 이야기를 들어주길 바란다.' AS prompt, 'dialogue' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 19 AS question_number, '갈등이 커지기 전에 차분하게 대화를 제안한다.' AS prompt, 'dialogue' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 20 AS question_number, '도움이 필요해도 괜찮다고 말하기 어렵다.' AS prompt, 'dialogue' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 21 AS question_number, '비슷한 상황이 반복될 때도 마음이 힘들 때 믿을 수 있는 사람에게 이야기한다.' AS prompt, 'dialogue' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 22 AS question_number, '비슷한 상황이 반복될 때도 상대가 해결책보다 내 이야기를 들어주길 바란다.' AS prompt, 'dialogue' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 23 AS question_number, '비슷한 상황이 반복될 때도 갈등이 커지기 전에 차분하게 대화를 제안한다.' AS prompt, 'dialogue' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'emotional_regulation' AS code, 24 AS question_number, '비슷한 상황이 반복될 때도 도움이 필요해도 괜찮다고 말하기 어렵다.' AS prompt, 'dialogue' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 1 AS question_number, '내가 관계에서 무엇을 필요로 하는지 알고 있다.' AS prompt, 'self_awareness' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 2 AS question_number, '외로움과 불안이 다르게 느껴진다는 것을 안다.' AS prompt, 'self_awareness' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 3 AS question_number, '같은 갈등이 반복될 때 내 반응을 돌아본다.' AS prompt, 'self_awareness' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 4 AS question_number, '서운함의 원인을 정확히 말하기 어렵다.' AS prompt, 'self_awareness' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 5 AS question_number, '비슷한 상황이 반복될 때도 내가 관계에서 무엇을 필요로 하는지 알고 있다.' AS prompt, 'self_awareness' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 6 AS question_number, '비슷한 상황이 반복될 때도 외로움과 불안이 다르게 느껴진다는 것을 안다.' AS prompt, 'self_awareness' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 7 AS question_number, '비슷한 상황이 반복될 때도 같은 갈등이 반복될 때 내 반응을 돌아본다.' AS prompt, 'self_awareness' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 8 AS question_number, '비슷한 상황이 반복될 때도 서운함의 원인을 정확히 말하기 어렵다.' AS prompt, 'self_awareness' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 9 AS question_number, '파트너가 내 마음을 먼저 알아주길 기대한다.' AS prompt, 'partner_expectation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 10 AS question_number, '연인이 내 외로움을 해결해주어야 한다고 느낄 때가 있다.' AS prompt, 'partner_expectation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 11 AS question_number, '상대의 책임과 내 감정의 책임을 나눠 생각할 수 있다.' AS prompt, 'partner_expectation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 12 AS question_number, '파트너가 모든 순간을 함께하지 않아도 사랑은 유지된다고 믿는다.' AS prompt, 'partner_expectation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 13 AS question_number, '비슷한 상황이 반복될 때도 파트너가 내 마음을 먼저 알아주길 기대한다.' AS prompt, 'partner_expectation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 14 AS question_number, '비슷한 상황이 반복될 때도 연인이 내 외로움을 해결해주어야 한다고 느낄 때가 있다.' AS prompt, 'partner_expectation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 15 AS question_number, '비슷한 상황이 반복될 때도 상대의 책임과 내 감정의 책임을 나눠 생각할 수 있다.' AS prompt, 'partner_expectation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 16 AS question_number, '비슷한 상황이 반복될 때도 파트너가 모든 순간을 함께하지 않아도 사랑은 유지된다고 믿는다.' AS prompt, 'partner_expectation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 17 AS question_number, '파트너 외에도 마음을 나눌 수 있는 사람이 있다.' AS prompt, 'alternative_resources' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 18 AS question_number, '혼자서도 기분을 회복하는 방법을 알고 있다.' AS prompt, 'alternative_resources' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 19 AS question_number, '새로운 관계를 만드는 것이 어렵고 부담스럽다.' AS prompt, 'alternative_resources' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 20 AS question_number, '파트너가 없으면 하루를 보내기 힘들 것 같다.' AS prompt, 'alternative_resources' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 21 AS question_number, '비슷한 상황이 반복될 때도 파트너 외에도 마음을 나눌 수 있는 사람이 있다.' AS prompt, 'alternative_resources' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 22 AS question_number, '비슷한 상황이 반복될 때도 혼자서도 기분을 회복하는 방법을 알고 있다.' AS prompt, 'alternative_resources' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 23 AS question_number, '비슷한 상황이 반복될 때도 새로운 관계를 만드는 것이 어렵고 부담스럽다.' AS prompt, 'alternative_resources' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'relationship_deficiency' AS code, 24 AS question_number, '비슷한 상황이 반복될 때도 파트너가 없으면 하루를 보내기 힘들 것 같다.' AS prompt, 'alternative_resources' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 1 AS question_number, '우리 사이의 긴장이 커지는 신호를 알아차릴 수 있다.' AS prompt, 'conflict_signal' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 2 AS question_number, '불편한 일이 생기면 비교적 빠르게 알아차린다.' AS prompt, 'conflict_signal' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 3 AS question_number, '갈등의 원인과 표면적인 말다툼을 구분할 수 있다.' AS prompt, 'conflict_signal' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 4 AS question_number, '갈등이 시작되면 상황을 통제하기 어렵다고 느낀다.' AS prompt, 'conflict_signal' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 5 AS question_number, '비슷한 상황이 반복될 때도 우리 사이의 긴장이 커지는 신호를 알아차릴 수 있다.' AS prompt, 'conflict_signal' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 6 AS question_number, '비슷한 상황이 반복될 때도 불편한 일이 생기면 비교적 빠르게 알아차린다.' AS prompt, 'conflict_signal' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 7 AS question_number, '비슷한 상황이 반복될 때도 갈등의 원인과 표면적인 말다툼을 구분할 수 있다.' AS prompt, 'conflict_signal' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 8 AS question_number, '비슷한 상황이 반복될 때도 갈등이 시작되면 상황을 통제하기 어렵다고 느낀다.' AS prompt, 'conflict_signal' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 9 AS question_number, '다툰 뒤 관계를 회복하기 위한 행동을 먼저 제안할 수 있다.' AS prompt, 'repair_action' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 10 AS question_number, '사과할 부분이 있으면 구체적으로 인정한다.' AS prompt, 'repair_action' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 11 AS question_number, '같은 갈등을 줄일 다음 약속을 함께 정한다.' AS prompt, 'repair_action' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 12 AS question_number, '갈등 후 대화를 다시 시작하는 것이 부담스럽다.' AS prompt, 'repair_action' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 13 AS question_number, '비슷한 상황이 반복될 때도 다툰 뒤 관계를 회복하기 위한 행동을 먼저 제안할 수 있다.' AS prompt, 'repair_action' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 14 AS question_number, '비슷한 상황이 반복될 때도 사과할 부분이 있으면 구체적으로 인정한다.' AS prompt, 'repair_action' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 15 AS question_number, '비슷한 상황이 반복될 때도 같은 갈등을 줄일 다음 약속을 함께 정한다.' AS prompt, 'repair_action' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 16 AS question_number, '비슷한 상황이 반복될 때도 갈등 후 대화를 다시 시작하는 것이 부담스럽다.' AS prompt, 'repair_action' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 17 AS question_number, '우리 사이에서는 실수나 약한 마음을 말할 수 있다.' AS prompt, 'safety' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 18 AS question_number, '감정이 커져도 모욕적인 말을 하지 않으려 한다.' AS prompt, 'safety' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 19 AS question_number, '서로의 이야기를 끊지 않고 들으려고 한다.' AS prompt, 'safety' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 20 AS question_number, '상대의 반응이 두려워 중요한 이야기를 숨긴다.' AS prompt, 'safety' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 21 AS question_number, '비슷한 상황이 반복될 때도 우리 사이에서는 실수나 약한 마음을 말할 수 있다.' AS prompt, 'safety' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 22 AS question_number, '비슷한 상황이 반복될 때도 감정이 커져도 모욕적인 말을 하지 않으려 한다.' AS prompt, 'safety' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 23 AS question_number, '비슷한 상황이 반복될 때도 서로의 이야기를 끊지 않고 들으려고 한다.' AS prompt, 'safety' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'conflict_repair' AS code, 24 AS question_number, '비슷한 상황이 반복될 때도 상대의 반응이 두려워 중요한 이야기를 숨긴다.' AS prompt, 'safety' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 1 AS question_number, '우리에게 필요한 함께하는 시간을 대략 알고 있다.' AS prompt, 'togetherness' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 2 AS question_number, '함께하는 시간이 관계의 안정감을 높여준다.' AS prompt, 'togetherness' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 3 AS question_number, '같이 있을 때 각자의 하루를 자연스럽게 나눈다.' AS prompt, 'togetherness' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 4 AS question_number, '모든 여가를 함께 보내야 한다고 생각한다.' AS prompt, 'togetherness' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 5 AS question_number, '비슷한 상황이 반복될 때도 우리에게 필요한 함께하는 시간을 대략 알고 있다.' AS prompt, 'togetherness' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 6 AS question_number, '비슷한 상황이 반복될 때도 함께하는 시간이 관계의 안정감을 높여준다.' AS prompt, 'togetherness' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 7 AS question_number, '비슷한 상황이 반복될 때도 같이 있을 때 각자의 하루를 자연스럽게 나눈다.' AS prompt, 'togetherness' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 8 AS question_number, '비슷한 상황이 반복될 때도 모든 여가를 함께 보내야 한다고 생각한다.' AS prompt, 'togetherness' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 9 AS question_number, '각자가 혼자 보내는 시간이 필요하다는 것을 인정한다.' AS prompt, 'personal_time' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 10 AS question_number, '상대의 취미와 친구 관계를 존중한다.' AS prompt, 'personal_time' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 11 AS question_number, '내가 원하는 개인 시간을 구체적으로 말할 수 있다.' AS prompt, 'personal_time' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 12 AS question_number, '상대가 혼자 있고 싶다고 하면 거절당한 느낌이 든다.' AS prompt, 'personal_time' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 13 AS question_number, '비슷한 상황이 반복될 때도 각자가 혼자 보내는 시간이 필요하다는 것을 인정한다.' AS prompt, 'personal_time' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 14 AS question_number, '비슷한 상황이 반복될 때도 상대의 취미와 친구 관계를 존중한다.' AS prompt, 'personal_time' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 15 AS question_number, '비슷한 상황이 반복될 때도 내가 원하는 개인 시간을 구체적으로 말할 수 있다.' AS prompt, 'personal_time' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 16 AS question_number, '비슷한 상황이 반복될 때도 상대가 혼자 있고 싶다고 하면 거절당한 느낌이 든다.' AS prompt, 'personal_time' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 17 AS question_number, '함께하는 시간과 개인 시간을 미리 조율할 수 있다.' AS prompt, 'coordination' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 18 AS question_number, '일정이 달라져도 서로의 기대를 확인한다.' AS prompt, 'coordination' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 19 AS question_number, '시간의 양보다 서로 만족하는 방식을 중요하게 생각한다.' AS prompt, 'coordination' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 20 AS question_number, '시간 문제를 이야기하면 결국 싸우게 된다고 생각한다.' AS prompt, 'coordination' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 21 AS question_number, '비슷한 상황이 반복될 때도 함께하는 시간과 개인 시간을 미리 조율할 수 있다.' AS prompt, 'coordination' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 22 AS question_number, '비슷한 상황이 반복될 때도 일정이 달라져도 서로의 기대를 확인한다.' AS prompt, 'coordination' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 23 AS question_number, '비슷한 상황이 반복될 때도 시간의 양보다 서로 만족하는 방식을 중요하게 생각한다.' AS prompt, 'coordination' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'togetherness_personal_time' AS code, 24 AS question_number, '비슷한 상황이 반복될 때도 시간 문제를 이야기하면 결국 싸우게 된다고 생각한다.' AS prompt, 'coordination' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 1 AS question_number, '나는 상대에게 애정을 말과 행동으로 표현한다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 2 AS question_number, '상대가 좋아하는 표현 방식을 알고 있다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 3 AS question_number, '작은 관심과 배려를 꾸준히 보여준다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 4 AS question_number, '표현이 어색해서 무심한 태도로 보일 때가 있다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 5 AS question_number, '비슷한 상황이 반복될 때도 나는 상대에게 애정을 말과 행동으로 표현한다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 6 AS question_number, '비슷한 상황이 반복될 때도 상대가 좋아하는 표현 방식을 알고 있다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 7 AS question_number, '비슷한 상황이 반복될 때도 작은 관심과 배려를 꾸준히 보여준다.' AS prompt, 'expression' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 8 AS question_number, '비슷한 상황이 반복될 때도 표현이 어색해서 무심한 태도로 보일 때가 있다.' AS prompt, 'expression' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 9 AS question_number, '내가 사랑받는다고 느끼는 행동을 설명할 수 있다.' AS prompt, 'expectation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 10 AS question_number, '상대가 원하는 애정 표현을 물어본 적이 있다.' AS prompt, 'expectation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 11 AS question_number, '기대와 실제 행동의 차이를 차분히 이야기할 수 있다.' AS prompt, 'expectation' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 12 AS question_number, '상대가 알아서 맞춰야 한다고 생각하는 편이다.' AS prompt, 'expectation' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 13 AS question_number, '비슷한 상황이 반복될 때도 내가 사랑받는다고 느끼는 행동을 설명할 수 있다.' AS prompt, 'expectation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 14 AS question_number, '비슷한 상황이 반복될 때도 상대가 원하는 애정 표현을 물어본 적이 있다.' AS prompt, 'expectation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 15 AS question_number, '비슷한 상황이 반복될 때도 기대와 실제 행동의 차이를 차분히 이야기할 수 있다.' AS prompt, 'expectation' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 16 AS question_number, '비슷한 상황이 반복될 때도 상대가 알아서 맞춰야 한다고 생각하는 편이다.' AS prompt, 'expectation' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 17 AS question_number, '서로 다른 표현 방식을 번역해 이해하려 한다.' AS prompt, 'alignment' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 18 AS question_number, '두 사람 모두 편안한 애정 표현을 찾아본다.' AS prompt, 'alignment' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 19 AS question_number, '표현이 부족하다고 느낄 때 구체적인 부탁을 한다.' AS prompt, 'alignment' AS dimension_key, 0 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 20 AS question_number, '표현 방식이 맞지 않으면 관계 자체가 맞지 않는 것 같다.' AS prompt, 'alignment' AS dimension_key, 1 AS reverse_scored, 1 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 21 AS question_number, '비슷한 상황이 반복될 때도 서로 다른 표현 방식을 번역해 이해하려 한다.' AS prompt, 'alignment' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 22 AS question_number, '비슷한 상황이 반복될 때도 두 사람 모두 편안한 애정 표현을 찾아본다.' AS prompt, 'alignment' AS dimension_key, 1 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 23 AS question_number, '비슷한 상황이 반복될 때도 표현이 부족하다고 느낄 때 구체적인 부탁을 한다.' AS prompt, 'alignment' AS dimension_key, 0 AS reverse_scored, 0 AS is_active UNION ALL
  SELECT 'affection_alignment' AS code, 24 AS question_number, '비슷한 상황이 반복될 때도 표현 방식이 맞지 않으면 관계 자체가 맞지 않는 것 같다.' AS prompt, 'alignment' AS dimension_key, 1 AS reverse_scored, 0 AS is_active
) seed ON seed.code = a.code
JOIN relationship_assessment_dimensions d
  ON d.version_id = v.version_id AND d.dimension_key = seed.dimension_key
WHERE v.version_label = 'v1' AND v.is_active = 1;

