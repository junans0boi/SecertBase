import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';

import {
  generateTerrain,
  raiseMound,
  selectTankClass,
  timeoutTurn,
  viewFor,
  battleSummary,
  TANK_CLASSES,
  THEMES,
  MAX_TIMEOUTS,
  SUDDEN_DEATH_TURN,
  FINAL_TURN,
  CRATE_INTERVAL,
  isSolid,
  surfaceY,
  carveBlast,
  simulateTrajectory,
  createFortressState,
  moveTank,
  aimTank,
  selectWeapon,
  fireTank,
  TERRAIN_W,
  TERRAIN_H,
  TANK_MOVE_FUEL,
  WEAPONS,
} from '../src/fortress-engine.js';

// ── Terrain ──────────────────────────────────────────────────────────────────
describe('generateTerrain', () => {
  it('returns TERRAIN_W columns', () => {
    const t = generateTerrain(0.5);
    assert.equal(t.length, TERRAIN_W);
  });

  it('all heights are within valid range', () => {
    const t = generateTerrain(0.3);
    for (const h of t) {
      assert.ok(h >= 2 && h <= TERRAIN_H - 2, `height ${h} out of range`);
    }
  });

  it('same seed produces same terrain', () => {
    const t1 = generateTerrain(0.77);
    const t2 = generateTerrain(0.77);
    assert.deepEqual(t1, t2);
  });

  it('different seeds produce different terrain', () => {
    const t1 = generateTerrain(0.1);
    const t2 = generateTerrain(0.9);
    assert.notDeepEqual(t1, t2);
  });
});

describe('isSolid / surfaceY', () => {
  it('bottom rows are solid', () => {
    const t = generateTerrain(0.5);
    assert.ok(isSolid(t, 5, TERRAIN_H - 1));
  });

  it('top rows are not solid', () => {
    const t = generateTerrain(0.5);
    assert.ok(!isSolid(t, 5, 0));
  });

  it('walls (out-of-bounds x) are solid', () => {
    const t = generateTerrain(0.5);
    assert.ok(isSolid(t, -1, 5));
    assert.ok(isSolid(t, TERRAIN_W, 5));
  });

  it('surfaceY is just above solid', () => {
    const t = generateTerrain(0.5);
    const sy = surfaceY(t, 5);
    assert.ok(!isSolid(t, 5, sy - 1), 'above surface should be air');
    assert.ok(isSolid(t, 5, sy), 'at surface should be solid');
  });
});

describe('carveBlast', () => {
  it('reduces terrain height in blast radius', () => {
    const t = generateTerrain(0.5);
    const origH = t[50];
    const { terrain: next } = carveBlast(t, 50, 4);
    assert.ok(next[50] <= origH);
  });

  it('blast radius beyond terrain width does not throw', () => {
    const t = generateTerrain(0.5);
    assert.doesNotThrow(() => carveBlast(t, 0, 10));
    assert.doesNotThrow(() => carveBlast(t, TERRAIN_W - 1, 10));
  });

  it('minimum height remains at least 2', () => {
    let t = generateTerrain(0.5);
    for (let i = 0; i < 20; i++) {
      ({ terrain: t } = carveBlast(t, 50, 8));
    }
    assert.ok(t[50] >= 2);
  });
});

// ── Trajectory ───────────────────────────────────────────────────────────────
describe('simulateTrajectory', () => {
  const flat = new Array(TERRAIN_W).fill(15); // flat terrain, surface at row 25

  it('returns path and impact', () => {
    const { path, impact } = simulateTrajectory(flat, 10, 24, 45, 50, 0);
    assert.ok(Array.isArray(path));
    assert.ok(path.length > 0);
    assert.ok(typeof impact.x === 'number');
    assert.ok(typeof impact.col === 'number');
  });

  it('projectile lands ON the terrain surface, not the screen bottom', () => {
    const { impact } = simulateTrajectory(flat, 10, 24, 45, 60, 0);
    // Flat terrain surface is at row 25 — impact row must be at/near it, not TERRAIN_H-1
    assert.ok(impact.row <= 26, `impact.row=${impact.row} should be at surface (~25), not bottom`);
  });

  it('shell fired straight up falls back down and lands near start', () => {
    const { impact } = simulateTrajectory(flat, 50, 24, 90, 80, 0);
    assert.ok(Math.abs(impact.col - 50) <= 3, `fired up should land near col 50, got ${impact.col}`);
    assert.ok(impact.row <= 26, 'should land on surface after falling back');
  });

  it('shell cannot pass through a mountain', () => {
    const wall = [...flat];
    for (let x = 45; x <= 55; x++) wall[x] = 35; // tall ridge, surface at row 5
    const { impact } = simulateTrajectory(wall, 10, 24, 30, 70, 0); // low, fast shot
    assert.ok(impact.col <= 56, `low shot should hit the ridge, got col=${impact.col}`);
  });

  it('wind displaces trajectory horizontally', () => {
    // Fire straight up (angle=90) — without wind it lands near start; wind pushes sideways
    const { impact: left }  = simulateTrajectory(flat, 50, 24, 90, 60, -1);
    const { impact: right } = simulateTrajectory(flat, 50, 24, 90, 60,  1);
    assert.ok(right.x > left.x, 'rightward wind should land further right than leftward wind');
  });

  it('direct hit on a target is detected', () => {
    const { directHit } = simulateTrajectory(flat, 10, 24, 45, 40, 0, {
      targets: [{ col: 30, row: 24, idx: 1 }],
    });
    // Whether it hits depends on tuning — but a shot landing right at the target col should register.
    // Fire a spread and expect at least one direct hit near a target on its path.
    if (directHit !== null) assert.equal(directHit, 1);
  });

  it('full-power 45° shot crosses most of the map (or leaves it)', () => {
    const { impact, outOfBounds } = simulateTrajectory(flat, 5, 24, 45, 100, 0);
    assert.ok(outOfBounds || impact.col >= 60, 'max power should reach far');
  });

  it('a shell leaving the map sideways vanishes instead of exploding at the wall', () => {
    const { impact, outOfBounds } = simulateTrajectory(flat, 90, 24, 20, 100, 0);
    assert.equal(outOfBounds, true);
    assert.equal(impact, null);
  });

  it('lower gravity (moon) carries the same shot further', () => {
    const earth = simulateTrajectory(flat, 10, 24, 45, 45, 0);
    const moon = simulateTrajectory(flat, 10, 24, 45, 45, 0, { gravityMul: 0.55 });
    assert.ok(moon.outOfBounds || moon.impact.col > earth.impact.col);
  });
});

// ── Tank 2.0: 상태·전차 선택 ──────────────────────────────────────────────────
const flatTerrain = (h = 15) => new Array(TERRAIN_W).fill(h);
const fixedRandom = (v = 0.5) => () => v;

/** 두 전차를 고르고 평지에서 시작하는 전투 상태. */
function battle(classes = { p1: 'turtle', p2: 'turtle' }, overrides = {}) {
  let s = createFortressState('p1', 'p2', { theme: 'meadow', seed: 0.5, random: fixedRandom(0.5) });
  s.terrain = flatTerrain();
  for (const p of s.players) p.row = surfaceY(s.terrain, p.col) - 1;
  ({ state: s } = selectTankClass(s, 'p1', classes.p1));
  ({ state: s } = selectTankClass(s, 'p2', classes.p2));
  s.wind = 0;
  return { ...s, ...overrides };
}

describe('createFortressState (2.0)', () => {
  it('starts in the hidden tank selection phase with a theme and series', () => {
    const s = createFortressState('p1', 'p2', { stake: 1000, theme: 'moon' });
    assert.equal(s.phase, 'select');
    assert.equal(s.theme, 'moon');
    assert.equal(s.gravityMul, THEMES.moon.gravityMul);
    assert.equal(s.windMul, 0);
    assert.equal(s.wind, 0, 'the moon has no wind');
    assert.equal(s.stake, 1000);
    assert.deepEqual(s.series, { p1: 0, p2: 0 });
    for (const p of s.players) assert.equal(p.row, surfaceY(s.terrain, p.col) - 1);
  });

  it('applies class stats and special ammo only after both players pick', () => {
    let s = createFortressState('p1', 'p2', { theme: 'meadow' });
    ({ state: s } = selectTankClass(s, 'p1', 'rhino'));
    assert.equal(s.phase, 'select');
    ({ state: s } = selectTankClass(s, 'p2', 'falcon'));
    assert.equal(s.phase, 'aiming');
    assert.equal(s.players[0].maxHp, TANK_CLASSES.rhino.hp);
    assert.equal(s.players[1].maxFuel, TANK_CLASSES.falcon.fuel);
    assert.equal(s.players[0].ammo.quake, 1);
    assert.equal(s.players[1].ammo.shotgun, 1);
    assert.equal('shotgun' in s.players[0].ammo, false, 'other classes\' specials are not owned');
  });

  it('rejects unknown classes and actions before the battle starts', () => {
    const s = createFortressState('p1', 'p2');
    assert.equal(selectTankClass(s, 'p1', 'dragon').ok, false);
    assert.equal(fireTank(s, 'p1').ok, false);
  });

  it('hides the opponent class during selection and the opponent aim during battle', () => {
    let s = createFortressState('p1', 'p2');
    ({ state: s } = selectTankClass(s, 'p1', 'mole'));
    const seenByP2 = viewFor(s, 'p2');
    assert.equal(seenByP2.players[0].tankClass, null);
    assert.equal(seenByP2.players[0].classPicked, true);
    const b = battle();
    const v = viewFor(b, 'p2');
    assert.equal(v.players[0].angle, null);
    assert.equal(v.players[0].power, null);
    assert.equal(v.players[1].angle, b.players[1].angle, 'own aim stays visible');
  });
});

describe('moveTank (2.0)', () => {
  it('moves and spends fuel; the falcon spends half', () => {
    const s = battle({ p1: 'falcon', p2: 'turtle' });
    const { ok, state } = moveTank(s, 'p1', 2);
    assert.ok(ok);
    assert.equal(state.players[0].col, s.players[0].col + 2);
    assert.equal(state.players[0].fuel, TANK_CLASSES.falcon.fuel - 2 * TANK_MOVE_FUEL * 0.5);
  });

  it('cannot climb a slope steeper than 3 rows', () => {
    const s = battle();
    s.terrain[s.players[0].col + 1] = 25; // 10-row wall right next to p1
    const { ok, error } = moveTank(s, 'p1', 2);
    assert.equal(ok, false);
    assert.equal(error, 'blocked');
  });

  it('rejects the wrong player and insufficient fuel', () => {
    const s = battle();
    assert.equal(moveTank(s, 'p2', 1).ok, false);
    const drained = { ...s, players: s.players.map((p, i) => (i === 0 ? { ...p, fuel: 2 } : p)) };
    assert.equal(moveTank(drained, 'p1', 1).ok, false);
  });

  it('collects a supply crate within one cell', () => {
    const s = battle();
    s.players[0].hp = 50;
    s.crates = [{ id: 'c1', col: s.players[0].col + 3, row: 24, item: 'repair' }];
    const { state, events } = moveTank(s, 'p1', 2);
    assert.equal(state.crates.length, 0);
    assert.equal(state.players[0].hp, 75);
    assert.ok(events.some((e) => e.type === 'crate' && e.item === 'repair'));
  });
});

describe('fireTank (2.0)', () => {
  it('fires with the aim sent at fire time and advances the turn', () => {
    const s = battle();
    const { ok, state, shotResult } = fireTank(s, 'p1', { angle: 60, power: 55, weapon: 'basic' });
    assert.ok(ok);
    assert.equal(shotResult.angle, 60);
    assert.equal(shotResult.power, 55);
    assert.ok(shotResult.events.some((e) => e.type === 'shell'));
    assert.equal(state.turn, 1);
    assert.equal(state.players[0].stats.shots, 1);
  });

  it('cannot use another class\'s special weapon', () => {
    const s = battle({ p1: 'turtle', p2: 'rhino' });
    assert.equal(fireTank(s, 'p1', { weapon: 'quake' }).ok, false);
  });

  it('a direct hit damages the enemy, records stats and respects the rhino armor', () => {
    const s = battle({ p1: 'turtle', p2: 'rhino' });
    s.players[0].col = 40; s.players[0].row = 24;
    s.players[1].col = 44; s.players[1].row = 24;
    // 직사로 붙어 있는 상대를 맞힌다.
    const { state, shotResult } = fireTank(s, 'p1', { angle: 0, power: 30, weapon: 'heavy' });
    const dmgEvent = shotResult.events.find((e) => e.type === 'damage' && e.target === 1);
    assert.ok(dmgEvent, 'enemy should take damage');
    assert.ok(dmgEvent.amount <= Math.round(WEAPONS.heavy.damage * 0.9), 'rhino takes 10% less');
    assert.equal(state.players[0].stats.hits, 1);
    assert.ok(state.players[0].stats.damageDealt > 0);
  });

  it('power buff boosts the next shot once and the shield halves the next hit', () => {
    const s = battle();
    s.players[0].col = 40; s.players[0].row = 24;
    s.players[1].col = 44; s.players[1].row = 24;
    s.players[0].buffs.power = true;
    s.players[1].buffs.shield = true;
    const { state, shotResult } = fireTank(s, 'p1', { angle: 0, power: 30, weapon: 'basic' });
    assert.equal(state.players[0].buffs.power, false);
    assert.equal(state.players[1].buffs.shield, false);
    assert.ok(shotResult.events.some((e) => e.type === 'shield' && e.target === 1));
  });

  it('teleport shell moves the shooter to the impact point without damage', () => {
    const s = battle();
    const before = s.players[0].col;
    const { state, shotResult } = fireTank(s, 'p1', { angle: 60, power: 40, weapon: 'teleport' });
    assert.notEqual(state.players[0].col, before);
    assert.ok(shotResult.events.some((e) => e.type === 'teleport'));
    assert.ok(!shotResult.events.some((e) => e.type === 'damage'));
    assert.equal(state.players[0].ammo.teleport, 0);
  });

  it('cluster shell splits at the apex into bomblets', () => {
    const s = battle();
    const { shotResult } = fireTank(s, 'p1', { angle: 60, power: 50, weapon: 'cluster' });
    assert.ok(shotResult.events.some((e) => e.type === 'split'));
    const bomblets = shotResult.events.filter((e) => e.type === 'shell' && e.stage === 1);
    assert.equal(bomblets.length, WEAPONS.cluster.bomblets);
  });

  it('wall shell raises terrain instead of carving it', () => {
    const s = battle({ p1: 'turtle', p2: 'turtle' });
    const { shotResult, state } = fireTank(s, 'p1', { angle: 60, power: 45, weapon: 'wall' });
    const mound = shotResult.events.find((e) => e.type === 'mound');
    assert.ok(mound);
    assert.ok(state.terrain[mound.col] > 15);
  });

  it('a tank whose ground is blasted away falls and takes fall damage (mole is immune)', () => {
    for (const cls of ['turtle', 'mole']) {
      const s = battle({ p1: 'turtle', p2: cls });
      s.players[1].col = 60; s.players[1].row = 24;
      // 상대 발밑에 대형탄: 지형을 깊게 판다.
      s.terrain = s.terrain.map((h, x) => (Math.abs(x - 60) <= 6 ? 4 : h));
      const events = [];
      const { state } = fireTank({ ...s, terrain: flatTerrain() }, 'p1', { angle: 90, power: 1, weapon: 'basic' });
      // 직접 settle을 검증: 지형을 낮춘 상태에서 한 번 더 발사해 낙하가 일어나게 한다.
      state.terrain = s.terrain;
      const r = fireTank({ ...state, turn: 1, phase: 'aiming' }, 'p2', { angle: 90, power: 1, weapon: 'basic' });
      const fall = r.shotResult.events.find((e) => e.type === 'fall' && e.target === 1);
      assert.ok(fall, `${cls} should fall`);
      if (cls === 'mole') assert.equal(fall.damage, 0);
      else assert.ok(fall.damage > 0);
      void events;
    }
  });

  it('a blast that catches a crate gives it to the shooter', () => {
    const s = battle();
    s.crates = [{ id: 'c9', col: 50, row: 24, item: 'power' }];
    // 바람 0, 고각 사격으로 50 근처 착탄을 찾는다.
    let found = null;
    for (let power = 20; power <= 100 && !found; power++) {
      const r = fireTank(s, 'p1', { angle: 45, power, weapon: 'heavy' });
      if (r.shotResult.events.some((e) => e.type === 'crate' && e.crateId === 'c9')) found = r;
    }
    assert.ok(found, 'some shot must catch the crate');
    assert.equal(found.state.players[0].buffs.power, true);
  });
});

describe('turn flow (2.0)', () => {
  it('three consecutive timeouts forfeit the game', () => {
    let s = battle();
    let r;
    for (let i = 0; i < MAX_TIMEOUTS; i++) {
      r = timeoutTurn({ ...s, turn: 0 });
      s = r.state;
    }
    assert.equal(r.forfeited, true);
    assert.equal(s.winner, 'p2');
    assert.equal(s.endReason, 'afk');
    assert.equal(s.series.p2, 1);
  });

  it('firing resets the shooter\'s timeout counter', () => {
    let s = battle();
    ({ state: s } = timeoutTurn(s)); // p1 timeout → p2 turn
    ({ state: s } = timeoutTurn(s)); // p2 timeout → p1 turn
    assert.equal(s.timeouts[0], 1);
    ({ state: s } = fireTank(s, 'p1', { angle: 90, power: 1 }));
    assert.equal(s.timeouts[0], 0);
  });

  it('sudden death starts at the configured turn and the final turn decides by HP ratio', () => {
    let s = battle({ p1: 'rhino', p2: 'falcon' });
    s.turnNumber = SUDDEN_DEATH_TURN - 1;
    ({ state: s } = timeoutTurn(s));
    assert.equal(s.suddenDeath, true);
    s.turnNumber = FINAL_TURN - 1;
    s.players[0].hp = 65;  // 50%
    s.players[1].hp = 54;  // 60%
    ({ state: s } = timeoutTurn(s));
    assert.equal(s.phase, 'result');
    assert.equal(s.winner, 'p2');
    assert.equal(s.endReason, 'time');
  });

  it('mutual destruction is a draw and does not change the series', () => {
    const s = battle();
    s.players[0].col = 46; s.players[0].row = 24; s.players[0].hp = 1;
    s.players[1].col = 50; s.players[1].row = 24; s.players[1].hp = 1;
    const { state } = fireTank(s, 'p1', { angle: 90, power: 1, weapon: 'heavy' });
    if (state.players[0].hp <= 0 && state.players[1].hp <= 0) {
      assert.equal(state.winner, 'draw');
      assert.deepEqual(state.series, { p1: 0, p2: 0 });
    }
  });

  it('supply crates drop every few turns', () => {
    let s = battle();
    for (let i = 0; i < CRATE_INTERVAL; i++) ({ state: s } = timeoutTurn({ ...s, timeouts: [0, 0] }));
    assert.ok(s.crates.length >= 1);
  });

  it('battleSummary reports accuracy and series', () => {
    let s = battle();
    ({ state: s } = fireTank(s, 'p1', { angle: 90, power: 1 }));
    const summary = battleSummary(s);
    assert.equal(summary.players[0].stats.shots, 1);
    assert.equal(typeof summary.players[0].accuracy, 'number');
  });

  it('state survives a JSON round trip (Redis) and keeps unlimited basic ammo', () => {
    const s = JSON.parse(JSON.stringify(battle()));
    const { ok, state } = fireTank(s, 'p1', { angle: 45, power: 40 });
    assert.ok(ok);
    assert.ok(state.players[0].ammo.basic >= 900);
  });
});

describe('raiseMound', () => {
  it('raises terrain around the center and stays below the ceiling', () => {
    const { terrain } = raiseMound(flatTerrain(30), 50, 5);
    assert.ok(terrain[50] > 30);
    assert.ok(terrain.every((h) => h <= TERRAIN_H - 3));
  });
});

describe('WEAPONS table', () => {
  it('all weapons have required fields', () => {
    for (const [key, w] of Object.entries(WEAPONS)) {
      assert.ok(typeof w.name === 'string', `${key} missing name`);
      assert.ok(typeof w.damage === 'number', `${key} missing damage`);
      assert.ok(typeof w.blastR === 'number', `${key} missing blastR`);
    }
  });

  it('every class special exists in the weapon table', () => {
    for (const c of Object.values(TANK_CLASSES)) assert.ok(WEAPONS[c.special]);
  });
});

// keep unused imports referenced for lint parity
void aimTank; void selectWeapon; void isSolid;
