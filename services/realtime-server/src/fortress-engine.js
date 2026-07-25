// fortress-engine.js — Tank 대작전 game engine
// Server-authoritative: all physics/state runs here, clients render only

export const TERRAIN_W = 100; // columns
export const TERRAIN_H = 40;  // rows (0=top, TERRAIN_H-1=bottom)
export const TANK_MOVE_FUEL = 3; // fuel per cell moved
export const MAX_FUEL = 30;
export const MAX_TURNS = 15; // sudden death after this
export const GRAVITY = 9.8;  // m/s² equivalent per simulation step

// Weapon definitions
// count >= UNLIMITED_AMMO means 무제한 — Infinity는 JSON(Redis) 직렬화에서 null이 되므로 금지
export const UNLIMITED_AMMO = 999;
export const WEAPONS = {
  basic:    { name: '기본탄',   damage: 35, blastR: 4, count: UNLIMITED_AMMO, cost: 0 },
  heavy:    { name: '대형탄',   damage: 70, blastR: 7, count: 3,        cost: 0 },
  triple:   { name: '3연발탄',  damage: 25, blastR: 3, count: 2,        cost: 0, shots: 3 },
  mole:     { name: '두더지탄', damage: 55, blastR: 3, count: 1,        cost: 0, penetrates: true },
};

export const DIRECT_HIT_RADIUS = 1.8; // 직격 판정 반경 (넉넉하게)

// ── Terrain ──────────────────────────────────────────────────────────────────

/**
 * Generate a random terrain heightmap.
 * Returns a Uint8Array-like plain array of height values (0..TERRAIN_H-1).
 * Index i = column, value = number of solid rows from the bottom.
 */
export function generateTerrain(seed = Math.random()) {
  const heights = new Array(TERRAIN_W);
  // Simple seeded-ish sine-wave terrain
  let rng = seed;
  const next = () => { rng = (rng * 9301 + 49297) % 233280; return rng / 233280; };

  const base = 15 + Math.floor(next() * 10);
  const amp1 = 4 + next() * 6;
  const freq1 = 0.08 + next() * 0.04;
  const amp2 = 2 + next() * 3;
  const freq2 = 0.15 + next() * 0.1;
  const phase1 = next() * Math.PI * 2;
  const phase2 = next() * Math.PI * 2;

  for (let x = 0; x < TERRAIN_W; x++) {
    const h = base
      + Math.round(amp1 * Math.sin(freq1 * x + phase1))
      + Math.round(amp2 * Math.sin(freq2 * x + phase2));
    heights[x] = Math.max(5, Math.min(TERRAIN_H - 5, h));
  }

  // Flatten small platforms near tanks (cols 5-10 and 85-90)
  for (let x = 4; x <= 11; x++) heights[x] = heights[7];
  for (let x = 88; x <= 95; x++) heights[x] = heights[91];

  return heights;
}

/**
 * Solid check: returns true if (x, y) is inside terrain.
 * y=0 is top of screen, y=TERRAIN_H-1 is bottom.
 * Terrain is solid from (TERRAIN_H - heights[x]) downward.
 */
export function isSolid(terrain, x, y) {
  if (x < 0 || x >= TERRAIN_W) return true; // walls are solid
  if (y < 0) return false;
  if (y >= TERRAIN_H) return true;
  const surfaceY = TERRAIN_H - terrain[x];
  return y >= surfaceY;
}

/** Surface Y for column x (first solid row from top) */
export function surfaceY(terrain, x) {
  return TERRAIN_H - terrain[x];
}

// ── Ballistic simulation ──────────────────────────────────────────────────────

// Physics constants — mirrored in the Flutter client for aim preview.
export const PROJ_SPEED_SCALE = 0.35; // velocity = power * scale
export const PROJ_GRAVITY = 12;       // cells/s²
export const PROJ_WIND_SCALE = 1.5;   // wind accel = wind * scale (cells/s²)
export const PROJ_DT = 0.02;          // integration step (s)

/**
 * Simulate projectile trajectory with real terrain collision (포트리스 스타일).
 * terrain: heightmap array — projectile explodes on first solid contact
 * angle: degrees above horizontal (0=right, 90=up, 180=left)
 * power: 1..100, wind: -1..1 (negative=left)
 * opts.targets: [{col, row, idx}] — direct-hit check against tanks
 * opts.penetrates: burrow 3 cells into terrain before exploding (두더지탄)
 * Returns { path, impact: {x, y, col, row}, directHit: idx|null }.
 */
export function simulateTrajectory(terrain, startX, startY, angleDeg, power, wind, opts = {}) {
  const radians = (angleDeg * Math.PI) / 180;
  const speed = power * PROJ_SPEED_SCALE;
  let vx = Math.cos(radians) * speed;
  let vy = -Math.sin(radians) * speed; // negative = upward in screen coords
  let px = startX;
  let py = startY - 1; // muzzle sits above the tank body
  const dt = PROJ_DT;
  const windAcc = wind * PROJ_WIND_SCALE;
  const targets = opts.targets ?? [];

  const path = [{ x: px, y: py }];
  const MAX_STEPS = 12000;
  let entry = null; // where a penetrating shell entered terrain

  const clampCol = (c) => Math.max(0, Math.min(TERRAIN_W - 1, c));

  for (let i = 0; i < MAX_STEPS; i++) {
    vx += windAcc * dt;
    vy += PROJ_GRAVITY * dt;
    px += vx * dt;
    py += vy * dt;
    if (i % 5 === 0) path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });

    const col = Math.round(px);
    const row = Math.round(py);

    // Direct hit on a tank
    for (const t of targets) {
      if (Math.hypot(px - t.col, py - t.row) <= DIRECT_HIT_RADIUS) {
        path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
        return { path, impact: { x: px, y: py, col: clampCol(col), row }, directHit: t.idx };
      }
    }

    // Off the sides or below the floor → explode at the boundary
    if (col < 0 || col >= TERRAIN_W || row >= TERRAIN_H) {
      path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
      return {
        path,
        impact: { x: px, y: py, col: clampCol(col), row: Math.min(row, TERRAIN_H - 1) },
        directHit: null,
      };
    }

    // Terrain collision (shells above the screen keep flying and fall back)
    if (py >= 0 && isSolid(terrain, col, row)) {
      if (opts.penetrates) {
        if (!entry) entry = { x: px, y: py };
        if (Math.hypot(px - entry.x, py - entry.y) < 3) continue; // burrow deeper
      }
      path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
      return { path, impact: { x: px, y: py, col, row }, directHit: null };
    }
  }
  return {
    path,
    impact: { x: px, y: py, col: clampCol(Math.round(px)), row: Math.min(Math.round(py), TERRAIN_H - 1) },
    directHit: null,
  };
}

// ── Terrain destruction ───────────────────────────────────────────────────────

/**
 * Carve a circular crater into terrain.
 * Returns a new terrain array and list of changed columns {col, newHeight}.
 */
export function carveBlast(terrain, impactCol, blastR) {
  const next = [...terrain];
  const changed = [];

  for (let dx = -blastR; dx <= blastR; dx++) {
    const col = impactCol + dx;
    if (col < 0 || col >= TERRAIN_W) continue;
    // depth of crater at this column (circle cross-section)
    const depth = Math.round(Math.sqrt(blastR * blastR - dx * dx));
    const removed = Math.max(0, depth);
    next[col] = Math.max(2, next[col] - removed);
    changed.push({ col, newHeight: next[col] });
  }

  return { terrain: next, changed };
}

// ── Game state factory ────────────────────────────────────────────────────────

export function createFortressState(p1Id, p2Id, opts = {}) {
  const seed = opts.seed ?? Math.random();
  const terrain = generateTerrain(seed);

  // Place tanks on surface near each side
  const t1col = 8;
  const t2col = 91;

  const makeAmmo = () => Object.fromEntries(
    Object.entries(WEAPONS).map(([k, w]) => [k, w.count])
  );

  return {
    phase: 'aiming',       // aiming | flying | result
    turn: 0,               // whose turn: 0=p1, 1=p2
    turnNumber: 0,
    terrain,
    seed,
    wind: _randomWind(),
    players: [
      {
        id: p1Id,
        col: t1col,
        row: surfaceY(terrain, t1col) - 1,
        hp: 100,
        fuel: MAX_FUEL,
        angle: 45,
        power: 50,
        weapon: 'basic',
        ammo: makeAmmo(),
        facingRight: true,
      },
      {
        id: p2Id,
        col: t2col,
        row: surfaceY(terrain, t2col) - 1,
        hp: 100,
        fuel: MAX_FUEL,
        angle: 135,
        power: 50,
        weapon: 'basic',
        ammo: makeAmmo(),
        facingRight: false,
      },
    ],
    lastShot: null,   // { path, impact, blastR, damage, changed }
    winner: null,
    stake: opts.stake ?? 0,
  };
}

function _randomWind() {
  return parseFloat((Math.random() * 2 - 1).toFixed(2)); // -1..1
}

// ── Actions ───────────────────────────────────────────────────────────────────

/**
 * Move tank left/right by `delta` cells (negative=left).
 * Returns { ok, state, error }.
 */
export function moveTank(state, playerId, delta) {
  const idx = state.players.findIndex(p => p.id === playerId);
  if (idx === -1) return { ok: false, error: 'unknown player' };
  if (state.players[idx].id !== state.players[state.turn].id)
    return { ok: false, error: 'not your turn' };
  if (state.phase !== 'aiming') return { ok: false, error: 'wrong phase' };

  const fuelCost = Math.abs(delta) * TANK_MOVE_FUEL;
  if (state.players[idx].fuel < fuelCost)
    return { ok: false, error: 'not enough fuel' };

  const newCol = Math.max(1, Math.min(TERRAIN_W - 2, state.players[idx].col + delta));
  const newRow = surfaceY(state.terrain, newCol) - 1;

  const next = deepClone(state);
  next.players[idx].col = newCol;
  next.players[idx].row = newRow;
  next.players[idx].fuel -= fuelCost;
  next.players[idx].facingRight = delta > 0;

  return { ok: true, state: next };
}

/**
 * Adjust aim (angle 0..180, power 0..100).
 */
export function aimTank(state, playerId, angle, power) {
  const idx = state.players.findIndex(p => p.id === playerId);
  if (idx === -1) return { ok: false, error: 'unknown player' };
  if (state.players[idx].id !== state.players[state.turn].id)
    return { ok: false, error: 'not your turn' };
  if (state.phase !== 'aiming') return { ok: false, error: 'wrong phase' };

  const next = deepClone(state);
  next.players[idx].angle = Math.max(0, Math.min(180, angle));
  next.players[idx].power = Math.max(1, Math.min(100, power));
  return { ok: true, state: next };
}

/**
 * Switch weapon.
 */
export function selectWeapon(state, playerId, weapon) {
  if (!WEAPONS[weapon]) return { ok: false, error: 'unknown weapon' };
  const idx = state.players.findIndex(p => p.id === playerId);
  if (idx === -1) return { ok: false, error: 'unknown player' };
  if (state.players[idx].id !== state.players[state.turn].id)
    return { ok: false, error: 'not your turn' };

  const next = deepClone(state);
  next.players[idx].weapon = weapon;
  return { ok: true, state: next };
}

/**
 * Fire! Resolves trajectory, terrain destruction, damage.
 * Returns { ok, state, shotResult } where shotResult has path + damage info.
 */
export function fireTank(state, playerId) {
  const idx = state.players.findIndex(p => p.id === playerId);
  if (idx === -1) return { ok: false, error: 'unknown player' };
  if (state.players[idx].id !== state.players[state.turn].id)
    return { ok: false, error: 'not your turn' };
  if (state.phase !== 'aiming') return { ok: false, error: 'wrong phase' };

  const shooter = state.players[idx];
  const weapon = WEAPONS[shooter.weapon];
  if (!weapon) return { ok: false, error: 'unknown weapon' };

  const ammoLeft = shooter.ammo[shooter.weapon];
  if (!(ammoLeft > 0))
    return { ok: false, error: 'out of ammo' };

  const shots = weapon.shots ?? 1;
  let nextState = deepClone(state);

  const allPaths = [];
  const allChanges = [];
  let totalDamage = [0, 0];

  for (let s = 0; s < shots; s++) {
    // Slight spread for triple shot
    const spread = shots > 1 ? (s - 1) * 5 : 0;
    const enemyIdx = 1 - idx;
    const enemy = nextState.players[enemyIdx];
    const { path, impact, directHit } = simulateTrajectory(
      nextState.terrain,
      shooter.col,
      shooter.row,
      shooter.angle + spread,
      shooter.power,
      state.wind,
      {
        penetrates: weapon.penetrates,
        targets: [{ col: enemy.col, row: enemy.row, idx: enemyIdx }],
      },
    );
    allPaths.push(path);

    // Terrain destruction
    if (!weapon.penetrates) {
      const { terrain: newTerrain, changed } = carveBlast(
        nextState.terrain, impact.col, weapon.blastR
      );
      nextState.terrain = newTerrain;
      allChanges.push(...changed);
    }

    // Damage players: direct hit = full damage, otherwise blast falloff
    for (let pi = 0; pi < 2; pi++) {
      const p = nextState.players[pi];
      let dmg = 0;
      if (directHit === pi) {
        dmg = weapon.damage;
      } else {
        const dist = Math.sqrt((p.col - impact.col) ** 2 + (p.row - impact.row) ** 2);
        if (dist <= weapon.blastR * 1.5) {
          dmg = Math.round(weapon.damage * (1 - dist / (weapon.blastR * 1.5 + 1)));
        }
      }
      if (dmg > 0) {
        p.hp = Math.max(0, p.hp - dmg);
        totalDamage[pi] += dmg;
      }
    }
  }

  // Consume ammo
  if (nextState.players[idx].ammo[shooter.weapon] < UNLIMITED_AMMO) {
    nextState.players[idx].ammo[shooter.weapon]--;
  }

  // Re-seat tanks after terrain change
  for (const p of nextState.players) {
    p.row = surfaceY(nextState.terrain, p.col) - 1;
  }

  // Check win condition
  const loserIdx = nextState.players[1 - idx].hp <= 0 ? 1 - idx : -1;
  const selfDeadIdx = nextState.players[idx].hp <= 0 ? idx : -1;
  let winner = null;
  if (loserIdx >= 0 && selfDeadIdx < 0) winner = nextState.players[idx].id;
  else if (selfDeadIdx >= 0 && loserIdx < 0) winner = nextState.players[1 - idx].id;
  // mutual destruction → no winner (turnNumber increment will handle sudden death)

  const shotResult = {
    paths: allPaths,
    impact: { col: Math.round(allPaths[0].at(-1)?.x ?? 0), row: Math.round(allPaths[0].at(-1)?.y ?? 0) },
    blastR: weapon.blastR,
    damage: totalDamage,
    terrainChanges: allChanges,
  };

  nextState.phase = winner ? 'result' : 'aiming';
  nextState.winner = winner;
  nextState.lastShot = shotResult;

  if (!winner) {
    // Advance turn
    nextState.turn = 1 - nextState.turn;
    nextState.turnNumber++;
    nextState.wind = _randomWind();
    // Refuel next player partially
    const nextIdx = nextState.turn;
    nextState.players[nextIdx].fuel = Math.min(MAX_FUEL, nextState.players[nextIdx].fuel + 10);

    // Sudden death check
    if (nextState.turnNumber >= MAX_TURNS * 2) {
      // Player with more HP wins; tie → no winner
      const [hp0, hp1] = nextState.players.map(p => p.hp);
      if (hp0 !== hp1) {
        nextState.winner = nextState.players[hp0 > hp1 ? 0 : 1].id;
        nextState.phase = 'result';
      }
    }
  }

  return { ok: true, state: nextState, shotResult };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function deepClone(obj) {
  return structuredClone(obj); // preserves Infinity, NaN, etc.
}
