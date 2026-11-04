// fortress-engine.js — 탱크 대작전 2.0 게임 엔진
// 서버 권위: 탄도·지형 파괴·피해·보급·낙하·턴/타임아웃 판정을 모두 여기서 계산하고,
// 클라이언트는 shotResult.events를 순서대로 재생만 한다.
//
// 주요 개념
// - 단계(phase): select(전차 선택, 비공개) → aiming(턴 진행) → result
// - 전차 4종(TANK_CLASSES), 공용 무기 5종 + 전차 전용 특수탄 4종(WEAPONS)
// - 테마 맵 4종(THEMES): 중력·바람 계수와 지형 파라미터가 다르다
// - 보급 상자(crates): 일정 턴마다 낙하, 이동/포격으로 획득
// - 낙하 피해, 경사 이동 제한, 맵 밖 포탄 소멸
// - 30초 턴 타이머(소켓 계층이 예약) + 3회 연속 시간 초과 시 기권패
// - 서든데스(SUDDEN_DEATH_TURN부터 피해·바람 강화) + 최대 턴 도달 시 HP 비율 판정

export const TERRAIN_W = 100; // columns
export const TERRAIN_H = 40;  // rows (0=top, TERRAIN_H-1=bottom)
export const TANK_MOVE_FUEL = 3; // fuel per cell moved (기본)
export const MAX_FUEL = 30;      // 기본 연료 (전차별 maxFuel이 우선)
export const MAX_TURNS = 15;     // 하위호환용: 각자 15턴 = 30턴에서 판정
export const GRAVITY = 9.8;
export const TURN_TIME_MS = 30_000;
export const MAX_TIMEOUTS = 3;
export const SUDDEN_DEATH_TURN = 20;          // 전체 턴 수(양쪽 합) 기준
export const FINAL_TURN = MAX_TURNS * 2;      // 30턴이면 판정
export const SUDDEN_DEATH_DAMAGE_MUL = 1.5;
export const CRATE_INTERVAL = 3;              // 3턴마다 보급
export const MAX_CRATES = 2;
export const CRATE_PICKUP_RANGE = 1;          // 이동 시 획득 거리(칸)
export const MAX_SLOPE_STEP = 3;              // 한 칸 이동 시 오를 수 있는 최대 높이
export const FALL_SAFE_ROWS = 3;              // 이 높이까지는 낙하 피해 없음
export const FALL_DAMAGE_PER_ROW = 4;
export const MOVE_STEP_LIMIT = 10;

// count >= UNLIMITED_AMMO means 무제한 — Infinity는 JSON(Redis) 직렬화에서 null이 되므로 금지
export const UNLIMITED_AMMO = 999;

// ── 전차 ─────────────────────────────────────────────────────────────────────
export const TANK_CLASSES = {
  rhino:  { name: '코뿔소', hp: 130, fuel: 24, special: 'quake',   specialCount: 1, damageTakenMul: 0.9, desc: '단단한 장갑으로 받는 피해 10% 감소' },
  falcon: { name: '매',     hp: 90,  fuel: 45, special: 'shotgun', specialCount: 1, moveCostMul: 0.5,    desc: '가벼운 차체로 이동 연료 절반' },
  mole:   { name: '땅굴이', hp: 105, fuel: 30, special: 'drill',   specialCount: 2, fallImmune: true,   desc: '낙하 피해 면역, 땅을 파고드는 드릴탄' },
  turtle: { name: '거북',   hp: 115, fuel: 28, special: 'wall',    specialCount: 2, regenPerTurn: 3,    desc: '내 턴마다 HP 3 회복, 방벽 생성' },
};
export const TANK_CLASS_IDS = Object.keys(TANK_CLASSES);

// ── 무기 ─────────────────────────────────────────────────────────────────────
// kind: blast(폭발) | cluster(정점에서 분열) | teleport(이동) | wall(흙 언덕) | spread(부채꼴 다발)
export const WEAPONS = {
  basic:    { name: '기본탄',     damage: 30, blastR: 4, count: UNLIMITED_AMMO, kind: 'blast' },
  heavy:    { name: '대형탄',     damage: 55, blastR: 6, count: 2, kind: 'blast' },
  triple:   { name: '3연발탄',    damage: 22, blastR: 3, count: 2, kind: 'spread', shots: 3, spreadDeg: 5 },
  cluster:  { name: '집속탄',     damage: 18, blastR: 3, count: 1, kind: 'cluster', bomblets: 4 },
  teleport: { name: '순간이동탄', damage: 0,  blastR: 0, count: 1, kind: 'teleport' },
  // 전차 전용 특수탄
  quake:    { name: '지진탄',     damage: 50, blastR: 9, count: 0, kind: 'blast', special: 'rhino' },
  shotgun:  { name: '산탄',       damage: 14, blastR: 2, count: 0, kind: 'spread', shots: 5, spreadDeg: 8, special: 'falcon' },
  drill:    { name: '드릴탄',     damage: 50, blastR: 3, count: 0, kind: 'blast', penetrates: true, special: 'mole' },
  wall:     { name: '방벽탄',     damage: 0,  blastR: 5, count: 0, kind: 'wall', special: 'turtle' },
};
export const WEAPON_IDS = Object.keys(WEAPONS);
export const COMMON_WEAPON_IDS = WEAPON_IDS.filter((id) => !WEAPONS[id].special);

// ── 보급 ─────────────────────────────────────────────────────────────────────
export const CRATE_ITEMS = {
  repair: { name: '수리 키트' },
  power:  { name: '화력 강화' },
  shield: { name: '보호막' },
  fuel:   { name: '연료 통' },
  ammo:   { name: '탄약 상자' },
};
export const CRATE_ITEM_IDS = Object.keys(CRATE_ITEMS);
export const REPAIR_AMOUNT = 25;
export const POWER_BUFF_MUL = 1.5;
export const SHIELD_ABSORB = 0.5;

// ── 테마 ─────────────────────────────────────────────────────────────────────
export const THEMES = {
  meadow: { name: '초원', gravityMul: 1.0,  windMul: 1.0, base: [15, 24], amp: [4, 9] },
  desert: { name: '사막', gravityMul: 1.0,  windMul: 1.3, base: [13, 21], amp: [7, 12] },
  snow:   { name: '설원', gravityMul: 1.0,  windMul: 1.6, base: [16, 24], amp: [4, 8] },
  moon:   { name: '달',   gravityMul: 0.55, windMul: 0,   base: [14, 22], amp: [5, 10] },
};
export const THEME_IDS = Object.keys(THEMES);

export const DIRECT_HIT_RADIUS = 1.8; // 직격 판정 반경

// ── Terrain ──────────────────────────────────────────────────────────────────

/**
 * Generate a terrain heightmap (index = column, value = solid rows from bottom).
 * 같은 seed·theme이면 같은 지형.
 */
export function generateTerrain(seed = Math.random(), themeId = 'meadow') {
  const theme = THEMES[themeId] ?? THEMES.meadow;
  const heights = new Array(TERRAIN_W);
  let rng = seed;
  const next = () => { rng = (rng * 9301 + 49297) % 233280; return rng / 233280; };

  const base = theme.base[0] + Math.floor(next() * (theme.base[1] - theme.base[0] + 1));
  const amp1 = theme.amp[0] + next() * (theme.amp[1] - theme.amp[0]);
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

  // Flatten small platforms near tanks (cols 4-11 and 88-95)
  for (let x = 4; x <= 11; x++) heights[x] = heights[7];
  for (let x = 88; x <= 95; x++) heights[x] = heights[91];

  return heights;
}

export function isSolid(terrain, x, y) {
  if (x < 0 || x >= TERRAIN_W) return true; // walls are solid
  if (y < 0) return false;
  if (y >= TERRAIN_H) return true;
  return y >= TERRAIN_H - terrain[x];
}

/** Surface Y for column x (first solid row from top) */
export function surfaceY(terrain, x) {
  return TERRAIN_H - terrain[x];
}

// ── Ballistic simulation ──────────────────────────────────────────────────────

// Physics constants — mirrored in the Flutter client for aim preview.
export const PROJ_SPEED_SCALE = 0.35; // velocity = power * scale
export const PROJ_GRAVITY = 12;       // cells/s² (× theme gravityMul)
export const PROJ_WIND_SCALE = 1.5;   // wind accel = wind * scale (cells/s²)
export const PROJ_DT = 0.02;          // integration step (s)

/**
 * Simulate projectile trajectory with terrain collision.
 * angle: degrees above horizontal (0=right, 90=up, 180=left); power 1..100;
 * wind: 상태의 바람(테마 계수 반영 후). opts.gravityMul: 중력 계수.
 * opts.targets: [{col,row,idx}] 직격 판정. opts.penetrates: 3칸 파고든 뒤 폭발.
 * opts.splitAtApex: 정점(상승→하강 전환)에서 멈추고 apex 정보를 돌려준다(집속탄).
 * opts.start: {vx, vy} 초기 속도를 직접 지정(집속탄 자탄).
 * Returns { path, impact: {x,y,col,row}|null, directHit, outOfBounds, apex? }.
 */
export function simulateTrajectory(terrain, startX, startY, angleDeg, power, wind, opts = {}) {
  const radians = (angleDeg * Math.PI) / 180;
  const speed = power * PROJ_SPEED_SCALE;
  let vx = opts.start ? opts.start.vx : Math.cos(radians) * speed;
  let vy = opts.start ? opts.start.vy : -Math.sin(radians) * speed; // negative = upward
  let px = startX;
  let py = opts.start ? startY : startY - 1; // muzzle sits above the tank body
  const dt = PROJ_DT;
  const windAcc = wind * PROJ_WIND_SCALE;
  const gravity = PROJ_GRAVITY * (opts.gravityMul ?? 1);
  const targets = opts.targets ?? [];

  const path = [{ x: +px.toFixed(2), y: +py.toFixed(2) }];
  const MAX_STEPS = 12000;
  let entry = null;
  const clampCol = (c) => Math.max(0, Math.min(TERRAIN_W - 1, c));

  for (let i = 0; i < MAX_STEPS; i++) {
    const prevVy = vy;
    vx += windAcc * dt;
    vy += gravity * dt;
    px += vx * dt;
    py += vy * dt;
    if (i % 5 === 0) path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });

    if (opts.splitAtApex && prevVy < 0 && vy >= 0) {
      path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
      return { path, impact: null, directHit: null, outOfBounds: false, apex: { x: px, y: py, vx, vy } };
    }

    const col = Math.round(px);
    const row = Math.round(py);

    for (const t of targets) {
      if (Math.hypot(px - t.col, py - t.row) <= DIRECT_HIT_RADIUS) {
        path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
        return { path, impact: { x: px, y: py, col: clampCol(col), row }, directHit: t.idx, outOfBounds: false };
      }
    }

    // 좌우로 맵을 벗어난 포탄은 폭발하지 않고 사라진다(벽 근처 억울한 피해 방지).
    if (col < 0 || col >= TERRAIN_W) {
      path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
      return { path, impact: null, directHit: null, outOfBounds: true };
    }
    if (row >= TERRAIN_H) {
      path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
      return { path, impact: { x: px, y: py, col: clampCol(col), row: TERRAIN_H - 1 }, directHit: null, outOfBounds: false };
    }

    if (py >= 0 && isSolid(terrain, col, row)) {
      if (opts.penetrates) {
        if (!entry) entry = { x: px, y: py };
        if (Math.hypot(px - entry.x, py - entry.y) < 3) continue; // burrow deeper
      }
      path.push({ x: +px.toFixed(2), y: +py.toFixed(2) });
      return { path, impact: { x: px, y: py, col, row }, directHit: null, outOfBounds: false };
    }
  }
  return {
    path,
    impact: { x: px, y: py, col: clampCol(Math.round(px)), row: Math.min(Math.round(py), TERRAIN_H - 1) },
    directHit: null,
    outOfBounds: false,
  };
}

// ── Terrain destruction / creation ────────────────────────────────────────────

/** Carve a circular crater. Returns { terrain, changed[{col,newHeight}] }. */
export function carveBlast(terrain, impactCol, blastR) {
  const next = [...terrain];
  const changed = [];
  for (let dx = -blastR; dx <= blastR; dx++) {
    const col = impactCol + dx;
    if (col < 0 || col >= TERRAIN_W) continue;
    const depth = Math.round(Math.sqrt(blastR * blastR - dx * dx));
    next[col] = Math.max(2, next[col] - Math.max(0, depth));
    changed.push({ col, newHeight: next[col] });
  }
  return { terrain: next, changed };
}

/** Raise a mound (방벽탄). Returns { terrain, changed }. */
export function raiseMound(terrain, centerCol, radius) {
  const next = [...terrain];
  const changed = [];
  const peak = Math.max(3, Math.round(radius * 1.2));
  for (let dx = -radius; dx <= radius; dx++) {
    const col = centerCol + dx;
    if (col < 0 || col >= TERRAIN_W) continue;
    const add = Math.round(peak * Math.cos((dx / (radius + 1)) * (Math.PI / 2)));
    next[col] = Math.min(TERRAIN_H - 3, next[col] + Math.max(0, add));
    changed.push({ col, newHeight: next[col] });
  }
  return { terrain: next, changed };
}

// ── Game state factory ────────────────────────────────────────────────────────

const makePlayer = (id, col, terrain, facingRight) => ({
  id,
  tankClass: null,
  col,
  row: surfaceY(terrain, col) - 1,
  hp: 100,
  maxHp: 100,
  fuel: MAX_FUEL,
  maxFuel: MAX_FUEL,
  angle: facingRight ? 45 : 135,
  power: 50,
  weapon: 'basic',
  ammo: Object.fromEntries(COMMON_WEAPON_IDS.map((k) => [k, WEAPONS[k].count])),
  facingRight,
  buffs: { power: false, shield: false },
  stats: { shots: 0, hits: 0, directHits: 0, damageDealt: 0, maxHit: 0, crates: 0 },
});

export function createFortressState(p1Id, p2Id, opts = {}) {
  const seed = opts.seed ?? Math.random();
  const themeId = THEMES[opts.theme] ? opts.theme : THEME_IDS[Math.floor((opts.random ?? Math.random)() * THEME_IDS.length)];
  const theme = THEMES[themeId];
  const terrain = generateTerrain(seed, themeId);

  const state = {
    gameId: opts.gameId ?? null,
    phase: 'select',
    turn: 0,
    turnNumber: 0,
    theme: themeId,
    gravityMul: theme.gravityMul,
    windMul: theme.windMul,
    terrain,
    seed,
    wind: 0,
    turnDeadline: null,
    timeouts: [0, 0],
    crates: [],
    crateSeq: 0,
    suddenDeath: false,
    players: [makePlayer(p1Id, 8, terrain, true), makePlayer(p2Id, 91, terrain, false)],
    lastShot: null,
    winner: null,
    endReason: null,
    stake: opts.stake ?? 0,
    series: opts.series ?? { [p1Id]: 0, [p2Id]: 0 },
  };
  state.wind = rollWind(state, opts.random);
  // 테스트/하위호환: 전차를 미리 지정하면 선택 단계를 건너뛴다.
  if (opts.classes) {
    let s = state;
    for (const p of s.players) {
      const r = selectTankClass(s, p.id, opts.classes[p.id] ?? 'turtle');
      if (r.ok) s = r.state;
    }
    return s;
  }
  return state;
}

export function rollWind(state, random = Math.random) {
  const sdMul = state.suddenDeath ? 1.5 : 1;
  const raw = (random() * 2 - 1) * (state.windMul ?? 1) * sdMul;
  return parseFloat(Math.max(-2, Math.min(2, raw)).toFixed(2));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function deepClone(obj) {
  return structuredClone(obj);
}

const findIdx = (state, playerId) => state.players.findIndex((p) => p.id === playerId);

function requireTurn(state, playerId) {
  const idx = findIdx(state, playerId);
  if (idx === -1) return { error: 'unknown player' };
  if (state.phase !== 'aiming') return { error: 'wrong phase' };
  if (state.players[state.turn].id !== playerId) return { error: 'not your turn' };
  return { idx };
}

const classOf = (player) => TANK_CLASSES[player.tankClass] ?? null;

// ── 전차 선택 ─────────────────────────────────────────────────────────────────

/** 비공개 전차 선택. 둘 다 고르면 전차 능력치를 적용하고 aiming으로 전환한다. */
export function selectTankClass(state, playerId, classId) {
  if (state.phase !== 'select') return { ok: false, error: 'wrong phase' };
  const idx = findIdx(state, playerId);
  if (idx === -1) return { ok: false, error: 'unknown player' };
  if (!TANK_CLASSES[classId]) return { ok: false, error: 'unknown class' };

  const next = deepClone(state);
  next.players[idx].tankClass = classId;
  if (next.players.every((p) => p.tankClass)) {
    for (const p of next.players) {
      const c = TANK_CLASSES[p.tankClass];
      p.hp = c.hp;
      p.maxHp = c.hp;
      p.fuel = c.fuel;
      p.maxFuel = c.fuel;
      p.ammo[c.special] = c.specialCount;
    }
    next.phase = 'aiming';
  }
  return { ok: true, state: next };
}

// ── 이동 ─────────────────────────────────────────────────────────────────────

/**
 * Move tank left/right by `delta` cells (negative=left). 한 칸씩 이동하며,
 * 경사가 MAX_SLOPE_STEP을 넘는 칸은 오를 수 없어 그 앞에서 멈춘다.
 * 보급 상자 1칸 이내로 오면 자동 획득한다.
 */
export function moveTank(state, playerId, delta) {
  const turnCheck = requireTurn(state, playerId);
  if (turnCheck.error) return { ok: false, error: turnCheck.error };
  const { idx } = turnCheck;
  if (!Number.isInteger(delta) || delta === 0 || Math.abs(delta) > MOVE_STEP_LIMIT) {
    return { ok: false, error: 'invalid delta' };
  }

  const player = state.players[idx];
  const costPerCell = TANK_MOVE_FUEL * (classOf(player)?.moveCostMul ?? 1);
  if (player.fuel + 1e-9 < costPerCell * Math.abs(delta)) return { ok: false, error: 'not enough fuel' };

  const next = deepClone(state);
  const me = next.players[idx];
  const dir = Math.sign(delta);
  const events = [];
  let moved = 0;
  for (let i = 0; i < Math.abs(delta); i++) {
    const target = me.col + dir;
    if (target < 1 || target > TERRAIN_W - 2) break;
    const rise = surfaceY(next.terrain, me.col) - surfaceY(next.terrain, target); // 양수 = 오르막
    if (rise > MAX_SLOPE_STEP) {
      events.push({ type: 'blocked', target: idx, col: target });
      break;
    }
    me.col = target;
    me.row = surfaceY(next.terrain, target) - 1;
    me.fuel = Math.round((me.fuel - costPerCell) * 10) / 10;
    moved++;
    collectCratesNear(next, idx, events);
  }
  me.facingRight = delta > 0;
  if (moved === 0 && events.every((e) => e.type === 'blocked')) {
    return { ok: false, error: 'blocked', state: next };
  }
  return { ok: true, state: next, events };
}

/** Adjust aim (angle 0..180, power 1..100). 상대에게는 공개되지 않는다(viewFor). */
export function aimTank(state, playerId, angle, power) {
  const turnCheck = requireTurn(state, playerId);
  if (turnCheck.error) return { ok: false, error: turnCheck.error };
  const next = deepClone(state);
  next.players[turnCheck.idx].angle = Math.max(0, Math.min(180, Number(angle) || 0));
  next.players[turnCheck.idx].power = Math.max(1, Math.min(100, Number(power) || 1));
  return { ok: true, state: next };
}

/** Switch weapon. 보유하지 않은 무기(다른 전차 전용탄 포함)는 선택할 수 없다. */
export function selectWeapon(state, playerId, weapon) {
  if (!WEAPONS[weapon]) return { ok: false, error: 'unknown weapon' };
  const idx = findIdx(state, playerId);
  if (idx === -1) return { ok: false, error: 'unknown player' };
  if (state.players[state.turn].id !== playerId) return { ok: false, error: 'not your turn' };
  if (!(weapon in state.players[idx].ammo)) return { ok: false, error: 'weapon not owned' };
  const next = deepClone(state);
  next.players[idx].weapon = weapon;
  return { ok: true, state: next };
}

// ── 보급 ─────────────────────────────────────────────────────────────────────

function applyCrate(state, playerIdx, crate, events) {
  const p = state.players[playerIdx];
  switch (crate.item) {
    case 'repair': {
      const before = p.hp;
      p.hp = Math.min(p.maxHp, p.hp + REPAIR_AMOUNT);
      events.push({ type: 'heal', target: playerIdx, amount: p.hp - before });
      break;
    }
    case 'power': p.buffs.power = true; break;
    case 'shield': p.buffs.shield = true; break;
    case 'fuel': p.fuel = p.maxFuel; break;
    case 'ammo': p.ammo.heavy = (p.ammo.heavy ?? 0) + 1; break;
    default: break;
  }
  p.stats.crates += 1;
  events.push({ type: 'crate', crateId: crate.id, owner: playerIdx, item: crate.item, col: crate.col, row: crate.row });
}

function collectCratesNear(state, playerIdx, events) {
  const p = state.players[playerIdx];
  const remaining = [];
  for (const crate of state.crates) {
    if (Math.abs(crate.col - p.col) <= CRATE_PICKUP_RANGE) applyCrate(state, playerIdx, crate, events);
    else remaining.push(crate);
  }
  state.crates = remaining;
}

function spawnCrate(state, random = Math.random) {
  if (state.crates.length >= MAX_CRATES) return null;
  for (let attempt = 0; attempt < 12; attempt++) {
    const col = 15 + Math.floor(random() * 71); // 15..85
    const nearTank = state.players.some((p) => Math.abs(p.col - col) <= 4);
    const nearCrate = state.crates.some((c) => Math.abs(c.col - col) <= 3);
    if (nearTank || nearCrate) continue;
    const crate = {
      id: `c${++state.crateSeq}`,
      col,
      row: surfaceY(state.terrain, col) - 1,
      item: CRATE_ITEM_IDS[Math.floor(random() * CRATE_ITEM_IDS.length)],
    };
    state.crates.push(crate);
    return crate;
  }
  return null;
}

// ── 피해 ─────────────────────────────────────────────────────────────────────

function applyDamage(state, shooterIdx, targetIdx, rawDamage, events, meta = {}) {
  const target = state.players[targetIdx];
  let dmg = rawDamage * (classOf(target)?.damageTakenMul ?? 1);
  if (target.buffs.shield && dmg > 0) {
    const absorbed = Math.round(dmg * SHIELD_ABSORB);
    dmg -= absorbed;
    target.buffs.shield = false;
    events.push({ type: 'shield', target: targetIdx, absorbed, stage: meta.stage ?? 0 });
  }
  dmg = Math.max(0, Math.round(dmg));
  if (dmg <= 0) return 0;
  target.hp = Math.max(0, target.hp - dmg);
  events.push({ type: 'damage', target: targetIdx, amount: dmg, direct: !!meta.direct, stage: meta.stage ?? 0, cause: meta.cause ?? 'blast' });
  if (shooterIdx != null && shooterIdx !== targetIdx) {
    const s = state.players[shooterIdx].stats;
    s.damageDealt += dmg;
  }
  return dmg;
}

/** 폭발: 지형을 깎고 반경 내 전차에 피해, 반경 내 보급은 사수가 획득. */
function resolveBlast(state, shooterIdx, impact, weapon, damageMul, events, stage, directHitIdx) {
  if (weapon.kind === 'wall') {
    const { terrain, changed } = raiseMound(state.terrain, impact.col, weapon.blastR);
    state.terrain = terrain;
    events.push({ type: 'mound', col: impact.col, r: weapon.blastR, changed, stage });
    return { dealt: [0, 0], hitAny: false };
  }
  if (!weapon.penetrates) {
    const { terrain, changed } = carveBlast(state.terrain, impact.col, weapon.blastR);
    state.terrain = terrain;
    events.push({ type: 'blast', col: impact.col, row: impact.row, r: weapon.blastR, changed, stage });
  } else {
    events.push({ type: 'blast', col: impact.col, row: impact.row, r: weapon.blastR, changed: [], stage });
  }

  const dealt = [0, 0];
  for (let pi = 0; pi < state.players.length; pi++) {
    const p = state.players[pi];
    let dmg = 0;
    const direct = directHitIdx === pi;
    if (direct) {
      dmg = weapon.damage;
    } else {
      const dist = Math.hypot(p.col - impact.col, p.row - impact.row);
      if (dist <= weapon.blastR * 1.5) {
        dmg = weapon.damage * (1 - dist / (weapon.blastR * 1.5 + 1));
      }
    }
    if (dmg > 0) dealt[pi] += applyDamage(state, shooterIdx, pi, dmg * damageMul, events, { direct, stage });
  }

  // 폭발 반경 안의 보급 상자는 사수가 획득
  const remaining = [];
  for (const crate of state.crates) {
    if (Math.hypot(crate.col - impact.col, crate.row - impact.row) <= weapon.blastR + 1) {
      applyCrate(state, shooterIdx, crate, events);
    } else {
      remaining.push(crate);
    }
  }
  state.crates = remaining;
  return { dealt, hitAny: dealt[1 - shooterIdx] > 0 };
}

/** 지형 변화 뒤 전차·보급을 지면에 다시 앉힌다. 높이 떨어지면 낙하 피해. */
function settleBodies(state, events) {
  for (let pi = 0; pi < state.players.length; pi++) {
    const p = state.players[pi];
    const newRow = surfaceY(state.terrain, p.col) - 1;
    const drop = newRow - p.row;
    p.row = newRow;
    if (drop > FALL_SAFE_ROWS && !classOf(p)?.fallImmune) {
      const damage = (drop - FALL_SAFE_ROWS) * FALL_DAMAGE_PER_ROW;
      const before = p.hp;
      p.hp = Math.max(0, p.hp - damage);
      events.push({ type: 'fall', target: pi, rows: drop, damage: before - p.hp });
    } else if (drop > 0) {
      events.push({ type: 'fall', target: pi, rows: drop, damage: 0 });
    }
  }
  for (const crate of state.crates) crate.row = surfaceY(state.terrain, crate.col) - 1;
}

// ── 턴 진행 / 승패 ────────────────────────────────────────────────────────────

function decideWinner(state) {
  const [a, b] = state.players;
  const aDead = a.hp <= 0;
  const bDead = b.hp <= 0;
  if (aDead && bDead) return { winner: 'draw', reason: 'mutual_ko' };
  if (aDead) return { winner: b.id, reason: 'ko' };
  if (bDead) return { winner: a.id, reason: 'ko' };
  return null;
}

function finish(state, winner, reason) {
  state.phase = 'result';
  state.winner = winner;
  state.endReason = reason;
  state.turnDeadline = null;
  if (winner && winner !== 'draw' && state.series) {
    state.series[winner] = (state.series[winner] ?? 0) + 1;
  }
}

/** 다음 턴으로: 바람·연료·회복·보급·서든데스·최종 판정. */
function advanceTurn(state, events, random = Math.random) {
  state.turn = 1 - state.turn;
  state.turnNumber += 1;

  if (!state.suddenDeath && state.turnNumber >= SUDDEN_DEATH_TURN) {
    state.suddenDeath = true;
    events.push({ type: 'sudden_death' });
  }

  if (state.turnNumber >= FINAL_TURN) {
    // HP 비율로 판정(전차마다 최대 HP가 다르므로 비율 비교), 같으면 무승부
    const [a, b] = state.players;
    const ra = a.hp / a.maxHp;
    const rb = b.hp / b.maxHp;
    if (Math.abs(ra - rb) < 1e-9) finish(state, 'draw', 'time_draw');
    else finish(state, ra > rb ? a.id : b.id, 'time');
    return;
  }

  state.wind = rollWind(state, random);
  const p = state.players[state.turn];
  p.fuel = Math.min(p.maxFuel, Math.round((p.fuel + 10) * 10) / 10);
  const regen = classOf(p)?.regenPerTurn ?? 0;
  if (regen > 0 && p.hp > 0 && p.hp < p.maxHp) {
    const before = p.hp;
    p.hp = Math.min(p.maxHp, p.hp + regen);
    events.push({ type: 'heal', target: state.turn, amount: p.hp - before, cause: 'regen' });
  }
  if (state.turnNumber % CRATE_INTERVAL === 0) {
    const crate = spawnCrate(state, random);
    if (crate) events.push({ type: 'crate_drop', crateId: crate.id, col: crate.col, row: crate.row });
  }
}

/**
 * 턴 시간 초과: 현재 차례 플레이어의 시간 초과를 누적하고 턴을 넘긴다.
 * MAX_TIMEOUTS회 연속이면 기권패(endReason 'afk').
 */
export function timeoutTurn(state, opts = {}) {
  if (state.phase !== 'aiming') return { ok: false, error: 'wrong phase' };
  const next = deepClone(state);
  const idx = next.turn;
  next.timeouts = [...(next.timeouts ?? [0, 0])];
  next.timeouts[idx] += 1;
  const events = [{ type: 'timeout', target: idx, count: next.timeouts[idx] }];
  if (next.timeouts[idx] >= MAX_TIMEOUTS) {
    finish(next, next.players[1 - idx].id, 'afk');
    return { ok: true, state: next, events, forfeited: true };
  }
  advanceTurn(next, events, opts.random);
  return { ok: true, state: next, events, forfeited: false };
}

// ── 발사 ─────────────────────────────────────────────────────────────────────

/**
 * Fire! aim({angle, power, weapon})을 함께 받으면 그 값으로 발사한다(조준은 로컬,
 * 서버는 발사 시점에만 받는다). 탄도·지형·피해·보급·낙하·턴 진행을 모두 처리한다.
 * Returns { ok, state, shotResult }.
 */
export function fireTank(state, playerId, aim = {}, opts = {}) {
  const turnCheck = requireTurn(state, playerId);
  if (turnCheck.error) return { ok: false, error: turnCheck.error };
  const idx = turnCheck.idx;

  let next = deepClone(state);
  const shooter = next.players[idx];
  if (aim.angle != null) shooter.angle = Math.max(0, Math.min(180, Number(aim.angle) || 0));
  if (aim.power != null) shooter.power = Math.max(1, Math.min(100, Number(aim.power) || 1));
  if (aim.weapon != null) {
    if (!WEAPONS[aim.weapon]) return { ok: false, error: 'unknown weapon' };
    if (!(aim.weapon in shooter.ammo)) return { ok: false, error: 'weapon not owned' };
    shooter.weapon = aim.weapon;
  }

  const weaponId = shooter.weapon;
  const weapon = WEAPONS[weaponId];
  if (!weapon) return { ok: false, error: 'unknown weapon' };
  if (!(shooter.ammo[weaponId] > 0)) return { ok: false, error: 'out of ammo' };

  const enemyIdx = 1 - idx;
  const events = [];
  const allPaths = [];
  let firstImpact = null;
  let damageMul = shooter.buffs.power ? POWER_BUFF_MUL : 1;
  if (next.suddenDeath) damageMul *= SUDDEN_DEATH_DAMAGE_MUL;
  if (shooter.buffs.power) {
    shooter.buffs.power = false;
    events.push({ type: 'buff_used', target: idx, buff: 'power' });
  }
  const dealtTotal = [0, 0];
  let hitEnemy = false;
  let directHitEnemy = false;

  const shoot = (angle, power, stage, extra = {}) => {
    const enemy = next.players[enemyIdx];
    const result = simulateTrajectory(
      next.terrain, extra.x ?? shooter.col, extra.y ?? shooter.row, angle, power, next.wind,
      {
        gravityMul: next.gravityMul,
        penetrates: weapon.penetrates,
        targets: weapon.kind === 'teleport' ? [] : [{ col: enemy.col, row: enemy.row, idx: enemyIdx }],
        splitAtApex: extra.splitAtApex,
        start: extra.start,
      },
    );
    allPaths.push(result.path);
    events.push({ type: 'shell', path: result.path, stage, weapon: weaponId });
    return result;
  };

  const blastAt = (result, stage, w = weapon) => {
    if (!result.impact) return;
    firstImpact ??= result.impact;
    const { dealt } = resolveBlast(next, idx, result.impact, w, damageMul, events, stage, result.directHit);
    dealtTotal[0] += dealt[0];
    dealtTotal[1] += dealt[1];
    if (dealt[enemyIdx] > 0) hitEnemy = true;
    if (result.directHit === enemyIdx) directHitEnemy = true;
  };

  if (weapon.kind === 'spread') {
    const n = weapon.shots;
    for (let s = 0; s < n; s++) {
      const offset = (s - (n - 1) / 2) * weapon.spreadDeg;
      blastAt(shoot(shooter.angle + offset, shooter.power, 0), 0);
    }
  } else if (weapon.kind === 'cluster') {
    const main = shoot(shooter.angle, shooter.power, 0, { splitAtApex: true });
    if (main.apex) {
      events.push({ type: 'split', col: main.apex.x, row: main.apex.y, stage: 0 });
      const n = weapon.bomblets;
      for (let b = 0; b < n; b++) {
        const spreadVx = main.apex.vx + (b - (n - 1) / 2) * 2.2;
        blastAt(shoot(0, 0, 1, { x: main.apex.x, y: main.apex.y, start: { vx: spreadVx, vy: 0.5 } }), 1);
      }
    } else {
      blastAt(main, 0); // 정점 전에 착탄(직사)하면 그 자리에서 폭발
    }
  } else if (weapon.kind === 'teleport') {
    const result = shoot(shooter.angle, shooter.power, 0);
    if (result.impact) {
      const col = Math.max(1, Math.min(TERRAIN_W - 2, result.impact.col));
      shooter.col = col;
      shooter.row = surfaceY(next.terrain, col) - 1;
      shooter.facingRight = shooter.col < next.players[enemyIdx].col;
      events.push({ type: 'teleport', target: idx, col: shooter.col, row: shooter.row, stage: 0 });
      collectCratesNear(next, idx, events);
      firstImpact = result.impact;
    }
  } else {
    blastAt(shoot(shooter.angle, shooter.power, 0), 0);
  }

  if (shooter.ammo[weaponId] < UNLIMITED_AMMO) shooter.ammo[weaponId] -= 1;
  // 탄을 다 쓴 무기를 들고 있지 않도록 기본탄으로 되돌린다.
  if (!(shooter.ammo[weaponId] > 0)) shooter.weapon = 'basic';

  settleBodies(next, events);

  // 통계
  shooter.stats.shots += 1;
  if (hitEnemy) shooter.stats.hits += 1;
  if (directHitEnemy) shooter.stats.directHits += 1;
  shooter.stats.maxHit = Math.max(shooter.stats.maxHit, dealtTotal[enemyIdx]);
  next.timeouts = [...(next.timeouts ?? [0, 0])];
  next.timeouts[idx] = 0; // 발사하면 연속 시간 초과 초기화

  const shotResult = {
    shooter: idx,
    weapon: weaponId,
    angle: shooter.angle,
    power: shooter.power,
    paths: allPaths,
    impact: firstImpact
      ? { col: Math.round(firstImpact.col ?? firstImpact.x), row: Math.round(firstImpact.row ?? firstImpact.y) }
      : null,
    blastR: weapon.blastR,
    damage: dealtTotal,
    events,
    turnNumber: next.turnNumber,
  };

  const outcome = decideWinner(next);
  if (outcome) {
    finish(next, outcome.winner, outcome.reason);
  } else {
    advanceTurn(next, events, opts.random);
  }
  next.lastShot = shotResult;
  return { ok: true, state: next, shotResult };
}

// ── 보는 사람별 마스킹 ────────────────────────────────────────────────────────

/**
 * viewer에게 보낼 상태. 상대의 조준(angle/power)은 발사 전까지 비공개,
 * 선택 단계에서는 상대 전차도 비공개(골랐는지 여부만).
 */
export function viewFor(state, viewerId) {
  return {
    ...state,
    players: state.players.map((p) => {
      if (p.id === viewerId) return p;
      const masked = { ...p, angle: null, power: null };
      if (state.phase === 'select') {
        masked.tankClass = null;
        masked.classPicked = !!p.tankClass;
      }
      return masked;
    }),
  };
}

/** 결과 화면용 요약. */
export function battleSummary(state) {
  return {
    winner: state.winner,
    reason: state.endReason,
    series: state.series,
    turnNumber: state.turnNumber,
    players: state.players.map((p) => ({
      id: p.id,
      tankClass: p.tankClass,
      hp: p.hp,
      maxHp: p.maxHp,
      stats: p.stats,
      accuracy: p.stats.shots > 0 ? Math.round((p.stats.hits / p.stats.shots) * 100) : 0,
    })),
  };
}
