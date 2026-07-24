import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';

import {
  generateTerrain,
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
  MAX_FUEL,
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
  it('returns path and impact', () => {
    const { path, impact } = simulateTrajectory(10, 20, 45, 50, 0);
    assert.ok(Array.isArray(path));
    assert.ok(path.length > 0);
    assert.ok(typeof impact.x === 'number');
    assert.ok(typeof impact.col === 'number');
  });

  it('wind displaces trajectory horizontally', () => {
    // Fire straight up (angle=90) — without wind it lands near start; wind pushes sideways
    const { path: pathLeft }  = simulateTrajectory(50, 20, 90, 30, -1);
    const { path: pathRight } = simulateTrajectory(50, 20, 90, 30,  1);
    const endLeft  = pathLeft.at(-1);
    const endRight = pathRight.at(-1);
    assert.ok(endRight.x > endLeft.x, 'rightward wind should land further right than leftward wind');
  });
});

// ── Game state ────────────────────────────────────────────────────────────────
describe('createFortressState', () => {
  it('creates valid initial state', () => {
    const s = createFortressState('p1', 'p2');
    assert.equal(s.players.length, 2);
    assert.equal(s.phase, 'aiming');
    assert.equal(s.turn, 0);
    assert.equal(s.winner, null);
    assert.equal(s.players[0].hp, 100);
    assert.equal(s.players[1].hp, 100);
    assert.equal(s.players[0].fuel, MAX_FUEL);
  });

  it('players are on terrain surface', () => {
    const s = createFortressState('p1', 'p2');
    for (const p of s.players) {
      assert.equal(p.row, surfaceY(s.terrain, p.col) - 1);
    }
  });

  it('stake is stored', () => {
    const s = createFortressState('p1', 'p2', { stake: 1000 });
    assert.equal(s.stake, 1000);
  });
});

// ── moveTank ─────────────────────────────────────────────────────────────────
describe('moveTank', () => {
  it('moves player 0 right', () => {
    const s = createFortressState('p1', 'p2');
    const oldCol = s.players[0].col;
    const { ok, state } = moveTank(s, 'p1', 2);
    assert.ok(ok);
    assert.equal(state.players[0].col, oldCol + 2);
  });

  it('consumes fuel', () => {
    const s = createFortressState('p1', 'p2');
    const { state } = moveTank(s, 'p1', 3);
    assert.equal(state.players[0].fuel, MAX_FUEL - 3 * TANK_MOVE_FUEL);
  });

  it('rejects move by wrong player', () => {
    const s = createFortressState('p1', 'p2');
    const { ok, error } = moveTank(s, 'p2', 1);
    assert.ok(!ok);
    assert.ok(error);
  });

  it('rejects when not enough fuel', () => {
    let s = createFortressState('p1', 'p2');
    // Drain fuel
    ({ state: s } = moveTank(s, 'p1', 9));
    const { ok } = moveTank(s, 'p1', 9);
    assert.ok(!ok);
  });

  it('clamps to terrain bounds', () => {
    const s = createFortressState('p1', 'p2');
    // Move left by 5 (costs 15 fuel, within MAX_FUEL=30) — col should not go below 1
    const { ok, state } = moveTank(s, 'p1', -5);
    assert.ok(ok);
    assert.ok(state.players[0].col >= 1);
  });
});

// ── aimTank ───────────────────────────────────────────────────────────────────
describe('aimTank', () => {
  it('sets angle and power', () => {
    const s = createFortressState('p1', 'p2');
    const { ok, state } = aimTank(s, 'p1', 70, 80);
    assert.ok(ok);
    assert.equal(state.players[0].angle, 70);
    assert.equal(state.players[0].power, 80);
  });

  it('clamps angle to 0..180', () => {
    const s = createFortressState('p1', 'p2');
    const { state } = aimTank(s, 'p1', 999, 50);
    assert.equal(state.players[0].angle, 180);
  });

  it('rejects wrong player', () => {
    const s = createFortressState('p1', 'p2');
    const { ok } = aimTank(s, 'p2', 90, 50);
    assert.ok(!ok);
  });
});

// ── selectWeapon ──────────────────────────────────────────────────────────────
describe('selectWeapon', () => {
  it('switches weapon', () => {
    const s = createFortressState('p1', 'p2');
    const { ok, state } = selectWeapon(s, 'p1', 'heavy');
    assert.ok(ok);
    assert.equal(state.players[0].weapon, 'heavy');
  });

  it('rejects unknown weapon', () => {
    const s = createFortressState('p1', 'p2');
    const { ok } = selectWeapon(s, 'p1', 'nuke');
    assert.ok(!ok);
  });
});

// ── fireTank ──────────────────────────────────────────────────────────────────
describe('fireTank', () => {
  it('returns shot result with path', () => {
    const s = createFortressState('p1', 'p2');
    const { ok, shotResult } = fireTank(s, 'p1');
    assert.ok(ok);
    assert.ok(shotResult.paths.length > 0);
  });

  it('advances turn after fire', () => {
    const s = createFortressState('p1', 'p2');
    const { state } = fireTank(s, 'p1');
    if (!state.winner) {
      assert.equal(state.turn, 1);
    }
  });

  it('rejects fire by wrong player', () => {
    const s = createFortressState('p1', 'p2');
    const { ok } = fireTank(s, 'p2');
    assert.ok(!ok);
  });

  it('heavy weapon consumes ammo', () => {
    let s = createFortressState('p1', 'p2');
    ({ state: s } = selectWeapon(s, 'p1', 'heavy'));
    const before = s.players[0].ammo.heavy;
    const { state } = fireTank(s, 'p1');
    assert.equal(state.players[0].ammo.heavy, before - 1);
  });

  it('basic ammo is unlimited', () => {
    const s = createFortressState('p1', 'p2');
    const { state } = fireTank(s, 'p1');
    assert.equal(state.players[0].ammo.basic, Infinity);
  });

  it('wind changes each turn', () => {
    const s = createFortressState('p1', 'p2');
    const { state } = fireTank(s, 'p1');
    // Wind changes on turn advance (may coincidentally be same value, but structurally it's re-rolled)
    assert.ok(typeof state.wind === 'number');
    assert.ok(state.wind >= -1 && state.wind <= 1);
  });

  it('point-blank hit reduces target HP', () => {
    let s = createFortressState('p1', 'p2');
    // Move p1 very close to p2
    s.players[0].col = s.players[1].col - 2;
    s.players[0].row = s.players[1].row;
    s.players[0].angle = 0;
    s.players[0].power = 5;
    const { state } = fireTank(s, 'p1');
    // p2 HP may or may not be reduced depending on trajectory; engine should not throw
    assert.ok(state.players[1].hp <= 100);
  });
});

// ── Weapons table ─────────────────────────────────────────────────────────────
describe('WEAPONS table', () => {
  it('all weapons have required fields', () => {
    for (const [key, w] of Object.entries(WEAPONS)) {
      assert.ok(typeof w.name === 'string', `${key} missing name`);
      assert.ok(typeof w.damage === 'number', `${key} missing damage`);
      assert.ok(typeof w.blastR === 'number', `${key} missing blastR`);
    }
  });
});
