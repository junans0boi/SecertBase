-- 커플검사 시도를 활성 Couple과 연결한다. 개인검사 시도는 NULL을 유지한다.
ALTER TABLE relationship_assessment_attempts
  ADD COLUMN IF NOT EXISTS couple_id INT NULL;

ALTER TABLE relationship_assessment_attempts
  ADD INDEX IF NOT EXISTS idx_relationship_attempt_couple_version
    (couple_id, version_id, status, attempt_id);

ALTER TABLE relationship_assessment_attempts
  ADD CONSTRAINT fk_relationship_attempt_couple
    FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE;
