-- 0020: IDs 40-89 전체 활성화 (상점 표시 + 가챠 풀)
-- 업데이트별 점진 공개 전략 → 즉시 전체 공개로 변경
UPDATE shop_items SET active = 1 WHERE id BETWEEN 40 AND 89 AND active = 0;
