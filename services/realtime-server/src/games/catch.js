// 그림 맞히기 2.0 게임 모듈. 이벤트 계약: docs/socket-events/catch.md
//
// 한 사람이 제시어를 그리고 다른 사람이 맞힌다. 라운드는 서버 타이머(60초)로 끝나고,
// 30초·15초에 글자 하나씩 자동으로 열린다. 그림은 획(stroke) 단위로 서버가 기록해 두었다가
// 재접속(sync/restore) 때 다시 보내 준다. 라운드가 끝나면 6초 동안 정답을 보여 주고 다음 라운드가 자동 시작.
//
// 저장소: 상태(비밀 제시어 포함) game:<room>:catch · 그림 game:<room>:catch:art · 본 단어 catch:<room>:seen(90일, 600개).
import {
  CATCH_ROUND_MS,
  DRAWER_POINTS,
  MIN_HINT_LENGTH,
  guessPoints,
  hintOrder,
  hintTiles,
  judgeGuess,
  maxHintReveals,
  nextAutoHintRemaining,
  pickWord,
  rememberSeen,
  winnerOf,
} from "../catch-engine.js";

export const CATCH_GAME_TYPE = "catch";
/** 라운드가 끝난 뒤 정답·그림을 보여 주는 시간. 이 동안은 시간을 세지 않는다. */
export const CATCH_REVEAL_MS = 6_000;
/** 재대결 직후 첫 라운드 전 여유. */
export const CATCH_RESTART_INTRO_MS = 1_500;
/** 한 사람의 추측 사이 최소 간격. */
export const CATCH_GUESS_GAP_MS = 700;
/** 자기 차례에 그림을 한 획도 안 그린 라운드가 이만큼 이어지면 자리 비움으로 본다. */
export const CATCH_LAZY_FORFEIT = 2;
export const CATCH_ROUND_CHOICES = [4, 6, 8];
export const CATCH_PALETTE_SIZE = 12;
export const CATCH_TOOLS = ["pen", "marker", "eraser"];
// 그림 기록 상한(라운드당).
export const CATCH_MAX_STROKES = 400;
export const CATCH_MAX_ROUND_POINTS = 12_000;
export const CATCH_MAX_STROKE_POINTS = 4_000;
export const CATCH_MAX_BATCH_POINTS = 80;
// 묶음 전송 속도 제한(소켓당 1초): 33ms 묶음이면 초당 30개 안팎.
export const CATCH_MAX_BATCHES_PER_SEC = 60;
export const CATCH_MAX_POINTS_PER_SEC = 1_500;

const STATE_TTL_SEC = 3 * 3600;
const SEEN_TTL_SEC = 90 * 24 * 3600;
const MAX_GUESSES_KEPT = 12;
const MAX_GUESS_LENGTH = 20;

const stateKey = (roomCode) => `game:${roomCode}:catch`;
const artKey = (roomCode) => `game:${roomCode}:catch:art`;
const seenKey = (roomCode) => `catch:${roomCode}:seen`;
const lastKey = (roomCode) => `catch:${roomCode}:last`;

// 방별 타이머(콜백은 예약할 때의 timerApi를 쓴다), 그림 기록(메모리), 추측 간격.
const timers = new Map();
const arts = new Map();
const guessAt = new Map();
let random = Math.random;

/** 테스트용: 제시어·첫 그리는 사람·힌트 순서의 무작위를 바꾼다. */
export function setCatchRandom(fn) {
  random = typeof fn === "function" ? fn : Math.random;
}

function clearTimer(kit, roomCode) {
  const handle = timers.get(roomCode);
  if (!handle) return;
  timers.delete(roomCode);
  (handle.api ?? kit?.timerApi)?.clearTimeout(handle.timer);
}

async function readJson(kit, key) {
  const raw = await kit.redis.get(key);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

const loadState = (kit, roomCode) => readJson(kit, stateKey(roomCode));
const saveState = (kit, roomCode, state) =>
  kit.redis.set(stateKey(roomCode), JSON.stringify(state), "EX", STATE_TTL_SEC);

async function loadSeen(kit, roomCode) {
  const list = await readJson(kit, seenKey(roomCode));
  return Array.isArray(list) ? list.filter((w) => typeof w === "string") : [];
}

// ── 그림 기록 ────────────────────────────────────────────────────────────────

function newArt(gameId) {
  return { gameId, round: 0, drawer: null, open: false, strokes: [], points: 0, seqs: new Map(), past: [] };
}

function artSnapshot(art) {
  return JSON.stringify({
    gameId: art.gameId,
    round: art.round,
    strokes: art.strokes,
    past: art.past,
  });
}

async function saveArt(kit, roomCode, art) {
  // 동기로 직렬화해 두므로 늦게 끝난 저장이 더 새로운 기록을 덮지 않는다.
  await kit.redis.set(artKey(roomCode), artSnapshot(art), "EX", STATE_TTL_SEC);
}

/** 메모리에 없으면(서버 재시작) Redis의 상태·그림으로 되살린다. */
async function ensureArt(kit, roomCode, state = null) {
  const existing = arts.get(roomCode);
  const current = state ?? (await loadState(kit, roomCode));
  if (!current) return null;
  if (existing && existing.gameId === current.gameId) {
    syncArtFlags(existing, current);
    return existing;
  }
  const art = newArt(current.gameId);
  const saved = await readJson(kit, artKey(roomCode));
  if (saved && saved.gameId === current.gameId) {
    art.strokes = Array.isArray(saved.strokes) && saved.round === current.round ? saved.strokes : [];
    art.past = Array.isArray(saved.past) ? saved.past : [];
    art.points = art.strokes.reduce((n, s) => n + s.pts.length, 0);
    art.round = saved.round;
  }
  syncArtFlags(art, current);
  arts.set(roomCode, art);
  return art;
}

function syncArtFlags(art, state) {
  art.round = state.round;
  art.drawer = state.drawer;
  art.open = state.status === "playing" && state.phase === "drawing";
}

const clamp01 = (v) => Math.min(1, Math.max(0, v));
const round4 = (v) => Math.round(v * 10_000) / 10_000;

/** 클라이언트가 보낸 획 묶음을 검사·정리한다. 잘못되면 null. */
export function normalizeStrokeBatch(payload) {
  if (!payload || typeof payload !== "object") return null;
  const { id, seq, tool, color, w, pts, end } = payload;
  if (typeof id !== "string" || !/^[A-Za-z0-9_-]{1,24}$/.test(id)) return null;
  if (!Number.isInteger(seq) || seq < 0 || seq > 10_000) return null;
  if (!CATCH_TOOLS.includes(tool)) return null;
  const paletteIndex = tool === "eraser" ? 0 : color;
  if (!Number.isInteger(paletteIndex) || paletteIndex < 0 || paletteIndex >= CATCH_PALETTE_SIZE) return null;
  if (typeof w !== "number" || !Number.isFinite(w) || w < 0.002 || w > 0.12) return null;
  if (!Array.isArray(pts) || pts.length < 1 || pts.length > CATCH_MAX_BATCH_POINTS) return null;
  const clean = [];
  for (const p of pts) {
    if (!Array.isArray(p) || p.length < 2) return null;
    const [x, y] = p;
    if (typeof x !== "number" || typeof y !== "number" || !Number.isFinite(x) || !Number.isFinite(y)) return null;
    clean.push([round4(clamp01(x)), round4(clamp01(y))]);
  }
  return { id, seq, tool, color: paletteIndex, w: round4(w), pts: clean, end: end === true };
}

function withinRate(socket) {
  const now = Date.now();
  const bucket = socket.data.catchBucket ?? { t: now, batches: 0, points: 0 };
  if (now - bucket.t >= 1000) {
    bucket.t = now;
    bucket.batches = 0;
    bucket.points = 0;
  }
  socket.data.catchBucket = bucket;
  return bucket;
}

// ── 화면에 보내는 상태 ───────────────────────────────────────────────────────

/** viewer별 상태. 제시어는 그리는 사람과 정답 공개 뒤에만 들어간다. */
export function publicCatchState(state, viewer = null, extras = {}) {
  const reveal = state.phase !== "drawing" || state.status === "finished";
  const view = {
    gameId: state.gameId,
    gameType: CATCH_GAME_TYPE,
    status: state.status,
    phase: state.phase,
    players: state.players,
    round: state.round,
    maxRounds: state.maxRounds,
    drawer: state.drawer,
    category: state.wordCat,
    wordLen: state.wordLen,
    difficulty: state.difficulty,
    hint: hintTiles(state.word, state.revealed),
    canHint:
      state.status === "playing" &&
      state.phase === "drawing" &&
      !state.directHint &&
      state.wordLen >= MIN_HINT_LENGTH &&
      state.revealed.length < maxHintReveals(state.wordLen),
    directHint: Boolean(state.directHint),
    roundStartsAt: state.roundStartsAt,
    turnDeadline: state.phase === "drawing" ? state.turnDeadline : null,
    roundMs: CATCH_ROUND_MS,
    revealUntil: state.phase === "reveal" ? state.revealUntil : null,
    revealMs: CATCH_REVEAL_MS,
    scores: state.scores,
    guesses: state.guesses,
    history: state.history,
    result: state.result ?? null,
    series: state.series ?? null,
    serverNow: Date.now(),
  };
  if (reveal || viewer === state.drawer) view.word = state.word;
  if (state.status === "finished" && extras.gallery) view.gallery = extras.gallery;
  return view;
}

async function emitState(kit, roomCode, state) {
  const gallery = state.status === "finished" ? galleryOf(await ensureArt(kit, roomCode, state)) : null;
  const sockets = await kit.io.in(roomCode).fetchSockets();
  for (const sock of sockets) {
    const userId = sock.data.userId;
    if (userId && state.players.includes(userId)) {
      sock.emit("game:catch:state", publicCatchState(state, userId, { gallery }));
    }
  }
}

function galleryOf(art) {
  return (art?.past ?? []).map((p) => ({ ...p }));
}

/** 한 소켓에 현재 상태와(진행 중이면) 지금까지의 그림을 보낸다. */
async function sendSnapshot(kit, socket, roomCode, state) {
  const userId = socket.data.userId;
  const art = await ensureArt(kit, roomCode, state);
  const gallery = state.status === "finished" ? galleryOf(art) : null;
  const view = publicCatchState(state, userId, { gallery });
  socket.emit("game:catch:state", view);
  if (state.status === "playing") {
    socket.emit("game:catch:replay", { round: state.round, strokes: art?.strokes ?? [] });
  }
  return view;
}

// ── 타이머 ───────────────────────────────────────────────────────────────────

function nextDueAt(state) {
  if (state.status !== "playing") return null;
  if (state.phase === "reveal") return state.revealUntil;
  const remaining = nextAutoHintRemaining(state.wordLen, state.autoDone);
  return remaining == null ? state.turnDeadline : Math.min(state.turnDeadline, state.turnDeadline - remaining);
}

function schedule(kit, roomCode, state) {
  clearTimer(kit, roomCode);
  const due = nextDueAt(state);
  if (due == null) return;
  const { gameId, round, phase } = state;
  const api = kit.timerApi;
  const timer = api.setTimeout(() => {
    if (timers.get(roomCode)?.timer === timer) timers.delete(roomCode);
    void kit
      .withRoomLock(roomCode, () => onDue(kit, roomCode, gameId, round, phase))
      .catch((err) => console.error(`[catch] timer failed: ${err.message}`));
  }, Math.max(0, due - Date.now()));
  timer?.unref?.();
  timers.set(roomCode, { timer, api });
}

async function onDue(kit, roomCode, gameId, round, phase) {
  const state = await loadState(kit, roomCode);
  if (!state || state.status !== "playing" || state.gameId !== gameId || state.round !== round || state.phase !== phase) return;
  const now = Date.now();
  if (state.phase === "reveal") {
    if (now < state.revealUntil) return schedule(kit, roomCode, state);
    return advanceAfterReveal(kit, roomCode, state);
  }
  if (now >= state.turnDeadline) return endRound(kit, roomCode, state, { outcome: "timeout" });
  let changed = false;
  for (;;) {
    const remaining = nextAutoHintRemaining(state.wordLen, state.autoDone);
    if (remaining == null || now < state.turnDeadline - remaining) break;
    state.autoDone += 1;
    revealNextLetter(state);
    changed = true;
  }
  if (changed) {
    await saveState(kit, roomCode, state);
    await emitState(kit, roomCode, state);
  }
  schedule(kit, roomCode, state);
}

function revealNextLetter(state) {
  if (state.revealed.length >= maxHintReveals(state.wordLen)) return false;
  state.revealed.push(state.hintOrder[state.revealed.length]);
  return true;
}

// ── 라운드 흐름 ──────────────────────────────────────────────────────────────

/** 다음 라운드를 연다(제시어 뽑기·본 단어 기록·그림 비우기). state를 바꾼다. */
async function openRound(kit, roomCode, state, { startsAt }) {
  const seen = await loadSeen(kit, roomCode);
  state.round += 1;
  const entry = pickWord({ seen, used: state.usedWords, round: state.round, maxRounds: state.maxRounds, random });
  state.usedWords.push(entry.w);
  await kit.redis.set(seenKey(roomCode), JSON.stringify(rememberSeen(seen, [entry.w])), "EX", SEEN_TTL_SEC);
  const firstIdx = Math.max(0, state.players.indexOf(state.firstDrawer));
  state.drawer = state.players[(firstIdx + state.round - 1) % 2];
  state.phase = "drawing";
  state.word = entry.w;
  state.aliases = entry.aliases;
  state.wordCat = entry.cat;
  state.wordLen = [...entry.w].length;
  state.difficulty = entry.diff;
  state.hintOrder = hintOrder(state.wordLen, random);
  state.revealed = [];
  state.autoDone = 0;
  state.directHint = false;
  state.guesses = [];
  state.roundStartsAt = startsAt;
  state.turnDeadline = startsAt + CATCH_ROUND_MS;
  state.revealUntil = null;

  const art = arts.get(roomCode) ?? newArt(state.gameId);
  art.gameId = state.gameId;
  art.round = state.round;
  art.drawer = state.drawer;
  art.open = true;
  art.strokes = [];
  art.points = 0;
  art.seqs = new Map();
  arts.set(roomCode, art);
  await saveArt(kit, roomCode, art);
}

function newGame({ players, gameId, firstDrawer, maxRounds, series }) {
  return {
    gameId,
    players,
    firstDrawer,
    status: "playing",
    phase: "drawing",
    round: 0,
    maxRounds,
    scores: Object.fromEntries(players.map((p) => [p, 0])),
    history: [],
    usedWords: [],
    lazy: Object.fromEntries(players.map((p) => [p, 0])),
    drawer: null,
    word: "",
    aliases: [],
    wordCat: "",
    wordLen: 0,
    difficulty: 1,
    hintOrder: [],
    revealed: [],
    autoDone: 0,
    directHint: false,
    guesses: [],
    roundStartsAt: null,
    turnDeadline: null,
    revealUntil: null,
    result: null,
    series,
    createdAt: Date.now(),
  };
}

async function beginGame(kit, roomCode, { players, gameId, firstDrawer, maxRounds, startsAt }) {
  clearTimer(kit, roomCode);
  guessAt.delete(roomCode);
  arts.delete(roomCode);
  const series = await kit.series.get(roomCode, CATCH_GAME_TYPE, players);
  const state = newGame({ players, gameId, firstDrawer, maxRounds, series });
  await openRound(kit, roomCode, state, { startsAt });
  await saveState(kit, roomCode, state);
  await emitState(kit, roomCode, state);
  schedule(kit, roomCode, state);
  return state;
}

async function advanceAfterReveal(kit, roomCode, state) {
  if (state.round >= state.maxRounds) {
    return finishGame(kit, roomCode, state, { winner: winnerOf(state.scores, state.players), reason: "score" });
  }
  await openRound(kit, roomCode, state, { startsAt: Date.now() });
  await saveState(kit, roomCode, state);
  await emitState(kit, roomCode, state);
  schedule(kit, roomCode, state);
}

async function finishGame(kit, roomCode, state, { winner, reason, loser = null }) {
  clearTimer(kit, roomCode);
  guessAt.delete(roomCode);
  const art = arts.get(roomCode);
  if (art) art.open = false;
  state.status = "finished";
  state.phase = "over";
  state.turnDeadline = null;
  state.revealUntil = null;
  const realWinner = winner && winner !== "draw" ? winner : null;
  state.result = {
    winner: realWinner,
    loser: loser ?? (realWinner ? state.players.find((p) => p !== realWinner) : null),
    draw: !realWinner,
    reason,
    scores: { ...state.scores },
  };
  state.series = await kit.series.record(roomCode, CATCH_GAME_TYPE, state.players, realWinner);
  await saveState(kit, roomCode, state);
  await kit.redis.set(
    lastKey(roomCode),
    JSON.stringify({
      players: state.players,
      gameId: state.gameId,
      maxRounds: state.maxRounds,
      firstDrawer: state.firstDrawer,
      finishedAt: Date.now(),
    }),
    "EX",
    STATE_TTL_SEC,
  );
  try {
    await kit.recordGameOutcome(roomCode, {
      winner: realWinner ?? "draw",
      players: state.players,
      gameType: CATCH_GAME_TYPE,
      gameId: state.gameId,
    });
  } catch (err) {
    console.error(`[catch] outcome record failed: ${err.message}`);
  }
  await emitState(kit, roomCode, state);
}

/** 정답 또는 시간 초과로 라운드를 끝낸다(방 잠금 안에서 부른다). */
async function endRound(kit, roomCode, state, { outcome, guesser = null }) {
  clearTimer(kit, roomCode);
  const now = Date.now();
  const art = await ensureArt(kit, roomCode, state);
  art.open = false;
  const drewSomething = art.strokes.length > 0;
  const points = Object.fromEntries(state.players.map((p) => [p, 0]));
  let timeLeftMs = 0;
  if (outcome === "correct") {
    timeLeftMs = Math.max(0, Math.min(CATCH_ROUND_MS, state.turnDeadline - now));
    points[guesser] = guessPoints({ remainingMs: timeLeftMs, directHints: state.directHint ? 1 : 0 });
    points[state.drawer] = DRAWER_POINTS;
    for (const p of state.players) state.scores[p] = (state.scores[p] ?? 0) + points[p];
  }
  state.lazy[state.drawer] = drewSomething || outcome === "correct" ? 0 : (state.lazy[state.drawer] ?? 0) + 1;
  const record = {
    round: state.round,
    drawer: state.drawer,
    word: state.word,
    category: state.wordCat,
    outcome,
    guesser,
    points,
    timeLeftMs,
    usedHint: Boolean(state.directHint),
    scores: { ...state.scores },
  };
  state.history = [...state.history, record];
  art.past = [
    ...art.past,
    { round: state.round, drawer: state.drawer, word: state.word, category: state.wordCat, outcome, guesser, strokes: art.strokes },
  ];
  state.phase = "reveal";
  state.turnDeadline = null;
  state.revealUntil = now + CATCH_REVEAL_MS;
  await saveArt(kit, roomCode, art);

  const lazyPlayers = state.players.filter((p) => (state.lazy[p] ?? 0) >= CATCH_LAZY_FORFEIT);
  kit.io.to(roomCode).emit("game:catch:round_result", {
    gameId: state.gameId,
    ...record,
    maxRounds: state.maxRounds,
    last: state.round >= state.maxRounds,
    revealUntil: state.revealUntil,
    serverNow: now,
  });
  if (lazyPlayers.length === 2) {
    return finishGame(kit, roomCode, state, { winner: "draw", reason: "both_away" });
  }
  if (lazyPlayers.length === 1) {
    const loser = lazyPlayers[0];
    return finishGame(kit, roomCode, state, { winner: state.players.find((p) => p !== loser), loser, reason: "forfeit" });
  }
  await saveState(kit, roomCode, state);
  await emitState(kit, roomCode, state);
  schedule(kit, roomCode, state);
}

async function forfeitGame(kit, roomCode, state, loser, winner) {
  await finishGame(kit, roomCode, state, { winner, loser, reason: "forfeit" });
}

function cleanGuess(text) {
  return String(text ?? "").normalize("NFC").trim().slice(0, MAX_GUESS_LENGTH);
}

function roundsFromOptions(options) {
  const n = options?.rounds;
  return CATCH_ROUND_CHOICES.includes(n) ? n : 6;
}

const catchModule = {
  gameType: CATCH_GAME_TYPE,
  lobbyType: CATCH_GAME_TYPE,

  register(socket, kit) {
    socket.on("game:catch:sync", async (_payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const state = await loadState(kit, roomCode);
      if (!state || !state.players.includes(userId)) return ack({ ok: true, state: null });
      const view = await sendSnapshot(kit, socket, roomCode, state);
      return ack({ ok: true, state: view });
    });

    socket.on("game:catch:stroke", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const art = arts.get(roomCode) ?? (await ensureArt(kit, roomCode));
      if (!art) return ack({ ok: false, reason: "no_game" });
      if (art.drawer !== userId) return ack({ ok: false, reason: "not_drawer" });
      if (!art.open) return ack({ ok: false, reason: "round_over" });
      if (payload?.round !== art.round) return ack({ ok: false, reason: "stale_round", round: art.round });
      const batch = normalizeStrokeBatch(payload);
      if (!batch) return ack({ ok: false, reason: "invalid_payload" });
      const bucket = withinRate(socket);
      bucket.batches += 1;
      bucket.points += batch.pts.length;
      if (bucket.batches > CATCH_MAX_BATCHES_PER_SEC || bucket.points > CATCH_MAX_POINTS_PER_SEC) {
        return ack({ ok: false, reason: "rate_limited" });
      }
      let stroke = art.strokes.findLast((s) => s.id === batch.id);
      if (!stroke) {
        // 시작 묶음이 아닌데 모르는 획이면 취소·지우기 뒤에 늦게 온 묶음이다.
        if (batch.seq !== 0) return ack({ ok: false, reason: "unknown_stroke" });
        if (art.strokes.length >= CATCH_MAX_STROKES) return ack({ ok: false, reason: "stroke_limit" });
        stroke = { id: batch.id, tool: batch.tool, color: batch.color, w: batch.w, pts: [] };
      } else if (batch.seq <= (art.seqs.get(batch.id) ?? -1)) {
        return ack({ ok: true, duplicate: true });
      }
      if (
        stroke.pts.length + batch.pts.length > CATCH_MAX_STROKE_POINTS ||
        art.points + batch.pts.length > CATCH_MAX_ROUND_POINTS
      ) {
        return ack({ ok: false, reason: "stroke_limit" });
      }
      if (stroke.pts.length === 0) art.strokes.push(stroke);
      stroke.pts.push(...batch.pts);
      art.points += batch.pts.length;
      art.seqs.set(batch.id, batch.seq);
      socket.to(roomCode).emit("game:catch:stroke", {
        round: art.round,
        id: batch.id,
        seq: batch.seq,
        tool: stroke.tool,
        color: stroke.color,
        w: stroke.w,
        pts: batch.pts,
        end: batch.end,
      });
      if (batch.end) await saveArt(kit, roomCode, art);
      return ack({ ok: true });
    });

    socket.on("game:catch:undo", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const art = arts.get(roomCode) ?? (await ensureArt(kit, roomCode));
      if (!art) return ack({ ok: false, reason: "no_game" });
      if (art.drawer !== userId) return ack({ ok: false, reason: "not_drawer" });
      if (!art.open) return ack({ ok: false, reason: "round_over" });
      if (payload?.round !== art.round) return ack({ ok: false, reason: "stale_round", round: art.round });
      const id = typeof payload?.id === "string" ? payload.id : art.strokes.at(-1)?.id;
      const index = art.strokes.findLastIndex((s) => s.id === id);
      if (index < 0) return ack({ ok: false, reason: "no_stroke" });
      const [removed] = art.strokes.splice(index, 1);
      art.points -= removed.pts.length;
      art.seqs.delete(id);
      socket.to(roomCode).emit("game:catch:undo", { round: art.round, id });
      await saveArt(kit, roomCode, art);
      return ack({ ok: true, id });
    });

    socket.on("game:catch:clear", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const art = arts.get(roomCode) ?? (await ensureArt(kit, roomCode));
      if (!art) return ack({ ok: false, reason: "no_game" });
      if (art.drawer !== userId) return ack({ ok: false, reason: "not_drawer" });
      if (!art.open) return ack({ ok: false, reason: "round_over" });
      if (payload?.round !== art.round) return ack({ ok: false, reason: "stale_round", round: art.round });
      art.strokes = [];
      art.points = 0;
      art.seqs = new Map();
      socket.to(roomCode).emit("game:catch:clear", { round: art.round });
      await saveArt(kit, roomCode, art);
      return ack({ ok: true });
    });

    socket.on("game:catch:guess", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const text = cleanGuess(payload?.text);
      if (!text || !Number.isInteger(payload?.round)) return ack({ ok: false, reason: "invalid_payload" });
      await kit.withRoomLock(roomCode, async () => {
        const state = await loadState(kit, roomCode);
        if (!state) return ack({ ok: false, reason: "no_game" });
        if (!state.players.includes(userId)) return ack({ ok: false, reason: "not_a_player" });
        if (state.status !== "playing") return ack({ ok: false, reason: "game_over" });
        if (state.phase !== "drawing") return ack({ ok: false, reason: "round_over" });
        if (payload.round !== state.round) return ack({ ok: false, reason: "stale_round", round: state.round });
        if (userId === state.drawer) return ack({ ok: false, reason: "drawer_cannot_guess" });
        const key = `${roomCode}:${userId}`;
        const now = Date.now();
        if (now - (guessAt.get(key) ?? -Infinity) < CATCH_GUESS_GAP_MS) return ack({ ok: false, reason: "too_fast" });
        guessAt.set(key, now);

        const verdict = judgeGuess(text, { w: state.word, aliases: state.aliases });
        const bubble = {
          id: `${state.round}-${state.guesses.length + 1}-${now}`,
          round: state.round,
          userId,
          text,
          verdict,
        };
        state.guesses = [...state.guesses, bubble].slice(-MAX_GUESSES_KEPT);
        kit.io.to(roomCode).emit("game:catch:guess", bubble);
        if (verdict === "correct") {
          await endRound(kit, roomCode, state, { outcome: "correct", guesser: userId });
        } else {
          await saveState(kit, roomCode, state);
        }
        return ack({ ok: true, verdict });
      });
    });

    socket.on("game:catch:hint", async (payload, ackRaw) => {
      const ack = kit.normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      await kit.withRoomLock(roomCode, async () => {
        const state = await loadState(kit, roomCode);
        if (!state) return ack({ ok: false, reason: "no_game" });
        if (!state.players.includes(userId)) return ack({ ok: false, reason: "not_a_player" });
        if (state.status !== "playing" || state.phase !== "drawing") return ack({ ok: false, reason: "round_over" });
        if (payload?.round !== undefined && payload.round !== state.round) {
          return ack({ ok: false, reason: "stale_round", round: state.round });
        }
        if (userId === state.drawer) return ack({ ok: false, reason: "drawer_cannot_hint" });
        if (state.directHint) return ack({ ok: false, reason: "hint_used" });
        if (state.wordLen < MIN_HINT_LENGTH || state.revealed.length >= maxHintReveals(state.wordLen)) {
          return ack({ ok: false, reason: "no_more_hints" });
        }
        revealNextLetter(state);
        state.directHint = true;
        await saveState(kit, roomCode, state);
        await emitState(kit, roomCode, state);
        return ack({ ok: true, penalty: 1 });
      });
    });
  },

  async startFromLobby(roomCode, kit, ctx) {
    await kit.withRoomLock(roomCode, async () => {
      const players = ctx.players.slice(0, 2);
      await beginGame(kit, roomCode, {
        players,
        gameId: ctx.gameId ?? kit.randomUUID(),
        firstDrawer: players[Math.min(1, Math.floor(random() * 2))],
        maxRounds: roundsFromOptions(ctx.options),
        startsAt: ctx.startsAt ?? Date.now(),
      });
    });
  },

  async restart(roomCode, kit, ctx) {
    const previous = (await loadState(kit, roomCode)) ?? (await readJson(kit, lastKey(roomCode)));
    const players = [ctx.p1, ctx.p2];
    const firstDrawer =
      previous?.firstDrawer && players.includes(previous.firstDrawer)
        ? players.find((p) => p !== previous.firstDrawer)
        : players[Math.min(1, Math.floor(random() * 2))];
    await beginGame(kit, roomCode, {
      players,
      gameId: kit.randomUUID(),
      firstDrawer,
      maxRounds: CATCH_ROUND_CHOICES.includes(previous?.maxRounds) ? previous.maxRounds : 6,
      startsAt: Date.now() + CATCH_RESTART_INTRO_MS,
    });
  },

  async restore(roomCode, socket, kit) {
    const userId = socket.data.userId;
    const state = await loadState(kit, roomCode);
    if (!state || !state.players.includes(userId)) return false;
    await sendSnapshot(kit, socket, roomCode, state);
    if (state.status !== "playing") return false;
    // 서버가 재시작돼 타이머가 사라졌으면 다시 건다.
    if (!timers.has(roomCode)) schedule(kit, roomCode, state);
    return true;
  },

  afk(kit) {
    return {
      key: stateKey,
      playersOf: (s) => s.players ?? [],
      // 서버 타이머가 라운드를 끝내므로 보통 먼저 동작한다. 타이머가 사라진 판의 안전망으로 그리는 사람을 기다린다.
      waitingOn: (s) => (s.status === "playing" && s.phase === "drawing" ? s.drawer : null),
      forfeit: async (roomCode, s, loser, winner) => {
        if (s.status !== "playing") return;
        await forfeitGame(kit, roomCode, s, loser, winner);
      },
    };
  },

  dispose() {
    for (const [roomCode, handle] of [...timers]) {
      timers.delete(roomCode);
      handle.api?.clearTimeout(handle.timer);
    }
    arts.clear();
    guessAt.clear();
  },
};

export default catchModule;
