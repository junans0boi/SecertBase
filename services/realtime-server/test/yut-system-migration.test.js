// 0049_yut_system.sql(티켓 27): 새 윷 스킨 9종, 예전 윷·말 은퇴, 소유·장착 변환이 안전한지 SQL 문서 자체를 검사한다.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import test from 'node:test';

const dir = new URL('../migrations/', import.meta.url);
const read = (name) => readFileSync(new URL(name, dir), 'utf8');
const sql = read('0049_yut_system.sql');

const GRADES = ['B', 'A', 'S', 'SS', 'SSS'];
const rowRe = /\((\d+), 'skin', 'yut', '(yut_yut|yut_piece)', '(\w+)',\s+'([^']+)'/g;

function itemsIn(text) {
  return [...text.matchAll(rowRe)].map((m) => ({ id: Number(m[1]), slot: m[2], grade: m[3], name: m[4] }));
}

const newSkins = itemsIn(sql);
const oldYut = [...itemsIn(read('0014_shop_v2.sql')), ...itemsIn(read('0018_item_catalog_v2.sql'))].filter((i) => i.slot === 'yut_yut');
const oldPieces = [...itemsIn(read('0014_shop_v2.sql')), ...itemsIn(read('0018_item_catalog_v2.sql'))].filter((i) => i.slot === 'yut_piece');
const mapping = new Map([...sql.slice(sql.indexOf('INSERT INTO yut_skin_migration_map')).matchAll(/\((\d+), (\d+)\)/g)].map((m) => [Number(m[1]), Number(m[2])]));
const stats = [...sql.slice(sql.indexOf('INSERT INTO item_stats')).matchAll(/\((11\d), '(\w+)',\s+([\d.]+)\)/g)]
  .map((m) => ({ id: Number(m[1]), key: m[2], value: Number(m[3]) }));

test('nine new yut skins, ids 110–118, none colliding with any earlier catalog id', () => {
  assert.equal(newSkins.length, 9);
  assert.ok(newSkins.every((s) => s.slot === 'yut_yut'), 'no piece skins are added');
  assert.deepEqual(newSkins.map((s) => s.id), [110, 111, 112, 113, 114, 115, 116, 117, 118]);
  const earlier = new Set();
  for (const name of readdirSync(dir)) {
    if (name.startsWith('0049')) continue;
    for (const m of read(name).matchAll(/^\s*\((\d+), '(?:skin|character|booster|gacha|coupon)'/gm)) earlier.add(Number(m[1]));
  }
  for (const s of newSkins) assert.equal(earlier.has(s.id), false, `${s.id} collides`);
  assert.equal(new Set(newSkins.map((s) => s.name)).size, 9, 'names are unique');
});

test('grades scale: every grade has a skin (gacha can always draw), B/A are bought, S+ are gacha-only', () => {
  const byGrade = Object.fromEntries(GRADES.map((g) => [g, newSkins.filter((s) => s.grade === g)]));
  assert.deepEqual(GRADES.map((g) => byGrade[g].length), [2, 2, 2, 2, 1]);
  const priceRe = (id) => new RegExp(`\\(${id}, 'skin', 'yut', 'yut_yut', '\\w+',\\s+'[^']+',\\s+'[^']+',\\s+(\\d+),`);
  for (const s of newSkins) {
    const price = Number(sql.match(priceRe(s.id))?.[1]);
    if (s.grade === 'B' || s.grade === 'A') assert.ok(price >= 1000, `${s.name} is bought with coins`);
    else assert.equal(price, 0, `${s.name} is gacha-only`);
  }
});

test('each skin has exactly one clear effect, valid for the stat enum, and strength grows with grade', () => {
  const allowed = new Set(['yut_control_pct', 'piece_catch_resist_pct', 'yut_backdo_shield_pct', 'yut_win_coin_pct', 'yut_overturn_pct']);
  const enumText = read('0017_shop_v3.sql');
  for (const s of newSkins) {
    const rows = stats.filter((x) => x.id === s.id);
    assert.equal(rows.length, 1, `${s.name} has one effect`);
    assert.ok(allowed.has(rows[0].key), rows[0].key);
    assert.ok(enumText.includes(`'${rows[0].key}'`), `${rows[0].key} exists in the item_stats enum`);
    assert.ok(rows[0].value > 0);
  }
  const of = (name) => stats.find((x) => x.id === newSkins.find((s) => s.name === name).id);
  // 같은 효과 종류는 등급이 높을수록 세다.
  assert.ok(of('대나무 윷').value < of('번개 윷').value && of('번개 윷').value < of('신들의 윷').value, '윷·모 확률');
  assert.ok(of('단풍 윷').value < of('얼음 윷').value, '잡힘 방어');
  assert.ok(of('옥 윷').value < of('용의 윷').value, '윷·모 코인');
  assert.equal(of('신들의 윷').key, 'yut_control_pct', 'the mythic skin boosts the core throw');
});

test('every old yut skin maps to a new skin of the same grade', () => {
  assert.ok(oldYut.length >= 23, `found ${oldYut.length} old yut skins`);
  const newById = new Map(newSkins.map((s) => [s.id, s]));
  for (const old of oldYut) {
    const target = mapping.get(old.id);
    assert.ok(target, `${old.name} (${old.id}) has no mapping`);
    assert.equal(newById.get(target)?.grade, old.grade, `${old.name} → ${newById.get(target)?.name} keeps its grade`);
  }
  assert.equal(mapping.size, oldYut.length, 'no stray mapping rows');
  for (const target of mapping.values()) assert.ok(newById.has(target));
});

test('the migration is idempotent and never deletes player data', () => {
  assert.match(sql, /ON DUPLICATE KEY UPDATE/);
  assert.match(sql, /INSERT IGNORE INTO owned_items/);
  assert.match(sql, /CREATE TABLE IF NOT EXISTS yut_skin_migration_map/);
  assert.match(sql, /DROP TABLE IF EXISTS yut_skin_migration_map/);
  assert.doesNotMatch(sql, /DELETE FROM owned_items/i);
  assert.doesNotMatch(sql, /DELETE FROM shop_items/i);
  // 말 스킨 장착만 푼다. 소유 기록은 남는다.
  assert.match(sql, /DELETE FROM equipped_items WHERE slot = 'yut_piece'/);
  // 옛 윷·말은 은퇴(상점·도감·뽑기에서 빠짐).
  assert.match(sql, /SET active = 0, game = 'yut_legacy'/);
  assert.match(sql, /slot IN \('yut_yut', 'yut_piece'\)/);
  assert.match(sql, /id NOT BETWEEN 110 AND 118/);
  // 장착 중이던 윷은 새 스킨으로 바꾼다.
  assert.match(sql, /UPDATE equipped_items ei\s+JOIN yut_skin_migration_map m ON m\.old_id = ei\.item_id\s+SET ei\.item_id = m\.new_id\s+WHERE ei\.slot = 'yut_yut'/);
  assert.ok(oldPieces.length >= 20, 'old piece skins are known to the retirement query');
});

test('applying the mapping to sample owners converts ownership and equips without losing anything', () => {
  // 마이그레이션 SQL이 하는 일을 같은 대응표로 흉내 낸다.
  const owned = [{ user: 1, item: 41 }, { user: 1, item: 111 }, { user: 2, item: 55 }, { user: 3, item: 62 /* 동물 말 */ }];
  const equipped = [{ user: 1, slot: 'yut_yut', item: 41 }, { user: 2, slot: 'yut_yut', item: 55 }, { user: 3, slot: 'yut_piece', item: 62 }];
  const key = (o) => `${o.user}:${o.item}`;
  const next = new Map(owned.map((o) => [key(o), o]));
  for (const o of owned) if (mapping.has(o.item)) next.set(`${o.user}:${mapping.get(o.item)}`, { user: o.user, item: mapping.get(o.item) });
  const nextEquipped = equipped
    .map((e) => (e.slot === 'yut_yut' && mapping.has(e.item) ? { ...e, item: mapping.get(e.item) } : e))
    .filter((e) => e.slot !== 'yut_piece');
  assert.ok(next.has('1:111') && next.size === 5, 'user 1 already owned 111, so nothing duplicates');
  assert.ok(next.has('2:118'));
  assert.ok(next.has('3:62'), 'old piece ownership is kept');
  assert.deepEqual(nextEquipped, [{ user: 1, slot: 'yut_yut', item: 111 }, { user: 2, slot: 'yut_yut', item: 118 }]);
});
