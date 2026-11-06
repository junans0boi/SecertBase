// 마이그레이션이 item_stats.stat_key ENUM에 없는 효과 키를 넣으면 운영 배포가 DB 단계에서 멈춘다
// ("Data truncated for column 'stat_key'"). 파일 순서대로 ENUM 허용 목록을 따라가며 INSERT를 검사한다.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'migrations');
const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();

const stripComments = (sql) => sql.replace(/--[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
const enumOf = (body) => new Set([...body.matchAll(/'([^']+)'/g)].map((m) => m[1]));

test('every item_stats insert only uses stat keys the ENUM allows at that point', () => {
  let allowed = null;
  const problems = [];
  for (const file of files) {
    const sql = stripComments(readFileSync(path.join(dir, file), 'utf8'));
    // 문장 단위로 순서를 지켜 본다(ENUM 정의/변경 → INSERT).
    for (const stmt of sql.split(';')) {
      const create = stmt.match(/CREATE TABLE[^()]*item_stats[\s\S]*?stat_key\s+ENUM\(([^)]*)\)/i);
      if (create) allowed = enumOf(create[1]);
      const modify = stmt.match(/ALTER TABLE\s+item_stats[\s\S]*?MODIFY COLUMN\s+stat_key\s+ENUM\(([^)]*)\)/i);
      if (modify) allowed = enumOf(modify[1]);
      if (!allowed || !/INSERT\s+(IGNORE\s+)?INTO\s+item_stats/i.test(stmt)) continue;
      for (const m of stmt.matchAll(/\(\s*\d+\s*,\s*'([a-z_]+)'\s*,/g)) {
        if (!allowed.has(m[1])) problems.push(`${file}: '${m[1]}' is not in the stat_key ENUM`);
      }
    }
  }
  assert.deepEqual(problems, []);
});

test('0049 yut skins only use stat keys that exist in the ENUM after the migration', () => {
  const sql = stripComments(readFileSync(path.join(dir, '0049_yut_system.sql'), 'utf8'));
  const modify = sql.match(/MODIFY COLUMN\s+stat_key\s+ENUM\(([^)]*)\)/i);
  assert.ok(modify, '0049 must re-allow the keys it needs');
  const allowed = enumOf(modify[1]);
  for (const key of ['yut_control_pct', 'piece_catch_resist_pct', 'yut_backdo_shield_pct', 'yut_win_coin_pct', 'yut_overturn_pct']) {
    assert.ok(allowed.has(key), key);
  }
});
