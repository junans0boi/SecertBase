import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const expectedCatalog = [
  ['데이트 쿠폰', '상대방에게 주는 특별한 약속 쿠폰', '🎟️'],
  ['데일리 보너스 2배', '오늘 하루 데일리 보너스 2배 지급', '⚡'],
  ['황금 윷', '윷놀이 말 황금 스킨', '✨'],
  ['꽃 테마', '게임 배경 꽃 테마', '🌸'],
  ['아이템 뽑기', '랜덤 아이템 1개 획득', '🎰'],
];

test('shop catalog repair migration preserves canonical Korean copy and emoji', async () => {
  const sql = await readFile(
    new URL('../migrations/0009_repair_shop_catalog_encoding.sql', import.meta.url),
    'utf8',
  );

  assert.match(sql, /ON DUPLICATE KEY UPDATE/);
  const duplicateUpdate = sql.split('ON DUPLICATE KEY UPDATE')[1];
  assert.doesNotMatch(duplicateUpdate, /\b(category|price|active)\s*=/);
  for (const fields of expectedCatalog) {
    for (const field of fields) assert.ok(sql.includes(`'${field}'`), field);
  }
});
