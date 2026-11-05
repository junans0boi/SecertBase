import { z } from "zod";
import { randomUUID } from "node:crypto";
import { MARBLE_CHARACTER_IDS } from "./marble-characters.js";
import { config } from "./config.js";
import { installSocketAuthentication, installSocketFeatureGate } from "./backend-access.js";
import { resolveActiveCouple } from "./shared/access-context.js";
import {
  registerGameSessionHandlers,
  resolveLobbyJoinForResume,
  cleanupGameSessionOnDisconnect,
} from "./game-session.js";
import { query } from "./db.js";
import { redis } from "./redis.js";
import { notifier } from "./modules/notifications/index.js";
import { transferGameReward, getBalance, getEquippedStats, getEquippedItemsInfo } from "./wallet-engine.js";
import { isValidLobbyOption, normalizeLobbyOptions } from "./lobby-options.js";
import { grantXp, updateMissionProgress } from "./level-engine.js";
import {
  throwYut,
  createYutGameState,
  checkWin,
  resolveYutMove,
  hasBackdoMove,
  getNextPlayer as getNextYutPlayer,
  settleTurnAfterMove,
  recordYutThrow,
  resetYutTurnThrows,
  serializeYutGame,
  pruneUnusableBackdo,
} from "./yut-engine.js";
import {
  createMarbleGameState,
  rollDice as rollMarbleDice,
  movePiece as moveMarblePiece,
  settleTurnAfterMove as settleMarbleTurn,
  serializeMarbleGame,
  checkMarbleWin,
  calcToll,
  calcUpgradeCost,
  calcAcquireCost,
  calcPurchaseCost,
  hasColorMonopoly,
  getLandValue,
  getMarbleSpecialType,
  getNextPlayer as getNextMarblePlayer,
  advanceMarbleRound,
  pickGateDestination,
  sumEquippedStat,
  MARBLE_SALARY,
  MARBLE_MAX_ROUNDS,
  MARBLE_START_POSITIONS,
  SPECIAL_FEE,
  calcScore,
} from "./marble-engine.js";
import {
  createBombGameState,
  checkAnswer,
  isTimeUp,
  passBomb,
} from "./bomb-engine.js";

import {
  initGame as initBlackjackGame,
  hit as hitBlackjack,
  stand as standBlackjack,
  nextRound as nextBlackjackRound,
  serializeFor as serializeBlackjackFor,
} from "./blackjack-engine.js";

import {
  startGame as startOldMaidGame,
  drawCard as drawOldMaidCard,
} from "./oldmaid-engine.js";
import { TELEPATHY_RESPONSE_TIMEOUT_MS, TELEPATHY_SESSION_TTL_SEC, telepathyResult } from "./telepathy-engine.js";
import { resolveHanabagiRound } from "./rps-engine.js";

import {
  initBowlingGame,
  rollFrame as rollBowlingFrame,
  buildFrameDisplayData,
  nextRollContext,
} from "./bowling-engine.js";
import { simulateRoll as simulateBowlingRoll, standingDeck, jitterThrow } from "./bowling-sim.js";
import {
  initPenaltyGame,
  resolvePenaltyRound,
} from "./penalty-engine.js";

import {
  createFortressState,
  moveTank,
  aimTank,
  selectWeapon,
  fireTank,
  selectTankClass,
  timeoutTurn as timeoutTankTurn,
  viewFor as tankViewFor,
  battleSummary as tankBattleSummary,
  TANK_CLASS_IDS,
  WEAPON_IDS as TANK_WEAPON_IDS,
  TURN_TIME_MS as TANK_TURN_TIME_MS,
} from "./fortress-engine.js";

import {
  createGostopGameState,
  playHandCard,
  selectDeckCapture,
  declareShake,
  playBomb,
  declareGoStop,
  resolveGostopTerminalState,
  serializeFor as serializeGostopFor,
  forfeitGostop,
} from "./gostop-engine.js";
import { createAfkWatcher, afkGameTypeForEvent } from "./game-afk.js";
import { GAME_MODULES } from "./games/index.js";
import { createSeriesStore } from "./games/series.js";
import { REACTION_EMOJIS, createReactionLimiter } from "./games/reaction.js";

// ── 방(room) 단위 직렬 뮤텍스 ─────────────────────────────────────────────────
// Node.js는 단일 스레드지만 await 사이에 이벤트 루프가 다른 요청을 처리할 수 있어
// 동일 방의 두 요청이 Redis에서 같은 gameState를 읽고 마지막 쓰기가 앞 쓰기를 덮어쓰는
// 레이스컨디션이 발생한다. 방 코드별 Promise 체인으로 이를 직렬화한다.
const roomLocks = new Map();
async function withRoomLock(roomCode, fn) {
  const prev = roomLocks.get(roomCode) ?? Promise.resolve();
  let release;
  const lock = new Promise((r) => { release = r; });
  roomLocks.set(roomCode, lock);
  try {
    await prev;
    return await fn();
  } finally {
    release();
    if (roomLocks.get(roomCode) === lock) roomLocks.delete(roomCode);
  }
}

// 그림 맞히기 라운드 길이(클라이언트 타이머와 같음).
const CATCH_ROUND_MS = 60_000;
const catchDrawSchema = z.object({
  x: z.number().min(-0.1).max(1.1),
  y: z.number().min(-0.1).max(1.1),
  s: z.boolean().optional().default(false),
  c: z.number().int().min(0).max(7).optional().default(0),
  sz: z.number().int().min(0).max(2).optional().default(1),
});

// 진행 중인 그림 맞히기 판을 한 소켓에 다시 보여준다(복원·이어하기 공용).
async function emitCatchStateTo(targetSocket, roomCode, state) {
  const io = targetSocket.nsp?.server ?? null;
  const nicknames = io ? getPresenceNicknames(io, roomCode) : {};
  targetSocket.emit("game:catch:started", {
    drawer: state.drawer,
    round: state.round,
    maxRounds: state.maxRounds,
    scores: state.scores,
    wordLen: [...state.word].length,
    nicknames,
    resumed: true,
    remainingMs: Math.max(0, (state.roundEndsAt ?? 0) - Date.now()),
  });
  if (targetSocket.data.userId === state.drawer) targetSocket.emit("game:catch:word", { word: state.word });
  if (state.phase === "timeout") targetSocket.emit("game:catch:timeout_result", { word: state.word });
  if (state.phase === "guessed") targetSocket.emit("game:catch:correct", { word: state.word, scores: state.scores });
}

// 판정 전 제출값은 "제출함(true)"으로만 공개한다.
function maskPenaltyState(gameState) {
  return {
    ...gameState,
    submissions: Object.fromEntries(
      Object.keys(gameState.submissions ?? {}).map((uid) => [uid, true]),
    ),
  };
}

function withBowlingFrames(gameState) {
  const frames = {};
  for (const [pid, rolls] of Object.entries(gameState.rolls || {})) {
    frames[pid] = buildFrameDisplayData(rolls);
  }
  return { ...gameState, frames };
}

// Old Maid cards are private information. The drawing player sees their own
// hand, while the other player receives only stable card ids so they can be
// selected without leaking rank/suit/Joker state.
function serializeOldMaidGame(gameState, viewerId) {
  const players = Object.fromEntries(
    Object.entries(gameState.players ?? {}).map(([playerId, player]) => [
      playerId,
      {
        ...player,
        // 상대 카드의 실제 id(card_0…, card_joker)는 랭크와 조커 위치를 드러낸다.
        // 위치 별칭만 보내고, 뽑기 요청의 별칭은 서버가 실제 카드로 바꾼다.
        hand: (player.hand ?? []).map((card, index) =>
          playerId === viewerId ? card : { id: `slot-${index}` },
        ),
      },
    ]),
  );
  const lastDrawnCard = gameState.lastDrawnCard
    ? {
        ...gameState.lastDrawnCard,
        card: gameState.lastDrawnCard.by === viewerId
          ? gameState.lastDrawnCard.card
          : { id: gameState.lastDrawnCard.card?.id },
      }
    : null;
  return { ...gameState, players, lastDrawnCard };
}

function emitOldMaidState(io, roomCode, gameState) {
  return io.in(roomCode).fetchSockets().then((sockets) => {
    for (const roomSocket of sockets) {
      roomSocket.emit(
        "game:oldmaid:updated",
        serializeOldMaidGame(gameState, roomSocket.data.userId),
      );
    }
  });
}

// Blackjack hands are private during a round. Send each socket a projection
// containing its own cards, and reveal both hands only after the round ends.
function emitBlackjackState(io, roomCode, gameState) {
  return io.in(roomCode).fetchSockets().then((sockets) => {
    for (const roomSocket of sockets) {
      roomSocket.emit(
        "game:blackjack:updated",
        serializeBlackjackFor(gameState, roomSocket.data.userId),
      );
    }
  });
}

const joinSchema = z.object({
  profileEmoji: z.string().min(1).max(16).optional(),
});

const profileSchema = z.object({
  profileEmoji: z.string().min(1).max(16),
});

const gameTypes = [
  "dice",
  "rps",
  "zero",
  "telepathy",
  "pirate",
  "yut",
  "marble",
  "uno",
  "uno_classic",
  "uno_go_wild",
  "catch",
  "blackjack",
  "oldmaid",
  "penalty",
  "bowling",
  "tank",
  "gostop",
];

const lobbySchema = z.object({
  gameType: z.enum(gameTypes),
  stake: z.number().int().min(0).max(10000).optional().default(0),
});

const lobbyStakeSchema = z.object({
  gameType: z.enum(gameTypes),
  stake: z.number().int().min(0).max(10000),
});
const GOSTOP_STAKES = new Set([0, 100, 500, 1000]);

const lobbyOptionSchema = z.object({
  gameType: z.enum(gameTypes),
  key: z.string().min(1).max(32),
  value: z.union([z.string().max(32), z.number().int()]),
});

const lobbyReadySchema = z.object({
  gameType: z.enum(gameTypes),
  ready: z.boolean(),
});

const yutCharacters = ["honggilldong", "nolbu", "miho"];
const marbleCharacterIds = MARBLE_CHARACTER_IDS;

const lobbyCharacterSchema = z.union([
  z.object({
    gameType: z.literal("yut"),
    character: z.enum(yutCharacters),
  }),
  z.object({
    gameType: z.literal("marble"),
    character: z.enum(marbleCharacterIds),
  }),
]);

const yutNewSchema = z
  .object({
    characters: z.record(z.string(), z.enum(yutCharacters)).optional().default({}),
    bgm: z.enum(["yut1.mp3", "yut2.mp3", "yut3.mp3"]).optional().nullable(),
    stake: z.number().int().min(0).max(10000).optional().default(0),
  })
  .optional()
  .default({ characters: {}, bgm: null, stake: 0 });

const rouletteSchema = z.object({
  options: z.array(z.string().min(1).max(100)).min(2).max(12),
});

const rpsSchema = z.object({
  choice: z.enum(["rock", "paper", "scissors"]),
});

const rpsStartSchema = z.object({
  mode: z.enum(["single", "rps3", "mukjippa", "hanabagi"]),
});

const rpsPickSchema = z.object({
  choice: z.enum(["rock", "paper", "scissors"]).optional(),
  fingers: z.number().int().min(0).max(5).optional(),
  guess: z.number().int().min(0).max(10).optional(),
});

const telepathySchema = z.object({
  choice: z.string().min(1).max(100),
  options: z.array(z.string().min(1).max(100)).min(2).max(10),
  sessionId: z.string().min(1).max(100).optional(),
});

const pirateStartSchema = z.object({
  slots: z.number().int().min(4).max(16),
});

const piratePickSchema = z.object({
  slot: z.number().int().min(0),
});

const yutMoveSchema = z.object({
  pieceId: z.number().int().min(0).max(3),
  moveIndex: z.number().int().min(0).max(20).optional().default(0),
  backdoDir: z.number().int().optional(),
});

const chatMessageSchema = z.object({
  message: z.string().trim().min(1).max(200),
});


const bombAnswerSchema = z.object({
  answer: z.string().trim().min(1).max(50),
});

const bombNewSchema = z.object({
  duration: z.number().int().min(10).max(120).optional().default(30),
});

// gameId가 있으면 같은 판이 두 번 기록되지 않는다(uq_game_results_game_id).
async function saveGameResult(roomCode, winnerCode, loserCode, gameType, stake, { gameId = null } = {}) {
  try {
    const { rows } = await query('SELECT CoupleId FROM Couples WHERE RoomCode = ? LIMIT 1', [roomCode]);
    if (!rows[0]) return;
    await query(
      `INSERT INTO game_results (couple_id, game_type, winner_user_code, loser_user_code, stake, player_a_code, player_b_code, game_id)
       VALUES (?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE id = id`,
      [rows[0].CoupleId, gameType, winnerCode, loserCode, stake ?? 0, winnerCode, loserCode, gameId],
    );
  } catch (err) {
    console.error('[game_results] insert error:', err.message);
  }
}

// 무승부: 승자/패자 없이 두 참가자를 기록한다.
async function saveDrawResult(roomCode, playerCodes, gameType, { gameId = null, stake = 0 } = {}) {
  try {
    const { rows } = await query('SELECT CoupleId FROM Couples WHERE RoomCode = ? LIMIT 1', [roomCode]);
    if (!rows[0]) return;
    const [a = null, b = null] = playerCodes;
    await query(
      `INSERT INTO game_results (couple_id, game_type, winner_user_code, loser_user_code, stake, is_draw, player_a_code, player_b_code, game_id)
       VALUES (?,?,NULL,NULL,?,1,?,?,?) ON DUPLICATE KEY UPDATE id = id`,
      [rows[0].CoupleId, gameType, stake ?? 0, a, b, gameId],
    );
  } catch (err) {
    console.error('[game_results] draw insert error:', err.message);
  }
}

// 무승부 참여 보상: 두 사람 모두 XP 30 + game_play 미션 진행.
async function grantDrawXpAndMissions(playerCodes, game) {
  try {
    const codes = playerCodes.filter(Boolean);
    if (codes.length === 0) return;
    const { rows } = await query(
      'SELECT UserId, UserCode FROM Users WHERE UserCode IN (?,?)',
      [codes[0], codes[1] ?? codes[0]],
    );
    for (const row of rows) {
      await grantXp(row.UserId, 30);
      await updateMissionProgress(row.UserId, 'game_play', game);
    }
  } catch (err) {
    console.error('[xp] grantDrawXpAndMissions error:', err.message);
  }
}

// 승패 또는 무승부를 한 번에 기록하고 보상한다. winner가 null/'draw'면 무승부.
async function recordGameOutcome(roomCode, { winner, players, gameType, missionKey = gameType, stake = 0, gameId = null }) {
  if (!winner || winner === "draw") {
    await Promise.all([
      saveDrawResult(roomCode, players, gameType, { gameId, stake: 0 }),
      grantDrawXpAndMissions(players, missionKey),
    ]);
    return;
  }
  const loser = players.find((p) => p !== winner);
  if (!loser) return;
  await Promise.all([
    saveGameResult(roomCode, winner, loser, gameType, stake, { gameId }),
    grantGameXpAndMissions(winner, loser, missionKey),
  ]);
}

// 게임 종료 후 XP + 미션 진행 부여 (fire-and-forget)
async function grantGameXpAndMissions(winnerCode, loserCode, game) {
  try {
    const { rows } = await query(
      'SELECT UserId, UserCode FROM Users WHERE UserCode IN (?,?)',
      [winnerCode, loserCode],
    );
    for (const row of rows) {
      const uid = row.UserId;
      const isWinner = row.UserCode === winnerCode;
      await grantXp(uid, isWinner ? 50 : 20);
      await updateMissionProgress(uid, 'game_play', game);
      if (isWinner) await updateMissionProgress(uid, 'game_win', game);
    }
  } catch (err) {
    console.error('[xp] grantGameXpAndMissions error:', err.message);
  }
}

// 게임 종료 후 지갑 정산 + wallet:updated 브로드캐스트
// winnerNumericId: numeric UserId (for stat lookup); winnerId/loserId: UserCode
async function _getWinStreak(roomCode, winnerCode) {
  try {
    const { rows: coupleRows } = await query('SELECT CoupleId FROM Couples WHERE RoomCode = ? LIMIT 1', [roomCode]);
    if (!coupleRows[0]) return 0;
    const { rows } = await query(
      'SELECT winner_user_code FROM game_results WHERE couple_id = ? ORDER BY id DESC LIMIT 10',
      [coupleRows[0].CoupleId]
    );
    let streak = 0;
    for (const row of rows) {
      if (row.winner_user_code === winnerCode) streak++;
      else break;
    }
    return streak;
  } catch { return 0; }
}

// preStreak: 이미 계산된 이전 연승 수 (saveGameResult와 race condition 방지를 위해 Promise.all 이전에 계산)
async function settleAndEmitWallet(io, roomCode, winnerId, loserId, stake, gameRef, winnerNumericId = null, catchBonus = 0, loserNumericId = null, preStreak = 0) {
  if (!stake || stake <= 0) return { ok: true, skipped: true };
  try {
    let winnerBonusPct = 0;
    let totalCatchBonus = catchBonus;
    let loserRefundPct = 0;

    const [winnerStats, loserStats] = await Promise.all([
      winnerNumericId ? getEquippedStats(winnerNumericId) : Promise.resolve({}),
      loserNumericId ? getEquippedStats(loserNumericId) : Promise.resolve({}),
    ]);

    winnerBonusPct = winnerStats.coin_bonus_pct ?? 0;
    loserRefundPct = loserStats.lose_refund_pct ?? 0;

    // win_streak_bonus: 이전 연승 >= 1이면 이번 게임도 합쳐 streak >= 2
    const winStreakBonus = Math.floor(winnerStats.win_streak_bonus ?? 0);
    if (winStreakBonus > 0 && preStreak >= 1) {
      totalCatchBonus += winStreakBonus;
    }

    const result = await transferGameReward(winnerId, loserId, stake, gameRef, { winnerBonusPct, catchBonus: totalCatchBonus, loserRefundPct });
    io.to(roomCode).emit("wallet:updated", {
      [winnerId]: result.winnerBalance,
      [loserId]: result.loserBalance,
    });
    return { ok: true, result };
  } catch (err) {
    console.error("[wallet] settle error:", err.message);
    return { ok: false, reason: err.message };
  }
}

// 모든 소켓 핸들러의 동기/비동기 예외를 포착한다. 핸들러 하나의 DB 오류가
// unhandledRejection으로 프로세스를 종료시키지 않고, 요청자는 실패 ack를 받는다.
// afterHandler(event, args): 핸들러가 끝난 뒤 호출(잠수 감시 갱신 등). 실패는 로그만 남긴다.
export function installHandlerSafetyNet(socket, logger = console, afterHandler = null) {
  const rawOn = socket.on.bind(socket);
  socket.on = (event, handler) => rawOn(event, (...args) => {
    const ack = typeof args.at(-1) === "function" ? args.at(-1) : null;
    const report = (err) => {
      logger.error(`[socket] ${event} handler failed: ${err?.stack ?? err}`);
      try { ack?.({ ok: false, reason: "internal_error" }); } catch { /* ack already closed */ }
    };
    const after = () => {
      if (!afterHandler) return;
      Promise.resolve()
        .then(() => afterHandler(event, args))
        .catch((err) => logger.error(`[socket] ${event} after-hook failed: ${err?.message ?? err}`));
    };
    try {
      const result = handler(...args);
      if (result && typeof result.then === "function") result.then(after, report);
      else after();
    } catch (err) {
      report(err);
    }
  });
  return socket;
}

// In-memory mutex for lobby write operations (single-server race prevention)
const _lobbyLocks = new Map();
const withLobbyLock = (key, fn) => {
  const prev = _lobbyLocks.get(key) ?? Promise.resolve();
  let resolve;
  const next = new Promise((r) => (resolve = r));
  _lobbyLocks.set(key, next);
  return prev.then(fn).finally(() => { resolve(); if (_lobbyLocks.get(key) === next) _lobbyLocks.delete(key); });
};

const roomKey = (roomCode) => `room:${roomCode}:state`;
const yutGameKey = (roomCode) => `yut:${roomCode}:game`;
const gostopGameKey = (roomCode) => `gostop:${roomCode}:game`;
const bombGameKey = (roomCode) => `bomb:${roomCode}:game`;
const gameLobbyKey = (roomCode, gameType) => `lobby:${roomCode}:${gameType}`;
const rpsGameKey = (roomCode) => `rps:${roomCode}:game`;
const pirateKey = (roomCode) => `pirate:${roomCode}:game`;
const marbleGameKey = (roomCode) => `marble:${roomCode}:game`;
const pendingGameKey = (roomCode, gameType) => `pending:${roomCode}:${gameType}`;
const restartKey = (roomCode) => `restart:${roomCode}`;
// 판돈을 실제로 정산하는 게임. 클라이언트(game_lobby_screen.dart)의 목록과 같아야 한다.
export const STAKE_GAME_TYPES = new Set(["yut", "uno", "uno_classic", "uno_go_wild", "tank", "gostop"]);
const stakeFamily = (gameType) => (String(gameType).startsWith("uno") ? "uno" : gameType);
// 재시작(재대결)을 지원하는 게임.
export const RESTARTABLE_GAME_TYPES = new Set(["yut", "bomb", "marble", "tank"]);
for (const mod of GAME_MODULES) if (mod.restart) RESTARTABLE_GAME_TYPES.add(mod.gameType);
const GAME_MODULE_BY_TYPE = new Map(GAME_MODULES.map((mod) => [mod.gameType, mod]));
// 로비 종류(예: 제로의 로비는 'zero') → 모듈.
const GAME_MODULE_BY_LOBBY_TYPE = new Map(GAME_MODULES.map((mod) => [mod.lobbyType ?? mod.gameType, mod]));
// 로비 카운트다운(클라이언트 game_lobby_screen.dart 5초) + 화면 전환 여유.
export const LOBBY_COUNTDOWN_MS = 5300;
const PENDING_GAME_TTL_SEC = 120;
const RESTART_REQUEST_TTL_SEC = 30;

// 로비 시작 시 서버가 저장한 판돈/게임ID를 소비한다. 없으면 무료 판(stake 0).
// 클라이언트가 생성 이벤트에 실어 보낸 판돈은 절대 신뢰하지 않는다.
async function consumePendingGame(roomCode, gameType) {
  const key = pendingGameKey(roomCode, stakeFamily(gameType));
  const raw = await redis.get(key);
  if (!raw) return { stake: 0, gameId: randomUUID(), fromLobby: false, options: normalizeLobbyOptions(gameType) };
  await redis.del(key);
  try {
    const pending = JSON.parse(raw);
    return {
      stake: Number(pending.stake) || 0,
      gameId: pending.gameId ?? randomUUID(),
      fromLobby: true,
      options: normalizeLobbyOptions(gameType, pending.options),
    };
  } catch {
    return { stake: 0, gameId: randomUUID(), fromLobby: false, options: normalizeLobbyOptions(gameType) };
  }
}

const randomYutBgm = () => `yut${Math.floor(Math.random() * 3) + 1}.mp3`;

const defaultState = {
  lastDice: null,
  lastRoulette: null,
  lastRps: null,
  lastTelepathy: null,
  lastPirate: null,
  updatedAt: null,
};

const normalizeAck = (ack) => (typeof ack === "function" ? ack : () => {});

const getPresence = (io, roomCode) => {
  const room = io.sockets.adapter.rooms.get(roomCode);
  if (!room) {
    return [];
  }
  return [
    ...new Set(
      [...room]
        .map((socketId) => io.sockets.sockets.get(socketId)?.data?.userId)
        .filter(Boolean),
    ),
  ];
};

const getPresenceProfiles = (io, roomCode) => {
  const room = io.sockets.adapter.rooms.get(roomCode);
  if (!room) return {};
  return Object.fromEntries(
    [...room]
      .map((socketId) => io.sockets.sockets.get(socketId))
      .filter(Boolean)
      .map((sock) => [sock.data.userId, sock.data.profileEmoji])
      .filter(([userId, emoji]) => userId && emoji),
  );
};

const getPresenceNicknames = (io, roomCode) => {
  const room = io.sockets.adapter.rooms.get(roomCode);
  if (!room) return {};
  return Object.fromEntries(
    [...room]
      .map((socketId) => io.sockets.sockets.get(socketId))
      .filter(Boolean)
      .map((sock) => [sock.data.userId, sock.data.nickname])
      .filter(([userId, name]) => userId && name),
  );
};

const emitPresence = (io, roomCode) => {
  const nicknames = getPresenceNicknames(io, roomCode);
  io.to(roomCode).emit("room:presence", {
    roomCode,
    users: getPresence(io, roomCode),
    profileEmojis: getPresenceProfiles(io, roomCode),
    nicknames,
    displayNames: nicknames,
  });
};

const normalizeLobby = (lobby, presence) => {
  const players = (lobby?.players ?? []).filter((player) => presence.includes(player));
  const host = players.includes(lobby?.host) ? lobby.host : (players[0] ?? null);
  const rawSelections = lobby?.characterSelections ?? {};
  const characterSelections = Object.fromEntries(
    Object.entries(rawSelections).filter(([player, character]) =>
      players.includes(player) && yutCharacters.includes(character),
    ),
  );
  const rawReady = lobby?.ready ?? {};
  const ready = Object.fromEntries(
    Object.entries(rawReady).filter(([player, value]) => players.includes(player) && player !== host && value === true),
  );
  return {
    gameType: lobby?.gameType,
    host,
    players,
    characterSelections,
    stake: lobby?.stake ?? 0,
    options: normalizeLobbyOptions(lobby?.gameType, lobby?.options),
    ready,
    updatedAt: Date.now(),
  };
};

// 판돈이 걸린 판은 방장이 아닌 모든 참가자가 준비 완료해야 시작할 수 있다.
const lobbyNeedsReady = (lobby) => STAKE_GAME_TYPES.has(lobby.gameType) && (lobby.stake ?? 0) > 0;
const lobbyAllReady = (lobby) =>
  lobby.players.filter((p) => p !== lobby.host).every((p) => lobby.ready?.[p] === true);

const emitLobby = (io, roomCode, lobby) => {
  io.to(roomCode).emit("game:lobby:updated", {
    ...lobby,
    profileEmojis: getPresenceProfiles(io, roomCode),
    nicknames: getPresenceNicknames(io, roomCode),
  });
};

const cleanupLobbyForUser = async (io, roomCode, gameType, userId) => {
  const key = gameLobbyKey(roomCode, gameType);
  const lobbyText = await redis.get(key);
  if (!lobbyText) {
    return;
  }

  const lobby = normalizeLobby(JSON.parse(lobbyText), getPresence(io, roomCode));
  lobby.players = lobby.players.filter((player) => player !== userId);
  delete lobby.characterSelections[userId];
  lobby.host = lobby.players.includes(lobby.host) ? lobby.host : (lobby.players[0] ?? null);
  lobby.updatedAt = Date.now();

  if (lobby.players.length === 0) {
    await redis.del(key);
    emitLobby(io, roomCode, { gameType, host: null, players: [], updatedAt: Date.now() });
    return;
  }

  await redis.set(key, JSON.stringify(lobby), "EX", 1800);
  emitLobby(io, roomCode, lobby);
};

const resolveSocketSession = async (userId) => {
  const couple = await resolveActiveCouple(userId, query);
  return couple
    ? {
        userId: couple.UserCode,
        numericUserId: userId,
        roomCode: couple.RoomCode,
        nickname: couple.Nickname,
      }
    : null;
};

const getOrderedPlayers = async (roomCode, presence) => {
  const result = await query(
    `SELECT u1.UserCode AS User1Code, u2.UserCode AS User2Code
     FROM Couples c
     JOIN Users u1 ON c.User1Id = u1.UserId
     JOIN Users u2 ON c.User2Id = u2.UserId
     WHERE c.RoomCode = ?`,
    [roomCode],
  );

  if (result.rows.length > 0) {
    const room = result.rows[0];
    return [room.User1Code, room.User2Code].filter((user) => presence.includes(user));
  }

  return presence.slice(0, 2);
};

const emitYutState = (io, roomCode, eventName, gameState, extra = {}) => {
  io.to(roomCode).emit(eventName, {
    ...serializeYutGame(gameState),
    ...extra,
  });
};

const emitMarbleState = (io, roomCode, eventName, gameState, extra = {}) => {
  io.to(roomCode).emit(eventName, {
    ...serializeMarbleGame(gameState),
    ...extra,
  });
};


export const registerSocketHandlers = (io, { timerApi = { setTimeout, clearTimeout } } = {}) => {
  const telepathyTimers = new Map();
  const clearTelepathyTimer = (roomCode) => {
    const entry = telepathyTimers.get(roomCode);
    if (entry) timerApi.clearTimeout(entry.timer);
    telepathyTimers.delete(roomCode);
  };
  // 폭탄 돌리기: 서버가 제한 시간에 직접 폭발을 처리한다(답을 안 내고 버티는 치트 방지).
  const bombTimers = new Map();
  const clearBombTimer = (roomCode) => {
    const handle = bombTimers.get(roomCode);
    if (handle) timerApi.clearTimeout(handle);
    bombTimers.delete(roomCode);
  };
  const explodeBomb = async (roomCode, gameState) => {
    const loser = gameState.currentPlayer;
    const winner = gameState.players.find((p) => p !== loser);
    clearBombTimer(roomCode);
    await redis.del(bombGameKey(roomCode));
    io.to(roomCode).emit("game:bomb:exploded", {
      loser,
      correctAnswer: gameState.currentQuiz?.answer,
    });
    if (winner) await recordGameOutcome(roomCode, { winner, players: gameState.players, gameType: "bomb" });
  };
  const scheduleBombExplosion = (roomCode, gameState) => {
    clearBombTimer(roomCode);
    const handle = timerApi.setTimeout(() => {
      bombTimers.delete(roomCode);
      void withRoomLock(roomCode, async () => {
        const raw = await redis.get(bombGameKey(roomCode));
        if (!raw) return;
        const current = JSON.parse(raw);
        if (current.startTime !== gameState.startTime) return; // 새 판이 시작됨
        await explodeBomb(roomCode, current);
      }).catch((err) => console.error("[bomb] timer failed:", err.message));
    }, Math.max(0, gameState.startTime + gameState.duration - Date.now()));
    handle.unref?.();
    bombTimers.set(roomCode, handle);
  };

  // 이어하기 게임: 마지막 뷰어가 나가도 유예 시간 동안은 상태를 지우지 않는다.
  const sessionCleanupTimers = new Map();
  const scheduleSessionCleanup = (key, run, delayMs) => {
    const existing = sessionCleanupTimers.get(key);
    if (existing) timerApi.clearTimeout(existing);
    const handle = timerApi.setTimeout(() => {
      sessionCleanupTimers.delete(key);
      void Promise.resolve().then(run).catch((err) => console.error("[session] cleanup failed:", err.message));
    }, delayMs);
    handle.unref?.();
    sessionCleanupTimers.set(key, handle);
  };
  const cancelSessionCleanup = (key) => {
    const existing = sessionCleanupTimers.get(key);
    if (existing) timerApi.clearTimeout(existing);
    sessionCleanupTimers.delete(key);
  };
  const sessionScheduler = {
    schedule: scheduleSessionCleanup,
    cancel: cancelSessionCleanup,
    isPending: (key) => sessionCleanupTimers.has(key),
  };

  // ── 탱크 대작전 공용(서버 전체 범위): 저장·마스킹 브로드캐스트·턴 타이머·종료 처리 ──
  const tankGameKey = (rc) => `game:${rc}:tank`;
  const tankMetaKey = (rc) => `game:${rc}:tank:meta`;
  const saveTank = (roomCode, state) =>
    redis.set(tankGameKey(roomCode), JSON.stringify(state), "EX", 7200);
  const emitTankState = async (roomCode, eventName, state) => {
    const sockets = await io.in(roomCode).fetchSockets();
    for (const sock of sockets) {
      if (!sock.data.userId) continue;
      sock.emit(eventName, tankViewFor(state, sock.data.userId));
    }
  };
  const tankTimers = new Map();
  const clearTankTimer = (roomCode) => {
    const handle = tankTimers.get(roomCode);
    if (handle) timerApi.clearTimeout(handle);
    tankTimers.delete(roomCode);
  };
  // 정산 → 결과 기록 → 상태 삭제. 판마다 고정된 gameId로 정산해 재처리돼도 한 번만 지급된다.
  const finishTankGame = async (roomCode, state) => {
    clearTankTimer(roomCode);
    const winner = state.winner;
    const players = state.players.map((p) => p.id);
    const stake = state.stake ?? 0;
    if (winner && winner !== "draw" && stake > 0) {
      const loser = players.find((p) => p !== winner);
      const wallet = await settleAndEmitWallet(io, roomCode, winner, loser, stake, `tank:${state.gameId ?? roomCode}`);
      if (!wallet.ok) io.to(roomCode).emit("wallet:settle_failed", { gameType: "tank", reason: wallet.reason });
    }
    await recordGameOutcome(roomCode, {
      winner: winner === "draw" ? null : winner,
      players,
      gameType: "tank",
      stake,
      gameId: state.gameId ?? null,
    });
    await redis.set(tankMetaKey(roomCode), JSON.stringify({ series: state.series, stake }), "EX", 7200);
    await redis.del(tankGameKey(roomCode));
    io.to(roomCode).emit("game:tank:ended", {
      winner,
      reason: state.endReason,
      summary: tankBattleSummary(state),
      series: state.series,
      state: tankViewFor(state, null),
    });
  };
  const scheduleTankTimer = (roomCode, state) => {
    clearTankTimer(roomCode);
    if (state.phase !== "aiming" || !state.turnDeadline) return;
    const marker = { gameId: state.gameId, turnNumber: state.turnNumber, turn: state.turn };
    const handle = timerApi.setTimeout(() => {
      tankTimers.delete(roomCode);
      void withRoomLock(roomCode, async () => {
        const raw = await redis.get(tankGameKey(roomCode));
        if (!raw) return;
        const current = JSON.parse(raw);
        if (current.gameId !== marker.gameId || current.turnNumber !== marker.turnNumber ||
            current.turn !== marker.turn || current.phase !== "aiming") return;
        const result = timeoutTankTurn(current);
        if (!result.ok) return;
        io.to(roomCode).emit("game:tank:timeout", {
          player: current.players[current.turn].id,
          count: result.state.timeouts[current.turn],
          forfeited: result.forfeited,
          events: result.events,
        });
        if (result.state.phase === "result") {
          await finishTankGame(roomCode, result.state);
          return;
        }
        result.state.turnDeadline = Date.now() + TANK_TURN_TIME_MS;
        await saveTank(roomCode, result.state);
        await emitTankState(roomCode, "game:tank:updated", result.state);
        scheduleTankTimer(roomCode, result.state);
      }).catch((err) => console.error("[tank] timer failed:", err.message));
    }, Math.max(0, state.turnDeadline - Date.now()));
    handle.unref?.();
    tankTimers.set(roomCode, handle);
  };
  // 재대결: 이전 판의 시리즈 점수와 판돈을 이어받아 새 판을 연다(두 사람이 동의한 재시작).
  const restartTankGame = async (roomCode, p1, p2) => {
    const current = await redis.get(tankGameKey(roomCode));
    const metaRaw = await redis.get(tankMetaKey(roomCode));
    const previous = current ? JSON.parse(current) : (metaRaw ? JSON.parse(metaRaw) : {});
    const state = createFortressState(p1, p2, {
      stake: previous.stake ?? 0,
      gameId: randomUUID(),
      series: previous.series ?? { [p1]: 0, [p2]: 0 },
    });
    clearTankTimer(roomCode);
    await saveTank(roomCode, state);
    await emitTankState(roomCode, "game:tank:started", state);
  };
  // 재접속 시 진행 중인 탱크전의 턴 타이머가 없으면(서버 재시작 등) 다시 예약한다.
  const ensureTankTimer = (roomCode, state) => {
    if (state?.phase === "aiming" && !tankTimers.has(roomCode)) scheduleTankTimer(roomCode, state);
  };

  // ── 턴제 게임 공통 잠수(AFK) 기권패 ──────────────────────────────────────────
  // 차례인 사람이 90초 동안 아무것도 하지 않으면(60초에 경고) 상대의 기권승이다.
  // 지는 쪽이 앱을 꺼 버려도 판이 무한 대기하거나 정산 없이 사라지지 않는다.
  const notPicked = (startRolls, players) => players.find((p) => startRolls?.[p] == null) ?? null;
  const emitGostopRoom = async (roomCode, eventName, state) => {
    const sockets = await io.in(roomCode).fetchSockets();
    for (const sock of sockets) {
      if (sock.data.userId) sock.emit(eventName, serializeGostopFor(state, sock.data.userId));
    }
  };
  // 판돈 게임의 기권 정산: 정산 → 결과 기록 → 상태 삭제.
  const settleForfeit = async (roomCode, { gameType, missionKey, key, winner, loser, stake, gameId }) => {
    if (winner && loser && stake > 0) {
      const wallet = await settleAndEmitWallet(io, roomCode, winner, loser, stake, `${gameType}:${gameId}`);
      if (!wallet.ok) io.to(roomCode).emit("wallet:settle_failed", { gameType, reason: wallet.reason });
    }
    await recordGameOutcome(roomCode, { winner, players: [winner, loser], gameType, missionKey, stake, gameId });
    await redis.del(key);
  };
  const afkAdapters = {
    yut: {
      key: yutGameKey,
      playersOf: (s) => s.playersOrder ?? [],
      waitingOn: (s) => {
        if (s.winner) return null;
        if (s.phase === "roll_order") return notPicked(s.startRolls, s.playersOrder ?? []);
        if (s.phase === "order_countdown") return null;
        return s.currentTurn ?? null;
      },
      forfeit: async (roomCode, s, loser, winner) => {
        io.to(roomCode).emit("game:yut:ended", { winner, reason: "forfeit" });
        await settleForfeit(roomCode, {
          gameType: "yut", missionKey: "yut", key: yutGameKey(roomCode), winner, loser,
          stake: s.stake ?? 0, gameId: s.gameId ?? s.id,
        });
      },
    },
    marble: {
      key: marbleGameKey,
      playersOf: (s) => s.playersOrder ?? [],
      waitingOn: (s) => {
        if (s.winner || s.winReason === "timeout_draw") return null;
        if (s.phase === "roll_order") return notPicked(s.startRolls, s.playersOrder ?? []);
        if (s.phase === "order_countdown") return null;
        if (s.pendingLandAction?.userId) return s.pendingLandAction.userId;
        return s.currentTurn ?? null;
      },
      forfeit: async (roomCode, s, loser, winner) => {
        io.to(roomCode).emit("game:marble:ended", { winner, winReason: "forfeit", finalScores: null });
        await redis.del(marbleGameKey(roomCode));
        await recordGameOutcome(roomCode, { winner, players: s.playersOrder, gameType: "marble" });
      },
    },
    gostop: {
      key: gostopGameKey,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => {
        if (["finished", "nageori", "chongtong"].includes(s.phase)) return null;
        if (s.settlementStatus === "pending") return null;
        if (s.phase === "shake_choice") return s.shakePlayerId ?? null;
        return s.players?.[s.currentPlayerIdx] ?? null;
      },
      forfeit: async (roomCode, s, loser, winner) => {
        const finished = forfeitGostop(s, winner);
        const st = finished.settlement;
        if (st && st.amount > 0) {
          const wallet = await settleAndEmitWallet(io, roomCode, st.winnerId, st.loserId, st.amount, finished.gameId ?? `gostop:${roomCode}:forfeit`);
          if (!wallet.ok) {
            const pending = { ...finished, settlementStatus: "pending", settlementError: wallet.reason ?? "wallet_settlement_failed" };
            await redis.set(gostopGameKey(roomCode), JSON.stringify(pending), "EX", 7200);
            await emitGostopRoom(roomCode, "game:gostop:settlement_pending", pending);
            return;
          }
        }
        await recordGameOutcome(roomCode, { winner, players: s.players, gameType: "gostop", stake: st?.amount ?? 0, gameId: finished.gameId ?? null });
        await redis.del(gostopGameKey(roomCode));
        await emitGostopRoom(roomCode, "game:gostop:ended", { ...finished, settlementStatus: "settled" });
      },
    },
    blackjack: {
      key: (rc) => `game:${rc}:blackjack`,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => (s.status === "playing" && s.phase !== "round_result" ? s.currentTurn ?? null : null),
      forfeit: async (roomCode, s, loser, winner) => {
        const finished = { ...s, status: "finished", currentTurn: null, result: { ...(s.result ?? {}), winner, loser, reason: "forfeit" } };
        await redis.set(`game:${roomCode}:blackjack`, JSON.stringify(finished), "EX", 3600);
        await emitBlackjackState(io, roomCode, finished);
        await recordGameOutcome(roomCode, { winner, players: s.players, gameType: "blackjack" });
      },
    },
    oldmaid: {
      key: (rc) => `game:${rc}:oldmaid`,
      playersOf: (s) => Object.keys(s.players ?? {}),
      waitingOn: (s) => (s.status === "playing" ? s.turn ?? null : null),
      forfeit: async (roomCode, s, loser, winner) => {
        const finished = { ...s, status: "finished", result: { winner, loser, reason: "forfeit" } };
        await redis.set(`game:${roomCode}:oldmaid`, JSON.stringify(finished), "EX", 3600);
        await emitOldMaidState(io, roomCode, finished);
        await recordGameOutcome(roomCode, { winner, players: [winner, loser], gameType: "oldmaid" });
      },
    },
    bowling: {
      key: (rc) => `game:${rc}:bowling`,
      playersOf: (s) => Object.keys(s.scores ?? {}),
      waitingOn: (s) => (s.status === "playing" ? s.turn ?? null : null),
      forfeit: async (roomCode, s, loser, winner) => {
        const finished = { ...s, status: "finished", result: { winner, scores: s.scores, reason: "forfeit" } };
        await redis.set(`game:${roomCode}:bowling`, JSON.stringify(finished), "EX", 3600);
        io.to(roomCode).emit("game:bowling:updated", withBowlingFrames(finished));
        await recordGameOutcome(roomCode, { winner, players: Object.keys(s.scores), gameType: "bowling" });
      },
    },
    penalty: {
      key: (rc) => `game:${rc}:penalty`,
      playersOf: (s) => Object.keys(s.scores ?? {}),
      // 한 사람만 제출했을 때 나머지 한 사람을 기다린다(둘 다 안 냈으면 감시하지 않음).
      waitingOn: (s) => {
        if (s.status !== "playing") return null;
        const pair = [String(s.kicker), String(s.keeper)];
        const missing = pair.filter((p) => s.submissions?.[p] === undefined);
        return missing.length === 1 ? missing[0] : null;
      },
      forfeit: async (roomCode, s, loser, winner) => {
        const finished = { ...s, status: "finished", submissions: {}, result: { winner, scores: s.scores, reason: "forfeit" } };
        await redis.set(`game:${roomCode}:penalty`, JSON.stringify(finished), "EX", 3600);
        io.to(roomCode).emit("game:penalty:updated", maskPenaltyState(finished));
        await recordGameOutcome(roomCode, { winner, players: Object.keys(s.scores), gameType: "penalty" });
      },
    },
    pirate: {
      key: pirateKey,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => s.currentTurn ?? null,
      forfeit: async (roomCode, s, loser, winner) => {
        await redis.del(pirateKey(roomCode));
        io.to(roomCode).emit("game:pirate:exploded", { loser, bombSlot: s.bombSlot, forfeit: true, at: Date.now() });
        await recordGameOutcome(roomCode, { winner, players: s.players, gameType: "pirate" });
      },
    },
    rps: {
      key: rpsGameKey,
      playersOf: (s) => s.players ?? [],
      waitingOn: (s) => {
        if (s.gameWinner) return null;
        const missing = (s.players ?? []).filter((p) => s.picks?.[p] === undefined);
        return missing.length === 1 ? missing[0] : null;
      },
      forfeit: async (roomCode, s, loser) => {
        await redis.del(rpsGameKey(roomCode));
        io.to(roomCode).emit("game:rps:cancelled", { reason: "afk", by: loser });
      },
    },
  };
  // 게임 2.0 모듈이 쓰는 공용 도구. 모듈의 잠수 어댑터가 같은 게임의 옛 어댑터를 대신한다.
  const kit = {
    io,
    redis,
    timerApi,
    withRoomLock,
    normalizeAck,
    getPresence: (roomCode) => getPresence(io, roomCode),
    getOrderedPlayers,
    consumePendingGame,
    recordGameOutcome,
    presenceProfiles: (roomCode) => getPresenceProfiles(io, roomCode),
    presenceNicknames: (roomCode) => getPresenceNicknames(io, roomCode),
    series: createSeriesStore(redis),
    randomUUID,
    // 판돈 게임 정산(원카드): 기존 정산 경로를 그대로 쓴다.
    settleWallet: (...args) => settleAndEmitWallet(io, ...args),
    winStreak: _getWinStreak,
  };
  for (const mod of GAME_MODULES) if (mod.afk) afkAdapters[mod.gameType] = mod.afk(kit);
  const afkWatcher = createAfkWatcher({ io, redis, timerApi, withRoomLock, adapters: afkAdapters });
  const allowReaction = createReactionLimiter();

  io.httpServer?.once("close", () => {
    for (const roomCode of telepathyTimers.keys()) clearTelepathyTimer(roomCode);
    for (const roomCode of [...bombTimers.keys()]) clearBombTimer(roomCode);
    for (const key of [...sessionCleanupTimers.keys()]) cancelSessionCleanup(key);
    for (const roomCode of [...tankTimers.keys()]) clearTankTimer(roomCode);
    afkWatcher.clearAll();
    for (const mod of GAME_MODULES) mod.dispose?.();
  });
  const publishTelepathyResult = async (roomCode, session, extra = {}) => {
    const event = { ...telepathyResult(session), ...extra };
    session.result = event;
    await redis.set(`telepathy:${roomCode}:session`, JSON.stringify(session), "EX", TELEPATHY_SESSION_TTL_SEC);
    const stateText = await redis.get(roomKey(roomCode));
    const state = stateText ? JSON.parse(stateText) : defaultState;
    await redis.set(roomKey(roomCode), JSON.stringify({ ...state, lastTelepathy: event, updatedAt: event.at }));
    io.to(roomCode).emit("game:telepathy:result", event);
    return event;
  };
  const scheduleTelepathyExpiry = (roomCode, session) => {
    clearTelepathyTimer(roomCode);
    const entry = { sessionId: session.id, timer: null };
    entry.timer = timerApi.setTimeout(() => {
      void withRoomLock(roomCode, async () => {
        // An already queued callback must not remove a newer round's timer.
        if (telepathyTimers.get(roomCode) !== entry) return;
        telepathyTimers.delete(roomCode);
        const sessionKey = `telepathy:${roomCode}:session`;
        const raw = await redis.get(sessionKey);
        if (!raw) return;
        const current = JSON.parse(raw);
        if (current.id !== session.id || current.revealed || current.expired) return;
        current.expired = true;
        await publishTelepathyResult(roomCode, current, { expired: true });
      }).catch(err => console.error("[telepathy] expiry failed:", err.message));
    }, Math.max(0, session.deadlineAt - Date.now()));
    entry.timer.unref?.();
    telepathyTimers.set(roomCode, entry);
  };
  installSocketAuthentication(io, config.JWT_SECRET, resolveSocketSession);
  io.on("connection", (socket) => {
    installHandlerSafetyNet(socket, console, (event, args) => {
      const gameType = afkGameTypeForEvent(event, args[0]);
      if (gameType) return afkWatcher.refresh(socket.data.roomCode, gameType);
      return undefined;
    });
    installSocketFeatureGate(socket, config.PUBLIC_FEATURE_SET);
    registerGameSessionHandlers(socket, { io, redis, scheduler: sessionScheduler });
    for (const mod of GAME_MODULES) mod.register?.(socket, kit);

    // 공용 리액션(게임 2.0): 허용된 이모지 6개, 사용자별 1.5초 간격.
    socket.on("game:reaction", (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const emoji = payload?.emoji;
      if (!REACTION_EMOJIS.includes(emoji)) { ack({ ok: false, reason: "invalid_reaction" }); return; }
      if (!allowReaction(userId)) { ack({ ok: false, reason: "too_fast" }); return; }
      const gameType = typeof payload?.gameType === "string" ? payload.gameType.slice(0, 16) : null;
      io.to(roomCode).emit("game:reaction", { by: userId, emoji, gameType, at: Date.now() });
      ack({ ok: true });
    });
    socket.on("session:join", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const parsed = joinSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { profileEmoji } = parsed.data;
      const { userId, roomCode, nickname } = socket.data;

      const presence = getPresence(io, roomCode);
      if (presence.length >= 2 && !presence.includes(userId)) {
        ack({ ok: false, reason: "room_full" });
        return;
      }

      socket.data.userId = userId;
      socket.data.roomCode = roomCode;
      socket.data.profileEmoji = profileEmoji ?? "🙂";
      socket.data.nickname = nickname;
      await socket.join(roomCode);

      const stateText = await redis.get(roomKey(roomCode));
      const state = stateText ? JSON.parse(stateText) : defaultState;

      emitPresence(io, roomCode);

      // Redis survives a process restart; restore its original deadline when
      // either participant rejoins rather than leaving the stored round stuck.
      await withRoomLock(roomCode, async () => {
        const key = `telepathy:${roomCode}:session`;
        const raw = await redis.get(key);
        if (!raw) return;
        const session = JSON.parse(raw);
        if (session.revealed || session.expired) return;
        session.id ??= randomUUID();
        session.deadlineAt ??= (session.updatedAt ?? Date.now()) + TELEPATHY_RESPONSE_TIMEOUT_MS;
        await redis.set(key, JSON.stringify(session), "EX", TELEPATHY_SESSION_TTL_SEC);
        scheduleTelepathyExpiry(roomCode, session);
      });
      // Restore active pirate game state for reconnecting player.
      const pirateReconnect = await redis.get(pirateKey(roomCode));
      if (pirateReconnect) {
        const pirateState = JSON.parse(pirateReconnect);
        if (pirateState.players?.includes(userId)) {
          socket.emit("game:pirate:started", {
            slots: pirateState.slots,
            players: pirateState.players,
            currentTurn: pirateState.currentTurn,
            pickedSlots: pirateState.pickedSlots,
            at: Date.now(),
            reconnect: true,
          });
        }
      }

      ack({ ok: true, state, roomCode, userId });
    });

    socket.on("profile:update", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = profileSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      socket.data.profileEmoji = parsed.data.profileEmoji;
      emitPresence(io, roomCode);
      ack({ ok: true });
    });

    socket.on("game:lobby:join", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = lobbySchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { gameType, stake } = parsed.data;

      // Check for an active game that the partner is viewing — resume it instead of creating a lobby.
      const resume = await resolveLobbyJoinForResume(socket, io, redis, { roomCode, gameType, userId }, sessionScheduler);
      if (resume) {
        ack({ ok: true, ...resume });
        return;
      }

      const key = gameLobbyKey(roomCode, gameType);
      await withLobbyLock(key, async () => {
        const presence = getPresence(io, roomCode);
        const lobbyText = await redis.get(key);
        const baseLobby = lobbyText ? JSON.parse(lobbyText) : { gameType, host: null, players: [], stake: 0 };
        const lobby = normalizeLobby({ ...baseLobby, gameType }, presence);

        if (!lobby.players.includes(userId)) {
          lobby.players.push(userId);
          lobby.ready = {};
        }
        if (!lobby.host) {
          lobby.host = userId;
        }
        // 방장만 stake 변경 가능, 판돈 대상 게임만 판돈을 가진다.
        if (!STAKE_GAME_TYPES.has(gameType)) {
          lobby.stake = 0;
        } else if (userId === lobby.host && stake > 0 && (gameType !== 'gostop' || GOSTOP_STAKES.has(stake))) {
          lobby.stake = stake;
          lobby.ready = {};
        } else if (!lobby.stake) {
          lobby.stake = 0;
        }
        lobby.updatedAt = Date.now();

        // Newly opened lobby while partner is away = invite. Redis NX dedupes spam for 60s.
        if (!lobbyText && presence.length < 2) {
          const inviteKey = `push:game_invite:${roomCode}:${gameType}`;
          const inviteId = randomUUID();
          if ((await redis.set(inviteKey, inviteId, "EX", 60, "NX")) === "OK") {
            const releaseInvite = () => withLobbyLock(key, async () => {
              if (await redis.get(inviteKey) === inviteId) await redis.del(inviteKey);
            });
            void Promise.resolve().then(() => notifier.notifyPartner(
              socket.data.numericUserId, "game_invite", {
                game_type: gameType,
                room_code: roomCode,
              },
            )).then(async result => {
              if (result?.skipped === "error" || (result?.sent === 0 && !result?.skipped)) {
                await releaseInvite();
              }
            }).catch(async err => {
              console.error("[push] game invite failed:", err.message);
              await releaseInvite();
            }).catch(err => console.error("[push] invite cleanup failed:", err.message));
          }
        }

        await redis.set(key, JSON.stringify(lobby), "EX", 1800);
        emitLobby(io, roomCode, lobby);
        ack({ ok: true, status: "waiting", lobby: { ...lobby, profileEmojis: getPresenceProfiles(io, roomCode), nicknames: getPresenceNicknames(io, roomCode) } });
      });
    });

    socket.on("game:lobby:set_stake", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = lobbyStakeSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }
      const { gameType, stake } = parsed.data;
      if (!STAKE_GAME_TYPES.has(gameType) && stake > 0) {
        ack({ ok: false, reason: "stake_not_supported" });
        return;
      }
      if (gameType === 'gostop' && !GOSTOP_STAKES.has(stake)) {
        ack({ ok: false, reason: "invalid_stake" });
        return;
      }
      const key = gameLobbyKey(roomCode, gameType);
      await withLobbyLock(key, async () => {
        const lobbyText = await redis.get(key);
        if (!lobbyText) { ack({ ok: false, reason: "lobby_not_found" }); return; }
        const lobby = normalizeLobby(JSON.parse(lobbyText), getPresence(io, roomCode));
        if (lobby.host !== userId) { ack({ ok: false, reason: "not_host" }); return; }
        if (lobby.stake !== stake) lobby.ready = {}; // 금액이 바뀌면 다시 동의를 받는다.
        lobby.stake = stake;
        lobby.updatedAt = Date.now();
        await redis.set(key, JSON.stringify(lobby), "EX", 1800);
        emitLobby(io, roomCode, lobby);
        ack({ ok: true });
      });
    });

    // 방장이 게임별 설정(로비 옵션)을 바꾼다. 상대에게도 바로 보이고, 바뀌면 다시 동의를 받는다.
    socket.on("game:lobby:set_option", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = lobbyOptionSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }
      const { gameType, key: optionKey, value } = parsed.data;
      const key = gameLobbyKey(roomCode, gameType);
      await withLobbyLock(key, async () => {
        const lobbyText = await redis.get(key);
        if (!lobbyText) { ack({ ok: false, reason: "lobby_not_found" }); return; }
        const lobby = normalizeLobby(JSON.parse(lobbyText), getPresence(io, roomCode));
        if (lobby.host !== userId) { ack({ ok: false, reason: "not_host" }); return; }
        if (!isValidLobbyOption(gameType, optionKey, value)) { ack({ ok: false, reason: "invalid_option" }); return; }
        if (lobby.options[optionKey] !== value) lobby.ready = {};
        lobby.options = { ...lobby.options, [optionKey]: value };
        lobby.updatedAt = Date.now();
        await redis.set(key, JSON.stringify(lobby), "EX", 1800);
        emitLobby(io, roomCode, lobby);
        ack({ ok: true, options: lobby.options });
      });
    });

    socket.on("game:lobby:ready", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = lobbyReadySchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }
      const { gameType, ready } = parsed.data;
      const key = gameLobbyKey(roomCode, gameType);
      await withLobbyLock(key, async () => {
        const lobbyText = await redis.get(key);
        if (!lobbyText) { ack({ ok: false, reason: "lobby_not_found" }); return; }
        const lobby = normalizeLobby(JSON.parse(lobbyText), getPresence(io, roomCode));
        if (!lobby.players.includes(userId)) { ack({ ok: false, reason: "not_in_lobby" }); return; }
        if (lobby.host === userId) { ack({ ok: false, reason: "host_cannot_ready" }); return; }
        lobby.ready = { ...lobby.ready, [userId]: ready };
        if (!ready) delete lobby.ready[userId];
        lobby.updatedAt = Date.now();
        await redis.set(key, JSON.stringify(lobby), "EX", 1800);
        emitLobby(io, roomCode, lobby);
        ack({ ok: true });
      });
    });

    socket.on("game:lobby:leave", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = lobbySchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      await cleanupLobbyForUser(io, roomCode, parsed.data.gameType, userId);
      ack({ ok: true });
    });

    socket.on("game:lobby:select_character", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = lobbyCharacterSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { gameType, character } = parsed.data;
      const key = gameLobbyKey(roomCode, gameType);
      const lobbyText = await redis.get(key);
      if (!lobbyText) {
        ack({ ok: false, reason: "lobby_not_found" });
        return;
      }

      const lobby = normalizeLobby(JSON.parse(lobbyText), getPresence(io, roomCode));
      if (!lobby.players.includes(userId)) {
        ack({ ok: false, reason: "not_in_lobby" });
        return;
      }

      const takenBy = Object.entries(lobby.characterSelections).find(
        ([player, selected]) => player !== userId && selected === character,
      )?.[0];
      if (takenBy) {
        ack({ ok: false, reason: "character_taken", takenBy });
        return;
      }

      lobby.characterSelections = {
        ...lobby.characterSelections,
        [userId]: character,
      };
      lobby.updatedAt = Date.now();

      await redis.set(key, JSON.stringify(lobby), "EX", 1800);
      emitLobby(io, roomCode, lobby);
      ack({ ok: true, lobby: { ...lobby, profileEmojis: getPresenceProfiles(io, roomCode), nicknames: getPresenceNicknames(io, roomCode) } });
    });

    socket.on("game:lobby:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = lobbySchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { gameType } = parsed.data;
      const key = gameLobbyKey(roomCode, gameType);
      const lobbyText = await redis.get(key);
      if (!lobbyText) {
        ack({ ok: false, reason: "lobby_not_found" });
        return;
      }

      const lobby = normalizeLobby(JSON.parse(lobbyText), getPresence(io, roomCode));
      if (lobby.host !== userId) {
        ack({ ok: false, reason: "not_host" });
        return;
      }
      if (lobby.players.length < 2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }
      if (gameType === 'gostop' && !GOSTOP_STAKES.has(lobby.stake ?? 0)) {
        ack({ ok: false, reason: "invalid_stake" });
        return;
      }
      if (lobbyNeedsReady(lobby) && !lobbyAllReady(lobby)) {
        ack({ ok: false, reason: "partner_not_ready" });
        return;
      }
      const stakeForGame = STAKE_GAME_TYPES.has(gameType) ? (lobby.stake ?? 0) : 0;
      const gameId = randomUUID();
      // 생성 이벤트는 이 서버 기록에서만 판돈을 가져온다(클라이언트 payload 무시).
      await redis.set(
        pendingGameKey(roomCode, stakeFamily(gameType)),
        JSON.stringify({ gameId, gameType, stake: stakeForGame, options: lobby.options, host: lobby.host, players: lobby.players, createdAt: Date.now() }),
        "EX",
        PENDING_GAME_TTL_SEC,
      );
      const metadata = gameType === "yut"
        ? {
            yutBgm: randomYutBgm(),
            stake: stakeForGame,
            gameId,
            options: lobby.options,
          }
        : { stake: stakeForGame, gameId, options: lobby.options };
      // 게임 2.0 모듈은 서버가 로비 시작과 함께 판을 만든다(게임 화면에는 시작 버튼이 없다).
      const lobbyModule = GAME_MODULE_BY_LOBBY_TYPE.get(gameType);
      if (lobbyModule?.startFromLobby) metadata.serverStart = true;
      await redis.del(key);
      io.to(roomCode).emit("game:lobby:started", {
        gameType,
        host: lobby.host,
        players: lobby.players,
        profileEmojis: getPresenceProfiles(io, roomCode),
        nicknames: getPresenceNicknames(io, roomCode),
        metadata,
        at: Date.now(),
      });
      if (lobbyModule?.startFromLobby) {
        await redis.del(pendingGameKey(roomCode, stakeFamily(gameType)));
        const ordered = await getOrderedPlayers(roomCode, lobby.players);
        await lobbyModule.startFromLobby(roomCode, kit, {
          players: ordered.length === lobby.players.length ? ordered : lobby.players,
          options: lobby.options,
          gameId,
          stake: stakeForGame,
          host: lobby.host,
          lobbyType: gameType,
          startsAt: Date.now() + LOBBY_COUNTDOWN_MS,
        });
      }
      ack({ ok: true });
    });

    // 재접속 시 게임 세션 복원
    socket.on("session:restore", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      if (!roomCode) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      try {
        // 활성 게임 세션 확인
        const yutKey = `yut:${roomCode}:game`;
        const gostopKey = gostopGameKey(roomCode);
        const bombKey = `bomb:${roomCode}:game`;
        const marbleKey = marbleGameKey(roomCode);

        const [yutGame, gostopGame, bombGame, marbleGame] = await Promise.all([
          redis.get(yutKey),
          redis.get(gostopKey),
          redis.get(bombKey),
          redis.get(marbleKey),
        ]);

        const activeGames = {};
        
        if (yutGame) {
          const game = JSON.parse(yutGame);
          if (game.players) {
            activeGames.yut = serializeYutGame(game);
          }
        }

        if (gostopGame) {
          const game = JSON.parse(gostopGame);
          if (game.players?.includes(socket.data.userId)) {
            activeGames.gostop = serializeGostopFor(game, socket.data.userId);
          }
        }

        if (bombGame) {
          const game = JSON.parse(bombGame);
          const elapsed = Math.floor((Date.now() - game.startTime) / 1000);
          const remaining = Math.max(0, Math.round(game.duration / 1000) - elapsed);

          activeGames.bomb = {
            currentPlayer: game.currentPlayer,
            timer: remaining,
            startTime: game.startTime,
            duration: Math.round(game.duration / 1000),
            category: game.currentQuiz?.category,
            question: game.currentQuiz?.question,
          };
        }

        // 마블 게임 세션 복원
        if (marbleGame) {
          const game = JSON.parse(marbleGame);
          if (game.playersOrder && !game.winner) {
            activeGames.marble = serializeMarbleGame(game);
          }
        }

        // session:restore itself must reserve the viewer room. Otherwise a
        // reconnecting socket can render the game but the old viewer's
        // disconnect immediately deletes the last active Redis state.
        const restoredGameType = ['yut', 'marble', 'gostop']
          .find((type) => activeGames[type]);
        if (restoredGameType) {
          sessionScheduler.cancel(`${roomCode}:${restoredGameType}`);
          await socket.join(`game-view:${roomCode}:${restoredGameType}`);
          socket.data.viewingGame = restoredGameType;
        }

        // 비재개형 게임: 각 게임의 기존 업데이트 이벤트로 현재 상태를 이 소켓에만 다시 보낸다.
        // (클라이언트의 기존 리스너가 그대로 처리하므로 재접속 교착이 사라진다.)
        const userId = socket.data.userId;
        const [bjRaw, omRaw, pkRaw, bwRaw, tkRaw, ctRaw] = await Promise.all([
          redis.get(`game:${roomCode}:blackjack`),
          redis.get(`game:${roomCode}:oldmaid`),
          redis.get(`game:${roomCode}:penalty`),
          redis.get(`game:${roomCode}:bowling`),
          redis.get(`game:${roomCode}:tank`),
          redis.get(`game:${roomCode}:catch`),
        ]);
        const restored = [];
        for (const mod of GAME_MODULES) {
          if (mod.restore && await mod.restore(roomCode, socket, kit)) restored.push(mod.gameType);
        }
        if (bjRaw) {
          const g = JSON.parse(bjRaw);
          if (g.status !== "finished" && g.players?.includes(userId)) {
            socket.emit("game:blackjack:updated", serializeBlackjackFor(g, userId));
            restored.push("blackjack");
          }
        }
        if (omRaw) {
          const g = JSON.parse(omRaw);
          if (g.status !== "finished" && g.players?.[userId]) {
            socket.emit("game:oldmaid:updated", serializeOldMaidGame(g, userId));
            restored.push("oldmaid");
          }
        }
        if (pkRaw) {
          const g = JSON.parse(pkRaw);
          if (g.status === "playing" && Object.prototype.hasOwnProperty.call(g.scores ?? {}, userId)) {
            socket.emit("game:penalty:updated", maskPenaltyState(g));
            restored.push("penalty");
          }
        }
        if (bwRaw) {
          const g = JSON.parse(bwRaw);
          if (g.status === "playing" && Object.prototype.hasOwnProperty.call(g.scores ?? {}, userId)) {
            socket.emit("game:bowling:updated", withBowlingFrames(g));
            restored.push("bowling");
          }
        }
        if (tkRaw) {
          const g = JSON.parse(tkRaw);
          if (!g.winner && g.players?.some((p) => p.id === userId)) {
            socket.emit("game:tank:started", tankViewFor(g, userId));
            ensureTankTimer(roomCode, g);
            restored.push("tank");
          }
        }
        if (ctRaw) {
          const g = JSON.parse(ctRaw);
          if (g.phase !== "gameover" && Object.prototype.hasOwnProperty.call(g.scores ?? {}, userId)) {
            await emitCatchStateTo(socket, roomCode, g);
            restored.push("catch");
          }
        }

        ack({ ok: true, activeGames, restored });
      } catch (err) {
        console.error(`session:restore error: ${err.message}`);
        ack({ ok: false, reason: "internal_error" });
      }
    });

    socket.on("sync:ping", (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      ack({
        ok: true,
        clientTs: payload?.clientTs ?? null,
        serverTs: Date.now(),
      });
    });

    socket.on("game:dice:roll", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
        const value = Math.floor(Math.random() * 6) + 1;
        const event = { value, by: userId, at: Date.now() };

        const stateText = await redis.get(roomKey(roomCode));
        const state = stateText ? JSON.parse(stateText) : defaultState;
        const nextState = { ...state, lastDice: event, updatedAt: Date.now() };
        await redis.set(roomKey(roomCode), JSON.stringify(nextState));

        io.to(roomCode).emit("game:dice:result", event);
        ack({ ok: true, event });
      });
    });

    // Propose options — each player submits their list; spin merges both.
    socket.on("game:roulette:propose", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const parsed = rouletteSchema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });
      await withRoomLock(roomCode, async () => {
        const proposeKey = `roulette:${roomCode}:proposals`;
        const raw = await redis.get(proposeKey);
        const proposals = raw ? JSON.parse(raw) : {};
        proposals[userId] = parsed.data.options;
        await redis.set(proposeKey, JSON.stringify(proposals), "EX", 300);
        io.to(roomCode).emit("game:roulette:proposed", { by: userId, count: parsed.data.options.length });
        ack({ ok: true });
      });
    });

    socket.on("game:roulette:spin", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = rouletteSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      await withRoomLock(roomCode, async () => {
        // Merge proposals from both players if available; else use initiator's options.
        const proposeKey = `roulette:${roomCode}:proposals`;
        const raw = await redis.get(proposeKey);
        const proposals = raw ? JSON.parse(raw) : {};
        proposals[userId] = parsed.data.options;
        const allOptions = Object.values(proposals).flat();
        const options = allOptions.length >= 2 ? allOptions : parsed.data.options;
        await redis.del(proposeKey);

        const index = Math.floor(Math.random() * options.length);
        const event = {
          index,
          selected: options[index],
          options,
          by: userId,
          at: Date.now(),
        };

        const stateText = await redis.get(roomKey(roomCode));
        const state = stateText ? JSON.parse(stateText) : defaultState;
        const nextState = { ...state, lastRoulette: event, updatedAt: Date.now() };
        await redis.set(roomKey(roomCode), JSON.stringify(nextState));

        io.to(roomCode).emit("game:roulette:result", event);
        ack({ ok: true, event });
      });
    });

    // ── RPS legacy (kept for safety) ─────────────────────────────────────────
    socket.on("game:rps:select", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = rpsSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }
      await withRoomLock(roomCode, async () => {
        const { choice } = parsed.data;
        const sessionKey = `rps:${roomCode}:session`;
        const existing = await redis.get(sessionKey);
        const session = existing ? JSON.parse(existing) : { choices: {}, revealed: false };
        session.choices[userId] = choice;
        const presence = getPresence(io, roomCode);
        if (Object.keys(session.choices).length === presence.length && presence.length === 2) {
          const [u1, u2] = Object.keys(session.choices);
          const c1 = session.choices[u1], c2 = session.choices[u2];
          const winner = c1 === c2 ? "draw"
            : ((c1==="rock"&&c2==="scissors")||(c1==="scissors"&&c2==="paper")||(c1==="paper"&&c2==="rock")) ? u1 : u2;
          await redis.del(sessionKey);
          const event = { choices: session.choices, winner, at: Date.now() };
          io.to(roomCode).emit("game:rps:result", event);
          ack({ ok: true, result: event });
        } else {
          await redis.set(sessionKey, JSON.stringify(session), "EX", 60);
          ack({ ok: true, waiting: true });
        }
      });
    });

    // ── RPS multi-mode ────────────────────────────────────────────────────────
    const rpsWinner = (c1, c2) =>
      c1 === c2 ? "draw"
      : ((c1==="rock"&&c2==="scissors")||(c1==="scissors"&&c2==="paper")||(c1==="paper"&&c2==="rock"))
        ? "p1" : "p2";

    socket.on("game:rps:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = rpsStartSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }
      const { mode } = parsed.data;
      await withRoomLock(roomCode, async () => {
        const presence = getPresence(io, roomCode);
        if (presence.length < 2) { ack({ ok: false, reason: "need_two_players" }); return; }
        const players = await getOrderedPlayers(roomCode, presence);
        if (players.length !== 2) { ack({ ok: false, reason: "need_two_players" }); return; }
        const existing = await redis.get(rpsGameKey(roomCode));
        if (existing && !JSON.parse(existing).gameWinner) {
          const current = JSON.parse(existing);
          // 진행 중인 판: 요청자에게 현재 판을 다시 알려 화면이 이어지게 한다.
          socket.emit("game:rps:started", {
            mode: current.mode, players: current.players, scores: current.scores,
            phase: current.phase, attacker: current.attacker ?? null, resumed: true,
          });
          ack({ ok: true, resumed: true, mode: current.mode });
          return;
        }
        const game = {
          mode,
          players,
          scores: { [players[0]]: 0, [players[1]]: 0 },
          round: 1,
          picks: {},
          history: [],
          // mukjippa specific
          phase: mode === "mukjippa" ? "determine" : "play",
          attacker: null,
          gameWinner: null,
        };
        await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
        io.to(roomCode).emit("game:rps:started", { mode, players, scores: game.scores, phase: game.phase });
        ack({ ok: true });
      });
    });

    socket.on("game:rps:pick", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = rpsPickSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }

      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(rpsGameKey(roomCode));
        if (!raw) { ack({ ok: false, reason: "no_game" }); return; }
        const game = JSON.parse(raw);
        if (!game.players?.includes(userId)) { ack({ ok: false, reason: "not_a_player" }); return; }
        if (game.gameWinner) { ack({ ok: false, reason: "game_over" }); return; }
        if (game.picks[userId] !== undefined) { ack({ ok: true, waiting: true }); return; }

        // Record pick
        if (game.mode === "hanabagi") {
          const { fingers, guess } = parsed.data;
          if (fingers === undefined || guess === undefined) { ack({ ok: false, reason: "need_fingers_and_guess" }); return; }
          game.picks[userId] = { fingers, guess };
        } else {
          const { choice } = parsed.data;
          if (!choice) { ack({ ok: false, reason: "need_choice" }); return; }
          game.picks[userId] = choice;
        }

        const [p1, p2] = game.players;
        if (game.picks[p1] === undefined || game.picks[p2] === undefined) {
          await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
          ack({ ok: true, waiting: true });
          return;
        }

        // Both picked — resolve round
        let roundWinner = null; // userId or "draw"

      if (game.mode === "single") {
        const c1 = game.picks[p1], c2 = game.picks[p2];
        const rel = rpsWinner(c1, c2);
        roundWinner = rel === "draw" ? "draw" : rel === "p1" ? p1 : p2;
        if (roundWinner !== "draw") {
          game.scores[roundWinner] = (game.scores[roundWinner] || 0) + 1;
          game.gameWinner = roundWinner;
        }
        game.round++;
        const event = {
          mode: "single", round: game.round - 1,
          choices: { [p1]: c1, [p2]: c2 },
          roundWinner, scores: { ...game.scores }, gameWinner: game.gameWinner,
        };
        game.picks = {};
        await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
        io.to(roomCode).emit("game:rps:round_result", event);

      } else if (game.mode === "rps3") {
        const c1 = game.picks[p1], c2 = game.picks[p2];
        const rel = rpsWinner(c1, c2);
        roundWinner = rel === "draw" ? "draw" : rel === "p1" ? p1 : p2;
        if (roundWinner !== "draw") {
          game.scores[roundWinner] = (game.scores[roundWinner] || 0) + 1;
          if (game.scores[roundWinner] >= 3) game.gameWinner = roundWinner;
        }
        game.round++;
        const event = {
          mode: "rps3", round: game.round - 1,
          choices: { [p1]: c1, [p2]: c2 },
          roundWinner, scores: { ...game.scores }, gameWinner: game.gameWinner,
        };
        game.picks = {};
        await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
        io.to(roomCode).emit("game:rps:round_result", event);

      } else if (game.mode === "mukjippa") {
        const c1 = game.picks[p1], c2 = game.picks[p2];
        const rel = rpsWinner(c1, c2);
        const pickedWinner = rel === "draw" ? "draw" : rel === "p1" ? p1 : p2;

        if (game.phase === "determine") {
          if (pickedWinner === "draw") {
            // replay
            game.picks = {};
            await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
            io.to(roomCode).emit("game:rps:round_result", {
              mode: "mukjippa", phase: "determine",
              choices: { [p1]: c1, [p2]: c2 },
              roundWinner: "draw", attacker: null, gameWinner: null,
            });
          } else {
            game.attacker = pickedWinner;
            game.phase = "play";
            game.picks = {};
            await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
            io.to(roomCode).emit("game:rps:round_result", {
              mode: "mukjippa", phase: "determine",
              choices: { [p1]: c1, [p2]: c2 },
              roundWinner: pickedWinner, attacker: pickedWinner, gameWinner: null,
            });
          }
        } else {
          // mukjippa play phase
          if (c1 === c2) {
            // Same → attacker wins
            game.gameWinner = game.attacker;
            await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
            io.to(roomCode).emit("game:rps:round_result", {
              mode: "mukjippa", phase: "play",
              choices: { [p1]: c1, [p2]: c2 },
              roundWinner: "tie_attacker_wins", attacker: game.attacker,
              gameWinner: game.gameWinner,
            });
          } else {
            // Different → winner becomes new attacker
            const newAttacker = pickedWinner;
            game.attacker = newAttacker;
            game.picks = {};
            await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
            io.to(roomCode).emit("game:rps:round_result", {
              mode: "mukjippa", phase: "play",
              choices: { [p1]: c1, [p2]: c2 },
              roundWinner: newAttacker, attacker: newAttacker, gameWinner: null,
            });
          }
        }

      } else if (game.mode === "hanabagi") {
        const pick1 = game.picks[p1], pick2 = game.picks[p2];
        const result = resolveHanabagiRound(pick1, pick2);
        const total = result.total;
        if (result.roundWinner === 'p1') {
          roundWinner = p1;
          game.scores[p1] = (game.scores[p1] || 0) + 1;
        } else if (result.roundWinner === 'p2') {
          roundWinner = p2;
          game.scores[p2] = (game.scores[p2] || 0) + 1;
        } else {
          roundWinner = "draw";
        }
        if (roundWinner !== "draw" && game.scores[roundWinner] >= 3) {
          game.gameWinner = roundWinner;
        }
        const roundRecord = {
          round: game.round,
          fingers: { [p1]: pick1.fingers, [p2]: pick2.fingers },
          guesses: { [p1]: pick1.guess, [p2]: pick2.guess },
          total,
          roundWinner,
          scores: { ...game.scores },
        };
        game.history = [...(game.history || []), roundRecord];
        game.round++;
        const event = {
          mode: "hanabagi", round: game.round - 1,
          fingers: { [p1]: pick1.fingers, [p2]: pick2.fingers },
          guesses: { [p1]: pick1.guess, [p2]: pick2.guess },
          total, roundWinner, scores: { ...game.scores },
          history: game.history,
          gameWinner: game.gameWinner,
        };
        game.picks = {};
        await redis.set(rpsGameKey(roomCode), JSON.stringify(game), "EX", 600);
        io.to(roomCode).emit("game:rps:round_result", event);
      }

      // 승부가 났으면 결과·XP를 기록한다(이후 pick은 game_over로 거부되므로 한 번만).
      if (game.gameWinner) {
        await recordGameOutcome(roomCode, {
          winner: game.gameWinner,
          players: game.players,
          gameType: game.mode === "hanabagi" ? "zero" : "rps",
        });
      }

      ack({ ok: true });
      });
    });

    socket.on("game:rps:reset", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      await withRoomLock(roomCode, async () => {
        const rpsRaw = await redis.get(rpsGameKey(roomCode));
        if (rpsRaw) {
          // 방장 정의가 서버(User1)와 클라이언트(로비 방장)에서 달라 막히던 문제:
          // 참가자라면 누구나 리셋할 수 있다.
          const rpsGame = JSON.parse(rpsRaw);
          if (rpsGame.players && !rpsGame.players.includes(userId)) {
            ack({ ok: false, reason: 'not_a_player' });
            return;
          }
        }
        await redis.del(rpsGameKey(roomCode));
        io.to(roomCode).emit("game:rps:reset_done");
        ack({ ok: true });
      });
    });

    socket.on("game:telepathy:select", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = telepathySchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      await withRoomLock(roomCode, async () => {
        const { choice, options, sessionId } = parsed.data;
        if (!options.includes(choice)) {
          ack({ ok: false, reason: 'invalid_choice' });
          return;
        }
        const sessionKey = `telepathy:${roomCode}:session`;
        const existing = await redis.get(sessionKey);
        let session = existing ? JSON.parse(existing) : null;
        if (sessionId && session?.id !== sessionId) {
          return ack({ ok: false, reason: "stale_session" });
        }
        const sameOptions = session?.options?.length === options.length &&
          session.options.every((option, index) => option === options[index]);
        if (sessionId && !sameOptions) return ack({ ok: false, reason: "invalid_options" });
        // 상대가 이미 답한 진행 중 문제가 있는데 다른 문제로 답하면, 상대의 답을 버리지 않고
        // 거절한다(클라이언트는 상대가 풀고 있는 문제로 맞춰 다시 고른다).
        const partnerAnswered = session && !session.revealed && !session.expired &&
          Object.keys(session.choices ?? {}).some((uid) => uid !== userId);
        if (!sameOptions && partnerAnswered) {
          return ack({ ok: false, reason: "options_mismatch", options: session.options, sessionId: session.id });
        }
        if (!sameOptions) session = null;
        // Legacy clients do not carry a round id; their next selection starts
        // another question even if its options happen to be identical.
        if (session?.revealed && !sessionId) session = null;
        session ??= {
          id: randomUUID(), choices: {}, options, revealed: false,
          deadlineAt: Date.now() + TELEPATHY_RESPONSE_TIMEOUT_MS,
        };
        // Preserve pending choices created by the pre-deadline implementation.
        session.id ??= randomUUID();
        session.deadlineAt ??= (session.updatedAt ?? Date.now()) + TELEPATHY_RESPONSE_TIMEOUT_MS;
        if (session.revealed && session.result) {
          socket.emit("game:telepathy:result", session.result);
          return ack({ ok: true, result: session.result });
        }
        if (session.choices[userId] && session.choices[userId] !== choice) {
          return ack({ ok: false, reason: "already_selected" });
        }
        session.choices[userId] = choice;
        session.updatedAt = Date.now();

        if (Object.keys(session.choices).length === 2) {
          session.revealed = true;
          clearTelepathyTimer(roomCode);
          const event = await publishTelepathyResult(roomCode, session);
          ack({ ok: true, result: event });
        } else {
          await redis.set(sessionKey, JSON.stringify(session), "EX", TELEPATHY_SESSION_TTL_SEC);
          if (!session.expired) scheduleTelepathyExpiry(roomCode, session);
          ack({ ok: true, waiting: true, sessionId: session.id, deadlineAt: session.deadlineAt });
        }
      });
    });

    socket.on("game:pirate:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }

      const parsed = pirateStartSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

        const existing = await redis.get(pirateKey(roomCode));
        if (existing) {
          ack({ ok: false, reason: "game_in_progress" });
          return;
        }
        const { slots } = parsed.data;
        const players = await getOrderedPlayers(roomCode, presence);
        const bombSlot = Math.floor(Math.random() * slots);
        const gameState = {
          slots,
          bombSlot,
          pickedSlots: [],
          players,
          currentTurn: players[0],
          startedAt: Date.now(),
        };

        await redis.set(pirateKey(roomCode), JSON.stringify(gameState), "EX", 1800);
        io.to(roomCode).emit("game:pirate:started", {
          slots,
          players,
          currentTurn: players[0],
          pickedSlots: [],
          at: Date.now(),
        });
        ack({ ok: true });
      }); // withRoomLock
    });

    socket.on("game:pirate:pick", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = piratePickSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      await withRoomLock(roomCode, async () => {
        const gameText = await redis.get(pirateKey(roomCode));
        if (!gameText) {
          ack({ ok: false, reason: "no_game" });
          return;
        }

        const gameState = JSON.parse(gameText);
        if (gameState.currentTurn !== userId) {
          ack({ ok: false, reason: "not_your_turn" });
          return;
        }

        const { slot } = parsed.data;
        if (slot < 0 || slot >= gameState.slots) {
          ack({ ok: false, reason: "invalid_slot" });
          return;
        }
        if (gameState.pickedSlots.includes(slot)) {
          ack({ ok: false, reason: "slot_taken" });
          return;
        }

        if (slot === gameState.bombSlot) {
        await redis.del(pirateKey(roomCode));
        io.to(roomCode).emit("game:pirate:exploded", {
          loser: userId,
          bombSlot: slot,
          by: userId,
          at: Date.now(),
        });
        const pirateWinner = gameState.players.find(p => p !== userId);
        if (pirateWinner) {
          await saveGameResult(roomCode, pirateWinner, userId, 'pirate', 0).catch(() => {});
          grantGameXpAndMissions(pirateWinner, userId, 'pirate').catch(() => {});
        }
        ack({ ok: true, exploded: true });
        } else {
        gameState.pickedSlots.push(slot);
        const nextIdx = (gameState.players.indexOf(userId) + 1) % gameState.players.length;
        gameState.currentTurn = gameState.players[nextIdx];
        await redis.set(pirateKey(roomCode), JSON.stringify(gameState), "EX", 1800);
        io.to(roomCode).emit("game:pirate:slot_picked", {
          slot,
          by: userId,
          nextTurn: gameState.currentTurn,
          pickedSlots: gameState.pickedSlots,
          at: Date.now(),
        });
        ack({ ok: true, exploded: false });
        }
      });
    });

    socket.on("game:pirate:reset", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      await withRoomLock(roomCode, async () => {
        const pirateText = await redis.get(pirateKey(roomCode));
        const gameState = pirateText ? JSON.parse(pirateText) : null;
        if (gameState) {
          if (!gameState.players?.includes(userId)) {
            ack({ ok: false, reason: 'not_a_player' });
            return;
          }
        } else {
          // No active game: only room participants may clear
          const presence = getPresence(io, roomCode);
          if (!presence.includes(userId)) {
            ack({ ok: false, reason: 'not_in_room' });
            return;
          }
        }
        await redis.del(pirateKey(roomCode));
        io.to(roomCode).emit("game:pirate:reset_done", { by: userId, at: Date.now() });
        ack({ ok: true });
      });
    });

    socket.on("game:yut:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
        const presence = getPresence(io, roomCode);
        if (presence.length !== 2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }

        const existing = await redis.get(yutGameKey(roomCode));
        if (existing) {
          ack({ ok: false, reason: "game_in_progress" });
          return;
        }

        const [player1, player2] = await getOrderedPlayers(roomCode, presence);
        if (!player1 || !player2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }

        const parsed = yutNewSchema.safeParse(payload);
        if (!parsed.success) {
          ack({ ok: false, reason: "invalid_payload" });
          return;
        }
        const gameState = createYutGameState(player1, player2);
        const pendingYut = await consumePendingGame(roomCode, "yut");
        gameState.characters = parsed.data.characters ?? {};
        gameState.bgm = parsed.data.bgm ?? null;
        gameState.stake = pendingYut.stake; // payload의 stake는 무시한다.
        gameState.gameId = pendingYut.gameId;

        // 양 플레이어의 장착 아이템 정보 포함 (상대방 표시용)
        const { rows: p1Rows } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [player1]);
        const { rows: p2Rows } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [player2]);
        const [p1Info, p2Info, p1Stats, p2Stats] = await Promise.all([
          p1Rows[0]?.UserId ? getEquippedItemsInfo(p1Rows[0].UserId) : Promise.resolve({}),
          p2Rows[0]?.UserId ? getEquippedItemsInfo(p2Rows[0].UserId) : Promise.resolve({}),
          p1Rows[0]?.UserId ? getEquippedStats(p1Rows[0].UserId) : Promise.resolve({}),
          p2Rows[0]?.UserId ? getEquippedStats(p2Rows[0].UserId) : Promise.resolve({}),
        ]);
        gameState.equippedItems = { [player1]: p1Info, [player2]: p2Info };
        gameState.playerStats = { [player1]: p1Stats, [player2]: p2Stats };
        gameState.catchCoinBonus = {};
        gameState.winCoinBonus = {};

        await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

        emitYutState(io, roomCode, "game:yut:started", gameState);
        ack({ ok: true, gameState: serializeYutGame(gameState) });
      });
    });

    socket.on("game:yut:roll_start", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      let doCountdown = false;
      await withRoomLock(roomCode, async () => {
        const gameText = await redis.get(yutGameKey(roomCode));
        if (!gameText) {
          ack({ ok: false, reason: "no_game" });
          return;
        }

        const gameState = JSON.parse(gameText);
        if (gameState.phase !== "roll_order") {
          ack({ ok: false, reason: "invalid_phase" });
          return;
        }
        if (gameState.startRolls?.[userId] != null) {
          ack({ ok: false, reason: "already_rolled" });
          return;
        }

        gameState.startRolls = {
          ...(gameState.startRolls ?? {}),
          [userId]: Math.floor(Math.random() * 6) + 1,
        };

        const [player1, player2] = gameState.playersOrder;
        const p1Roll = gameState.startRolls[player1];
        const p2Roll = gameState.startRolls[player2];
        if (p1Roll != null && p2Roll != null) {
          if (p1Roll === p2Roll) {
            gameState.startRolls = {};
          } else {
            gameState.currentTurn = p1Roll > p2Roll ? player1 : player2;
            gameState.phase = "order_countdown";
            gameState.orderCountdownUntil = Date.now() + 3000;
          }
        }

        await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);
        emitYutState(io, roomCode, "game:yut:start_roll", gameState, { by: userId });
        ack({ ok: true, gameState: serializeYutGame(gameState) });
        if (gameState.phase === "order_countdown") doCountdown = true;
      });

      if (doCountdown) {
        setTimeout(async () => {
          try {
            await withRoomLock(roomCode, async () => {
              const latestText = await redis.get(yutGameKey(roomCode));
              if (!latestText) return;
              const latestState = JSON.parse(latestText);
              if (latestState.phase !== "order_countdown") return;
              latestState.phase = "throwing";
              latestState.orderCountdownUntil = null;
              await redis.set(yutGameKey(roomCode), JSON.stringify(latestState), "EX", 3600);
              emitYutState(io, roomCode, "game:yut:started", latestState, {
                orderReady: true,
              });
            });
          } catch (err) {
            console.error(`yut order countdown error: ${err.message}`);
          }
        }, 3000);
      }
    });

    socket.on("game:yut:throw", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
      const gameText = await redis.get(yutGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }

      const gameState = JSON.parse(gameText);
      if (gameState.currentTurn !== userId) {
        ack({ ok: false, reason: "not_your_turn" });
        return;
      }
      // Allow throw during moving phase only when bonus throw is available
      const canThrow = gameState.phase === "throwing" ||
        (gameState.phase === "moving" && gameState.hasBonusThrow);
      if (!canThrow) {
        ack({ ok: false, reason: "must_move_first" });
        return;
      }

      // Consume bonus throw if it was used
      if (gameState.hasBonusThrow) {
        gameState.hasBonusThrow = false;
      }

      // 게임 시작 시 캐시된 stats 재사용 (DB 재조회 불필요)
      const stats = gameState.playerStats?.[userId] ?? {};

      // 지고 있는지 판단 (상대보다 골인 말이 적으면 losing)
      const opponentCode = gameState.playersOrder.find((p) => p !== userId);
      const myFinished = gameState.players[userId]?.pieces.filter((p) => p.finished).length ?? 0;
      const oppFinished = opponentCode
        ? (gameState.players[opponentCode]?.pieces.filter((p) => p.finished).length ?? 0)
        : 0;
      const isLosing = myFinished < oppFinished;

      const throwResult = throwYut({
        yutControlPct: stats.yut_control_pct ?? 0,
        yutMoRatePct: stats.yut_mo_rate_pct ?? 0,
        yutOverturnPct: stats.yut_overturn_pct ?? 0,
        isLosing,
      });

      // yut_win_coin_pct: 윷(4)/모(5) 투척 시 스테이크 % 보너스 코인 누적
      if (throwResult.result === 4 || throwResult.result === 5) {
        const winCoinPct = Math.min(stats.yut_win_coin_pct ?? 0, 15);
        if (winCoinPct > 0 && (gameState.stake ?? 0) > 0) {
          const bonus = Math.floor(gameState.stake * winCoinPct / 100);
          gameState.winCoinBonus = gameState.winCoinBonus ?? {};
          gameState.winCoinBonus[userId] = (gameState.winCoinBonus[userId] ?? 0) + bonus;
          socket.emit("game:item_effect", { stat: "yut_win_coin_pct", amount: bonus });
        }
      }

      // 아직 둘 이동(윷/모 등)이 남아 있으면, 그 이동으로 말이 판에 올라온 뒤
      // 빽도를 쓸 수 있으므로 지금 낙 처리하지 않는다.
      const isNak = throwResult.result === -1 &&
        gameState.pendingMoves.length === 0 &&
        !gameState.hasBonusThrow &&
        !hasBackdoMove(gameState.players[userId].pieces);
      throwResult.nak = isNak;
      recordYutThrow(gameState, throwResult);

      if (!isNak) {
        gameState.pendingMoves.push(throwResult.result);
      }

      // New 윷/모 grants another bonus throw
      if (throwResult.bonusThrow) {
        gameState.hasBonusThrow = true;
      }

      if (isNak && gameState.pendingMoves.length === 0) {
        gameState.hasBonusThrow = false;
        gameState.caughtOpponentThisTurn = false;
        gameState.captureBonusThrows = 0;
        gameState.currentTurn = getNextYutPlayer(gameState, userId);
        gameState.phase = "throwing";
        resetYutTurnThrows(gameState);
      } else {
        gameState.phase = "moving";
      }

      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      emitYutState(io, roomCode, "game:yut:throw_result", gameState, {
        by: userId,
        throwResult,
        at: Date.now(),
      });
      ack({ ok: true, throwResult, gameState: serializeYutGame(gameState) });
      }); // withRoomLock
    });

    socket.on("game:yut:move", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = yutMoveSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      await withRoomLock(roomCode, async () => {
      const gameText = await redis.get(yutGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }

      const gameState = JSON.parse(gameText);
      const { pieceId, moveIndex, backdoDir } = parsed.data;
      const moverStats = gameState.playerStats?.[userId] ?? {};
      const opponentId = getNextYutPlayer(gameState, userId);
      const defenderStats = gameState.playerStats?.[opponentId] ?? {};
      const moveResolution = resolveYutMove(gameState, userId, {
        pieceId,
        moveIndex,
        backdoDir,
        moverStats,
        defenderStats,
      });
      if (!moveResolution.ok) {
        ack({ ok: false, reason: moveResolution.reason });
        return;
      }

      const {
        piece,
        steps,
        preMovePos,
        carriedPieces,
        stackedPieces,
        capturedPieces,
        captureBlockedPieces,
      } = moveResolution;

      // A protected piece is intentionally left on the landing square. The
      // count is included in move_result so a failed capture is not ambiguous.
      // piece_catch_resist_pct + piece_safe_zone_pct are applied in the engine.

      // piece_catch_coin_bonus: 잡은 말 1개당 플랫 코인 (최대 25)
      const catchCoinPer = Math.min(Math.floor(moverStats.piece_catch_coin_bonus ?? 0), 25);
      if (catchCoinPer > 0 && capturedPieces.length > 0) {
        gameState.catchCoinBonus = gameState.catchCoinBonus ?? {};
        gameState.catchCoinBonus[userId] = (gameState.catchCoinBonus[userId] ?? 0) + catchCoinPer * capturedPieces.length;
        socket.emit("game:item_effect", { stat: "piece_catch_coin_bonus", amount: catchCoinPer * capturedPieces.length });
      }

      // yut_catch_bonus: 잡기 이벤트당 플랫 코인, 잡은 말 수 무관 (최대 300)
      const catchFlatBonus = Math.min(Math.floor(moverStats.yut_catch_bonus ?? 0), 300);
      if (catchFlatBonus > 0 && capturedPieces.length > 0) {
        gameState.catchCoinBonus = gameState.catchCoinBonus ?? {};
        gameState.catchCoinBonus[userId] = (gameState.catchCoinBonus[userId] ?? 0) + catchFlatBonus;
        socket.emit("game:item_effect", { stat: "yut_catch_bonus", amount: catchFlatBonus });
      }

      // yut_backdo_bonus_pct: 유리한 백도 위치에서 추가 던지기 확률
      // - 날백도 (위치 1→골인): 스탯값 ×2 확률 (최대 50%)
      // - 대각선 백도 (위치 23→22/25): 스탯값 % 확률 (최대 25%)
      if (steps === -1) {
        const backdoBonus = Math.min(moverStats.yut_backdo_bonus_pct ?? 0, 25);
        if (backdoBonus > 0) {
          let triggerPct = 0;
          if (preMovePos === 1) triggerPct = Math.min(backdoBonus * 2, 50); // 날백도
          else if (preMovePos === 23) triggerPct = backdoBonus;              // 대각선
          if (triggerPct > 0 && Math.random() * 100 < triggerPct) {
            gameState.hasBonusThrow = true;
            socket.emit("game:item_effect", { stat: "yut_backdo_bonus_pct", amount: 0 });
          }
        }
      }

      const won = checkWin(gameState.players[userId]);
      // 남은 결과가 빽도뿐인데 판 위에 말이 없으면 쓸 수 없으므로 버린다(소프트락 방지).
      const discardedBackdo = won ? 0 : pruneUnusableBackdo(gameState, userId);
      if (won) {
        gameState.winner = userId;
      } else {
        settleTurnAfterMove(gameState, userId);
        if (gameState.currentTurn !== userId) {
          resetYutTurnThrows(gameState);
        }
      }

      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        pieceId,
        newPosition: piece.position,
        finished: piece.finished,
        discardedBackdo,
        movedPieceIds: carriedPieces.map((carriedPiece) => carriedPiece.id),
        capturedPieceIds: capturedPieces.map((capturedPiece) => capturedPiece.id),
        capturedCount: capturedPieces.length,
        captureBlockedCount: captureBlockedPieces.length,
        carriedCount: carriedPieces.length,
        stackedCount: stackedPieces.length,
        winner: gameState.winner,
        at: Date.now(),
        ...serializeYutGame(gameState),
      };

      io.to(roomCode).emit("game:yut:move_result", event);
      if (captureBlockedPieces.length > 0) {
        // A defensive item affects both players' understanding of the move.
        // Broadcast the effect instead of notifying only the defender so both
        // clients can show why the landing piece was not reset.
        io.to(roomCode).emit("game:item_effect", {
          stat: "yut_capture_protection",
          amount: captureBlockedPieces.length,
          at: event.at,
        });
      }
      ack({ ok: true, event });

      if (gameState.winner) {
        const yutLoserId = gameState.playersOrder.find(p => p !== gameState.winner);
        io.to(roomCode).emit("game:yut:ended", { winner: gameState.winner });
        const [{ rows: winnerRows }, { rows: loserRows }] = await Promise.all([
          query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [gameState.winner]),
          query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [yutLoserId]),
        ]);
        const winnerExtraBonus = (gameState.catchCoinBonus?.[gameState.winner] ?? 0)
          + (gameState.winCoinBonus?.[gameState.winner] ?? 0);
        const yutPreStreak = await _getWinStreak(roomCode, gameState.winner);
        // 정산 → 결과 기록 → 상태 삭제. ref가 판마다 고정이라 재처리돼도 한 번만 정산된다.
        const yutGameId = gameState.gameId ?? gameState.id;
        const yutWallet = await settleAndEmitWallet(io, roomCode, gameState.winner, yutLoserId, gameState.stake ?? 0, `yut:${yutGameId}`, winnerRows[0]?.UserId, winnerExtraBonus, loserRows[0]?.UserId, yutPreStreak);
        if (!yutWallet.ok) io.to(roomCode).emit("wallet:settle_failed", { gameType: "yut", reason: yutWallet.reason });
        await Promise.all([
          saveGameResult(roomCode, gameState.winner, yutLoserId, 'yut', gameState.stake ?? 0, { gameId: yutGameId }),
          grantGameXpAndMissions(gameState.winner, yutLoserId, 'yut'),
        ]);
        await redis.del(yutGameKey(roomCode));
      }
      }); // withRoomLock
    });

    // ─── 마블 게임 핸들러 ────────────────────────────────────────────────────────

    // 마블 판 생성(신규·재시작 공용). 캐릭터는 참가자·허용 목록으로 걸러 신뢰하지 않는다.
    const startMarbleGame = async (roomCode, player1, player2, rawCharacters) => {
      const characters = Object.fromEntries(
        Object.entries(rawCharacters && typeof rawCharacters === "object" ? rawCharacters : {})
          .filter(([player, character]) => [player1, player2].includes(player) && marbleCharacterIds.includes(character)),
      );
      const gameState = createMarbleGameState(player1, player2, { characters });
      const { rows: p1Rows } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [player1]);
      const { rows: p2Rows } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [player2]);
      const [p1Info, p2Info] = await Promise.all([
        p1Rows[0]?.UserId ? getEquippedItemsInfo(p1Rows[0].UserId) : Promise.resolve({}),
        p2Rows[0]?.UserId ? getEquippedItemsInfo(p2Rows[0].UserId) : Promise.resolve({}),
      ]);
      gameState.equippedItems = { [player1]: p1Info, [player2]: p2Info };
      await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
      emitMarbleState(io, roomCode, "game:marble:state", gameState);
      return gameState;
    };

    socket.on("game:marble:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
        const presence = getPresence(io, roomCode);
        if (presence.length !== 2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }

        const existing = await redis.get(marbleGameKey(roomCode));
        if (existing) {
          ack({ ok: false, reason: "game_in_progress" });
          return;
        }

        const [player1, player2] = await getOrderedPlayers(roomCode, presence);
        if (!player1 || !player2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }

        const gameState = await startMarbleGame(roomCode, player1, player2, payload?.characters);
        ack({ ok: true, gameState: serializeMarbleGame(gameState) });
      });
    });

    socket.on("game:marble:roll_start", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
        const gameText = await redis.get(marbleGameKey(roomCode));
        if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }
        const gameState = JSON.parse(gameText);
        if (gameState.phase !== "roll_order") { ack({ ok: false, reason: "invalid_phase" }); return; }
        if (!gameState.playersOrder?.includes(userId)) { ack({ ok: false, reason: "not_a_player" }); return; }
        if (gameState.startRolls?.[userId] != null) { ack({ ok: false, reason: "already_rolled" }); return; }

        gameState.startRolls = { ...(gameState.startRolls ?? {}), [userId]: Math.floor(Math.random() * 6) + 1 };

        const [player1, player2] = gameState.playersOrder;
        const p1Roll = gameState.startRolls[player1];
        const p2Roll = gameState.startRolls[player2];
        if (p1Roll != null && p2Roll != null) {
          if (p1Roll === p2Roll) {
            gameState.startRolls = {};
          } else {
            gameState.currentTurn = p1Roll > p2Roll ? player1 : player2;
            gameState.phase = "order_countdown";
            gameState.orderCountdownUntil = Date.now() + 3000;
          }
        }

        await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
        emitMarbleState(io, roomCode, "game:marble:state", gameState, { by: userId });
        ack({ ok: true, gameState: serializeMarbleGame(gameState) });

        if (gameState.phase === "order_countdown") {
          setTimeout(async () => {
            try {
              await withRoomLock(roomCode, async () => {
                const latestText = await redis.get(marbleGameKey(roomCode));
                if (!latestText) return;
                const latestState = JSON.parse(latestText);
                if (latestState.id !== gameState.id || latestState.phase !== "order_countdown") return;
                latestState.phase = "throwing";
                latestState.orderCountdownUntil = null;
                await redis.set(marbleGameKey(roomCode), JSON.stringify(latestState), "EX", 7200);
                emitMarbleState(io, roomCode, "game:marble:state", latestState, { orderReady: true });
              });
            } catch (err) {
              console.error(`marble order countdown error: ${err.message}`);
            }
          }, 3000);
        }
      });
    });

    socket.on("game:marble:roll", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }

      await withRoomLock(roomCode, async () => {
      const gameText = await redis.get(marbleGameKey(roomCode));
      if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }
      const gameState = JSON.parse(gameText);
      if (gameState.currentTurn !== userId) { ack({ ok: false, reason: "not_your_turn" }); return; }
      if (gameState.phase !== "throwing") { ack({ ok: false, reason: "must_move_first" }); return; }
      if (gameState.pendingLandAction) { ack({ ok: false, reason: "land_action_pending" }); return; }

      const rollResult = rollMarbleDice();
      gameState.lastRoll = rollResult;

      // 블랙사이트 감금: 더블이면 탈출해 그대로 이동, 아니면 이번 턴은 쉬고 넘긴다.
      if ((gameState.jailTurns?.[userId] ?? 0) > 0) {
        gameState.jailTurns[userId] -= 1;
        if (!rollResult.isDouble) {
          gameState.consecutiveDoubles = 0;
          gameState.hasDoubleRoll = false;
          gameState.pendingMoves = [];
          advanceMarbleRound(gameState);
          gameState.currentTurn = getNextMarblePlayer(gameState, userId);
          gameState.phase = "throwing";
          await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
          emitMarbleState(io, roomCode, "game:marble:roll_result", gameState, {
            by: userId, rollResult, jailed: true, at: Date.now(),
          });
          ack({ ok: true, rollResult, jailed: true, gameState: serializeMarbleGame(gameState) });
          return;
        }
        gameState.jailTurns[userId] = 0; // 더블 탈출 — 탈출 굴림은 추가 굴림을 주지 않는다.
        gameState.consecutiveDoubles = 0;
        gameState.hasDoubleRoll = false;
        gameState.pendingMoves.push(rollResult.total);
        gameState.phase = "moving";
        await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
        emitMarbleState(io, roomCode, "game:marble:roll_result", gameState, {
          by: userId, rollResult, jailEscape: true, at: Date.now(),
        });
        ack({ ok: true, rollResult, jailEscape: true, gameState: serializeMarbleGame(gameState) });
        return;
      }

      // 더블: 한 번 더 굴릴 수 있음 (연속 3번 더블이면 턴 넘김)
      if (rollResult.isDouble) {
        gameState.consecutiveDoubles = (gameState.consecutiveDoubles ?? 0) + 1;
        if (gameState.consecutiveDoubles >= 3) {
          // 3연속 더블: 턴 넘김 패널티
          gameState.consecutiveDoubles = 0;
          gameState.hasDoubleRoll = false;
          gameState.pendingMoves = [];
          advanceMarbleRound(gameState); // 3연속 더블로 턴을 넘겨도 라운드는 진행된다.
          gameState.currentTurn = getNextMarblePlayer(gameState, userId);
          gameState.phase = "throwing";
          await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
          emitMarbleState(io, roomCode, "game:marble:roll_result", gameState, {
            by: userId, rollResult, tripleDouble: true, at: Date.now(),
          });
          ack({ ok: true, rollResult, gameState: serializeMarbleGame(gameState) });
          return;
        }
        gameState.hasDoubleRoll = true;
      } else {
        gameState.consecutiveDoubles = 0;
        gameState.hasDoubleRoll = false;
      }

      gameState.pendingMoves.push(rollResult.total);
      gameState.phase = "moving";

      await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
      emitMarbleState(io, roomCode, "game:marble:roll_result", gameState, {
        by: userId, rollResult, at: Date.now(),
      });
      ack({ ok: true, rollResult, gameState: serializeMarbleGame(gameState) });
      }); // withRoomLock
    });

    socket.on("game:marble:move", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
      const gameText = await redis.get(marbleGameKey(roomCode));
      if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }
      const gameState = JSON.parse(gameText);
      if (gameState.currentTurn !== userId) { ack({ ok: false, reason: "not_your_turn" }); return; }
      if (gameState.phase !== "moving") { ack({ ok: false, reason: "no_pending_moves" }); return; }
      if (gameState.pendingLandAction) { ack({ ok: false, reason: "land_action_pending" }); return; }
      if (!Array.isArray(gameState.pendingMoves) || gameState.pendingMoves.length === 0) {
        ack({ ok: false, reason: "no_pending_moves" });
        return;
      }

      const pieceId = Number(payload?.pieceId ?? 0);
      const moveIndex = Number(payload?.moveIndex ?? 0);
      if (!Number.isInteger(pieceId) || !Number.isInteger(moveIndex) || moveIndex < 0 ||
          moveIndex >= gameState.pendingMoves.length) {
        ack({ ok: false, reason: "invalid_move" });
        return;
      }

      const piece = gameState.players[userId]?.pieces?.[pieceId];
      if (!piece) { ack({ ok: false, reason: "invalid_piece" }); return; }

      const steps = gameState.pendingMoves[moveIndex];
      const moveResult = moveMarblePiece(piece, steps);
      if (moveResult === null) { ack({ ok: false, reason: "invalid_move" }); return; }

      piece.lastPos = moveResult.lastPos;
      piece.position = moveResult.position;
      piece.finished = false;
      gameState.pendingMoves.splice(moveIndex, 1);

      const opponentId = getNextMarblePlayer(gameState, userId);
      // equippedItems는 슬롯별 { stats } 맵이다. 슬롯 합계로 스탯을 구한다.
      const defenderTollReducePct = sumEquippedStat(gameState.equippedItems?.[opponentId], "land_toll_reduce_pct");

      // 출발지를 통과하면 급여를 지급한다.
      const passedStart = moveResult.passedStart === true;
      if (passedStart) {
        gameState.players[userId].coins += MARBLE_SALARY;
      }

      const hadExtraRoll = gameState.hasDoubleRoll === true;
      if (gameState.pendingMoves.length === 0 && !hadExtraRoll) {
        advanceMarbleRound(gameState);
      }

      // 승리 체크
      const winResult = checkMarbleWin(gameState);
      let finalScores = null;  // H6: 서든데스 점수를 별도로 전달, Redis에는 저장하지 않음
      if (winResult) {
        gameState.winner = winResult.winner;
        gameState.winReason = winResult.reason;
      } else if (gameState.round > MARBLE_MAX_ROUNDS) {
        // C3/H6: 타임아웃 승리 — coins를 덮어쓰지 말고 finalScores로 분리
        const p1 = gameState.playersOrder[0];
        const p2 = gameState.playersOrder[1];
        const s1 = calcScore(gameState, p1);
        const s2 = calcScore(gameState, p2);
        finalScores = { [p1]: s1, [p2]: s2 };

        if (s1 === s2) {
          gameState.winner = null;  // draw: ended 이벤트 발송 대상이므로 winReason으로 식별
          gameState.winReason = 'timeout_draw';
        } else {
          gameState.winner = s1 > s2 ? p1 : p2;
          gameState.winReason = 'timeout';
        }
      } else {
        settleMarbleTurn(gameState, userId);
      }

      await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);

      const targetPos = moveResult.position;
      const landData = gameState.lands[targetPos];
      let landPrompt = null;

      let specialEvent = null;
      const specialType = getMarbleSpecialType(targetPos);
      // timeout_draw는 winner가 null이므로 winner만 보면 종료 후에도 칸 효과가 처리된다.
      const marbleOver = () => gameState.winner != null || gameState.winReason === 'timeout_draw';

      if (!marbleOver() && specialType === 'jail') {
        // 블랙사이트: 다음 자기 턴 1회를 쉰다(더블이 나오면 탈출).
        gameState.jailTurns = { ...(gameState.jailTurns ?? {}), [userId]: 1 };
        specialEvent = { type: 'jail', turns: 1 };
        io.to(roomCode).emit("game:marble:special_tile", specialEvent);
      } else if (!marbleOver() && specialType === 'gate') {
        // 비밀게이트: 무작위 도시로 순간이동(도착 칸 효과 없음).
        const destination = pickGateDestination();
        piece.lastPos = piece.position;
        piece.position = destination;
        specialEvent = { type: 'gate', to: destination };
        io.to(roomCode).emit("game:marble:special_tile", specialEvent);
      } else if (!marbleOver() && specialType === 'tax') {
        // 세금을 못 내면 잔액이 음수가 되어 파산한다(정확히 0이면 생존).
        const taxAmount = SPECIAL_FEE;
        gameState.players[userId].coins = gameState.players[userId].coins - taxAmount;
        await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
        specialEvent = { type: 'tax', amount: taxAmount, coins: { [userId]: gameState.players[userId].coins } };
        io.to(roomCode).emit("game:marble:special_tile", specialEvent);
      } else if (!marbleOver() && specialType === 'card') {
        // 황금열쇠 카드: 랜덤 효과
        const cards = [
          { id: 'bonus_coin',  text: '행운의 여신이 미소 지었다! +30만 MM',  amount:  300_000 },
          { id: 'bonus_coin2', text: '보물 상자를 발견했다! +15만 MM',       amount:  150_000 },
          { id: 'penalty',     text: '통행세 폭탄! -20만 MM',                 amount: -200_000 },
          { id: 'teleport',    text: '신비한 바람에 날렸다! 출발 칸으로 이동', amount:    0, move: 0 },
          { id: 'salary',      text: '특별 보너스! 급여 두 배 +40만 MM',       amount:  400_000 },
        ];
        const card = cards[Math.floor(Math.random() * cards.length)];
        gameState.players[userId].coins = gameState.players[userId].coins + card.amount;
        if (card.move !== undefined) {
          gameState.players[userId].pieces.forEach((p) => {
            if (p.id === pieceId) { p.lastPos = p.position; p.position = card.move; }
          });
        }
        await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
        specialEvent = { type: 'card', card, coins: { [userId]: gameState.players[userId].coins } };
        io.to(roomCode).emit("game:marble:special_tile", specialEvent);
      }

      const specialWin = !marbleOver() && checkMarbleWin(gameState);
      if (specialWin) {
        gameState.winner = specialWin.winner;
        gameState.winReason = specialWin.reason;
      }

      // 게이트로 이동했으면 도착 칸 효과는 없다.
      if (!marbleOver() && specialType !== 'gate' && !MARBLE_START_POSITIONS.has(targetPos) && getLandValue(targetPos) > 0) {
        if (!landData) {
          // 빈 칸: 점령 프롬프트
          landPrompt = { type: 'claim', pos: targetPos, cost: calcPurchaseCost(targetPos) };
        } else if (landData.owner === userId && landData.level < 4 && calcUpgradeCost(targetPos, landData.level) > 0) {
          // 내 영지 재방문: 강화 프롬프트
          const upgradeCost = calcUpgradeCost(targetPos, landData.level);
          landPrompt = { type: 'upgrade', pos: targetPos, cost: upgradeCost, level: landData.level };
        } else if (landData.owner !== userId) {
          // 상대 영지: 통행료 자동 징수
          // M4: 방어자의 통행료 감소 스탯 적용
          const rawToll = calcToll(targetPos, landData.level) *
            (hasColorMonopoly(gameState, opponentId, targetPos) ? 2 : 1);
          const tollReducePct = Math.min(defenderTollReducePct, 30);
          const toll = tollReducePct > 0
            ? Math.max(1, Math.floor(rawToll * (1 - tollReducePct / 100)))
            : rawToll;
          // 받는 쪽은 실제로 낼 수 있는 만큼만 받고, 다 못 내면 잔액이 음수가 되어 파산한다.
          const paidToll = Math.min(Math.max(0, gameState.players[userId].coins), toll);
          gameState.players[userId].coins -= toll;
          gameState.players[opponentId].coins += paidToll;
          await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
          io.to(roomCode).emit("game:marble:toll_paid", {
            payer: userId,
            receiver: opponentId,
            pos: targetPos,
            toll: paidToll,
            level: landData.level,
            coins: { [userId]: gameState.players[userId].coins, [opponentId]: gameState.players[opponentId].coins },
          });
          // 파산 체크
          const tollWin = checkMarbleWin(gameState);
          if (tollWin) {
            gameState.winner = tollWin.winner;
            gameState.winReason = tollWin.reason;
            await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);
          } else if (landData.level < 4 && calcAcquireCost(targetPos, landData.level) > 0) {
            // 인수 프롬프트
            const acquireCost = calcAcquireCost(targetPos, landData.level);
            landPrompt = { type: 'acquire', pos: targetPos, cost: acquireCost, level: landData.level };
          }
        }
      }

      gameState.pendingLandAction = landPrompt
        ? {
            userId,
            pos: targetPos,
            type: landPrompt.type,
            cost: landPrompt.cost,
            level: landPrompt.level,
          }
        : null;
      await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);

      const moveEvent = {
        by: userId,
        pieceId,
        newPosition: piece.position,
        movedPieceIds: [piece.id],
        passedStart,
        landPrompt,
        specialEvent,
        winner: gameState.winner,
        winReason: gameState.winReason,
        // H6: 서든데스 점수는 별도 필드로 전달 (Redis coins를 오염시키지 않음)
        finalScores,
        at: Date.now(),
        ...serializeMarbleGame(gameState),
      };

      io.to(roomCode).emit("game:marble:move_result", moveEvent);
      if (landPrompt) {
        // 이동한 플레이어에게만 프롬프트 전송
        socket.emit("game:marble:land_prompt", landPrompt);
      }
      ack({ ok: true, event: moveEvent });

      // C3: timeout_draw(winner=null)인 경우도 ended 이벤트 발송
      const isGameOver = gameState.winner !== null || gameState.winReason === 'timeout_draw';
      if (isGameOver) {
        const endedPayload = {
          winner: gameState.winner,
          winReason: gameState.winReason,
          finalScores,
        };
        io.to(roomCode).emit("game:marble:ended", endedPayload);
        await redis.del(marbleGameKey(roomCode));
        await recordGameOutcome(roomCode, {
          winner: gameState.winner,
          players: gameState.playersOrder,
          gameType: 'marble',
        });
      }
      }); // withRoomLock
    });

    socket.on("game:marble:land_act", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
      const gameText = await redis.get(marbleGameKey(roomCode));
      if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }
      const gameState = JSON.parse(gameText);

      const { action, pos } = payload ?? {};
      if (!['claim', 'upgrade', 'acquire', 'skip'].includes(action) || pos == null) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const posNum = Number(pos);
      if (!Number.isInteger(posNum) || posNum < 0 || posNum >= 24) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }
      const pendingAction = gameState.pendingLandAction;
      if (!pendingAction || pendingAction.userId !== userId || pendingAction.pos !== posNum) {
        ack({ ok: false, reason: "no_pending_land_action" });
        return;
      }
      if (action !== 'skip' && action !== pendingAction.type) {
        ack({ ok: false, reason: "invalid_land_action" });
        return;
      }
      const playerState = gameState.players[userId];
      if (!playerState) { ack({ ok: false, reason: "invalid_player" }); return; }

      if (action === 'claim') {
        const cost = calcPurchaseCost(posNum);
        if (cost <= 0) { ack({ ok: false, reason: "invalid_land" }); return; }
        if (playerState.coins < cost) { ack({ ok: false, reason: "insufficient_coins" }); return; }
        if (gameState.lands[posNum]) { ack({ ok: false, reason: "already_claimed" }); return; }
        playerState.coins -= cost;
        gameState.lands[posNum] = { owner: userId, level: 1 };
      } else if (action === 'upgrade') {
        const land = gameState.lands[posNum];
        if (!land || land.owner !== userId) { ack({ ok: false, reason: "not_your_land" }); return; }
        if (land.level >= 4) { ack({ ok: false, reason: "max_level" }); return; }
        const upgradeCost = calcUpgradeCost(posNum, land.level);
        if (playerState.coins < upgradeCost) { ack({ ok: false, reason: "insufficient_coins" }); return; }
        playerState.coins -= upgradeCost;
        land.level += 1;
      } else if (action === 'acquire') {
        const land = gameState.lands[posNum];
        if (!land || land.owner === userId) { ack({ ok: false, reason: "invalid_acquire" }); return; }
        if (land.level >= 4) { ack({ ok: false, reason: "max_level" }); return; }
        const cost = calcAcquireCost(posNum, land.level);
        if (cost <= 0) { ack({ ok: false, reason: "invalid_acquire" }); return; }
        if (playerState.coins < cost) { ack({ ok: false, reason: "insufficient_coins" }); return; }
        const prevOwnerId = land.owner;
        playerState.coins -= cost;
        gameState.players[prevOwnerId].coins += cost;
        land.owner = userId;
      }
      gameState.pendingLandAction = null;

      // 승리 조건 재체크 (bankrupt 포함 — checkMarbleWin이 모두 체크)
      const winResult = checkMarbleWin(gameState);
      if (winResult) {
        gameState.winner = winResult.winner;
        gameState.winReason = winResult.reason;
      }

      await redis.set(marbleGameKey(roomCode), JSON.stringify(gameState), "EX", 7200);

      emitMarbleState(io, roomCode, "game:marble:state", gameState, {
        landAction: { action, pos: posNum, by: userId },
      });
      ack({ ok: true, gameState: serializeMarbleGame(gameState) });

      if (gameState.winner) {
        io.to(roomCode).emit("game:marble:ended", {
          winner: gameState.winner,
          winReason: gameState.winReason,
          finalScores: null,
        });
        await redis.del(marbleGameKey(roomCode));
        const landActOpponentId = getNextMarblePlayer(gameState, userId);
        await saveGameResult(roomCode, gameState.winner, landActOpponentId, 'marble', 0).catch(() => {});
        await grantGameXpAndMissions(gameState.winner, landActOpponentId, 'marble').catch(() => {});
      }
      }); // withRoomLock
    });

    socket.on("game:yut:chat", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = chatMessageSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_message" });
        return;
      }

      const gameText = await redis.get(yutGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }
      const gameState = JSON.parse(gameText);
      if (!gameState.playersOrder?.includes(userId)) {
        ack({ ok: false, reason: "not_a_player" });
        return;
      }

      const event = {
        by: userId,
        message: parsed.data.message,
        at: Date.now(),
      };
      io.to(roomCode).emit("game:yut:chat", event);
      ack({ ok: true, event });
    });

    socket.on("game:marble:chat", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }

      const parsed = chatMessageSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_message" }); return; }

      const gameText = await redis.get(marbleGameKey(roomCode));
      if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }
      const gameState = JSON.parse(gameText);
      if (!gameState.playersOrder?.includes(userId)) { ack({ ok: false, reason: "not_a_player" }); return; }

      const event = { by: userId, message: parsed.data.message, at: Date.now() };
      io.to(roomCode).emit("game:marble:chat", event);
      ack({ ok: true, event });
    });

    socket.on("game:blackjack:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      await withRoomLock(roomCode, async () => {
        const presence = getPresence(io, roomCode);
        if (presence.length !== 2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }
        const orderedPlayers = await getOrderedPlayers(roomCode, presence);
        if (orderedPlayers.length !== 2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }
        const existing = await redis.get(`game:${roomCode}:blackjack`);
        if (existing && JSON.parse(existing).status !== 'finished') {
          // 이탈 후 다시 들어온 경우: 거절하지 않고 진행 중인 판을 이어서 보여준다.
          socket.emit("game:blackjack:updated", serializeBlackjackFor(JSON.parse(existing), userId));
          ack({ ok: true, resumed: true });
          return;
        }
        const gameState = initBlackjackGame(orderedPlayers[0], orderedPlayers[1]);
        await redis.set(`game:${roomCode}:blackjack`, JSON.stringify(gameState), "EX", 3600);
        await emitBlackjackState(io, roomCode, gameState);
        ack({ ok: true });
      });
    });

    const runBlackjackAction = async (userId, roomCode, action, ack) => {
      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(`game:${roomCode}:blackjack`);
        if (!raw) {
          ack({ ok: false, reason: "no_game" });
          return;
        }
        const previousState = JSON.parse(raw);
        const gameState = action(previousState, String(userId));
        if (gameState === previousState) {
          ack({ ok: false, reason: "invalid_action" });
          return;
        }
        await redis.set(`game:${roomCode}:blackjack`, JSON.stringify(gameState), "EX", 3600);
        await emitBlackjackState(io, roomCode, gameState);
        if (previousState.status !== 'finished' && gameState.status === 'finished') {
          const winner = gameState.result?.winner;
          await recordGameOutcome(roomCode, {
            winner: winner && winner !== 'tie' ? winner : null,
            players: gameState.players,
            gameType: 'blackjack',
          });
        }
        ack({ ok: true });
      });
    };

    socket.on("game:blackjack:hit", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      return runBlackjackAction(userId, roomCode, hitBlackjack, ack);
    });

    socket.on("game:blackjack:stand", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      return runBlackjackAction(userId, roomCode, standBlackjack, ack);
    });

    socket.on("game:blackjack:next_round", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      return runBlackjackAction(userId, roomCode, nextBlackjackRound, ack);
    });

    socket.on("game:oldmaid:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      await withRoomLock(roomCode, async () => {
        const presence = getPresence(io, roomCode);
        if (presence.length !== 2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }
        const orderedPlayers = await getOrderedPlayers(roomCode, presence);
        if (orderedPlayers.length !== 2) {
          ack({ ok: false, reason: "need_two_players" });
          return;
        }
        const existing = await redis.get(`game:${roomCode}:oldmaid`);
        const existingState = existing ? JSON.parse(existing) : null;
        const { game: gameState, resumed } = startOldMaidGame(
          existingState,
          orderedPlayers[0],
          orderedPlayers[1],
        );
        await redis.set(`game:${roomCode}:oldmaid`, JSON.stringify(gameState), "EX", 3600);
        await emitOldMaidState(io, roomCode, gameState);
        ack({ ok: true, resumed });
      });
    });

    socket.on("game:oldmaid:draw", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      const cardId = payload?.cardId;
      if (!cardId) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }
      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(`game:${roomCode}:oldmaid`);
        if (!raw) {
          ack({ ok: false, reason: "no_game" });
          return;
        }
        const previousState = JSON.parse(raw);
        if (!previousState.players?.[String(userId)]) {
          ack({ ok: false, reason: "not_a_player" });
          return;
        }
        // 위치 별칭(slot-N)을 상대 손패의 실제 카드 id로 바꾼다.
        let targetCardId = String(cardId);
        const slotMatch = /^slot-(\d+)$/.exec(targetCardId);
        if (slotMatch) {
          const opponentId = Object.keys(previousState.players).find((id) => id !== String(userId));
          targetCardId = previousState.players[opponentId]?.hand?.[Number(slotMatch[1])]?.id ?? "";
        }
        const gameState = drawOldMaidCard(previousState, String(userId), targetCardId);
        if (gameState === previousState) {
          ack({ ok: false, reason: "invalid_action" });
          return;
        }
        await redis.set(`game:${roomCode}:oldmaid`, JSON.stringify(gameState), "EX", 3600);
        await emitOldMaidState(io, roomCode, gameState);
        if (previousState.status !== 'finished' && gameState.status === 'finished' && gameState.result?.winner) {
          await recordGameOutcome(roomCode, {
            winner: gameState.result.winner,
            players: [gameState.result.winner, gameState.result.loser],
            gameType: 'oldmaid',
          });
        }
        ack({ ok: true });
      });
    });

    // ── Penalty Shootout ──────────────────────────────────────────────────
    socket.on("game:penalty:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      await withRoomLock(roomCode, async () => {
      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });
      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });
      const existing = await redis.get(`game:${roomCode}:penalty`);
      if (existing && JSON.parse(existing).status === 'playing') {
        socket.emit("game:penalty:updated", maskPenaltyState(JSON.parse(existing)));
        return ack({ ok: true, resumed: true });
      }

      const gameState = initPenaltyGame(orderedPlayers[0], orderedPlayers[1]);
      await redis.set(`game:${roomCode}:penalty`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:penalty:updated", gameState);
      ack({ ok: true });
      });
    });

    socket.on("game:penalty:submit", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      await withRoomLock(roomCode, async () => {
      const raw = await redis.get(`game:${roomCode}:penalty`);
      if (!raw) return ack({ ok: false, reason: "no_game" });

      const gameState = JSON.parse(raw);
      if (gameState.status !== "playing") return ack({ ok: false, reason: "finished" });
      if (!Object.prototype.hasOwnProperty.call(gameState.scores ?? {}, String(userId))) {
        return ack({ ok: false, reason: "not_a_player" });
      }

      const choice = Number(payload?.choice);
      if (!Number.isInteger(choice) || choice < 0 || choice > 8) {
        return ack({ ok: false, reason: "invalid_choice" });
      }

      if (gameState.submissions[String(userId)] !== undefined) {
        return ack({ ok: false, reason: "already_submitted" });
      }
      gameState.submissions[String(userId)] = choice;

      const kickerId = String(gameState.kicker);
      const keeperId = String(gameState.keeper);
      let nextGameState = gameState;

      if (
        gameState.submissions[kickerId] !== undefined &&
        gameState.submissions[keeperId] !== undefined
      ) {
        const kickerDir = gameState.submissions[kickerId]; // 0~8 (3x3)
        const keeperDir = gameState.submissions[keeperId]; // 0~8 (3x3 exact match)

        nextGameState = resolvePenaltyRound(gameState, kickerDir, keeperDir);
      }

      await redis.set(`game:${roomCode}:penalty`, JSON.stringify(nextGameState), "EX", 3600);
      io.to(roomCode).emit("game:penalty:updated", maskPenaltyState(nextGameState));
      if (gameState.status === 'playing' && nextGameState.status === 'finished') {
        const winner = nextGameState.result?.winner;
        await recordGameOutcome(roomCode, {
          winner: winner && winner !== 'draw' ? winner : null,
          players: Object.keys(nextGameState.scores),
          gameType: 'penalty',
        });
      }
      ack({ ok: true });
      });
    });

    // ── Bowling ───────────────────────────────────────────────────────────
    socket.on("game:bowling:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      await withRoomLock(roomCode, async () => {
      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });
      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });
      const existing = await redis.get(`game:${roomCode}:bowling`);
      if (existing && JSON.parse(existing).status === 'playing') {
        socket.emit("game:bowling:updated", withBowlingFrames(JSON.parse(existing)));
        return ack({ ok: true, resumed: true });
      }

      const gameState = initBowlingGame(orderedPlayers[0], orderedPlayers[1]);
      await redis.set(`game:${roomCode}:bowling`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:bowling:updated", withBowlingFrames(gameState));
      ack({ ok: true });
      });
    });

    socket.on("game:bowling:roll", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      await withRoomLock(roomCode, async () => {
      const raw = await redis.get(`game:${roomCode}:bowling`);
      if (!raw) return ack({ ok: false, reason: "no_game" });

      const previousState = JSON.parse(raw);
      if (!Object.prototype.hasOwnProperty.call(previousState.scores ?? {}, String(userId))) {
        return ack({ ok: false, reason: "not_a_player" });
      }
      if (previousState.status !== 'playing' || previousState.turn !== String(userId)) {
        return ack({ ok: false, reason: "not_your_turn" });
      }
      const clampUnit = (v) => Math.min(1, Math.max(-1, Number(v) || 0));
      // 클라이언트와 같은 결정론적 시뮬레이션으로 핀 수를 정한다. 손 떨림(jitter)을
      // 더한 실제 조준값을 ack로 돌려주면 클라이언트가 그 값으로 연출해 결과가 일치한다.
      const effective = jitterThrow(clampUnit(payload?.aim), clampUnit(payload?.curve));
      const playerRolls = previousState.rolls[String(userId)] || [];
      const ctx = nextRollContext(playerRolls);
      const deck = standingDeck(playerRolls, ctx, previousState.history, String(userId));
      const pins = simulateBowlingRoll(deck, effective.aim, effective.curve).pinsDown;
      const gameState = rollBowlingFrame(previousState, String(userId), pins, effective);
      if (gameState === previousState) return ack({ ok: false, reason: "invalid_action" });

      await redis.set(`game:${roomCode}:bowling`, JSON.stringify(gameState), "EX", 3600);
      // ack를 먼저 보내 투구자가 바로 연출을 시작하게 하고, 그다음 방 전체에 상태를 알린다.
      ack({ ok: true, pins: gameState.lastRoll?.pinsKnocked ?? pins, aim: effective.aim, curve: effective.curve });
      io.to(roomCode).emit("game:bowling:updated", withBowlingFrames(gameState));
      if (gameState.status === 'finished') {
        const winner = gameState.result?.winner;
        await recordGameOutcome(roomCode, {
          winner: winner && winner !== 'draw' ? winner : null,
          players: Object.keys(gameState.scores),
          gameType: 'bowling',
        });
      }
      });
    });

    socket.on("game:bomb:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
      const parsed = bombNewSchema.safeParse(payload || {});
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }

      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }

      const existing = await redis.get(bombGameKey(roomCode));
      if (existing) {
        const existingState = JSON.parse(existing);
        if (!isTimeUp(existingState)) {
          ack({ ok: false, reason: "game_in_progress" });
          return;
        }
        await explodeBomb(roomCode, existingState); // 놓친 폭발을 지금 처리한다.
      }

      const gameState = createBombGameState(orderedPlayers, parsed.data.duration);
      await redis.set(bombGameKey(roomCode), JSON.stringify(gameState), "EX", 300);
      scheduleBombExplosion(roomCode, gameState);

      const bombStarted = {
        currentPlayer: gameState.currentPlayer,
        duration: Math.round(gameState.duration / 1000),
        startTime: gameState.startTime,
        quiz: {
          category: gameState.currentQuiz.category,
          question: gameState.currentQuiz.question,
        },
      };
      io.to(roomCode).emit("game:bomb:started", bombStarted);
      ack({ ok: true, ...bombStarted });
      }); // withRoomLock
    });

    socket.on("game:bomb:answer", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      await withRoomLock(roomCode, async () => {
      const parsed = bombAnswerSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const gameText = await redis.get(bombGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }

      const gameState = JSON.parse(gameText);
      if (gameState.currentPlayer !== userId) {
        ack({ ok: false, reason: "not_your_turn" });
        return;
      }

      if (isTimeUp(gameState)) {
        await explodeBomb(roomCode, gameState);
        ack({ ok: false, reason: "time_up", loser: userId });
        return;
      }

      const { answer } = parsed.data;
      const correct = checkAnswer(answer, gameState.currentQuiz.alternatives);

      if (!correct) {
        io.to(roomCode).emit("game:bomb:wrong_answer", {
          by: userId,
          answer,
        });
        ack({ ok: false, reason: "wrong_answer" });
        return;
      }

      passBomb(gameState);
      await redis.set(bombGameKey(roomCode), JSON.stringify(gameState), "EX", 300);

      io.to(roomCode).emit("game:bomb:passed", {
        from: userId,
        to: gameState.currentPlayer,
        quiz: {
          category: gameState.currentQuiz.category,
          question: gameState.currentQuiz.question,
        },
        passCount: gameState.passCount,
      });
      ack({ ok: true, nextPlayer: gameState.currentPlayer });
      }); // withRoomLock
    });

    // 재시작(재대결): 요청을 Redis에 기록하고, 응답은 그 기록과 대조해 검증한다.
    // 위조된 respond(요청 없음/본인 요청/다른 게임)로 진행 중인 판을 덮어쓸 수 없다.
    socket.on("game:restart:request", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const gameType = payload?.gameType;
      if (!RESTARTABLE_GAME_TYPES.has(gameType)) {
        ack({ ok: false, reason: "unsupported_game" });
        return;
      }
      await redis.set(
        restartKey(roomCode),
        JSON.stringify({ by: userId, gameType, at: Date.now() }),
        "EX",
        RESTART_REQUEST_TTL_SEC,
      );
      socket.to(roomCode).emit("game:restart:requested", { by: userId, gameType });
      ack({ ok: true });
    });

    socket.on("game:restart:respond", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }

      const { accept, gameType } = payload || {};

      await withRoomLock(roomCode, async () => {
      const rawRequest = await redis.get(restartKey(roomCode));
      const request = rawRequest ? JSON.parse(rawRequest) : null;
      if (!request || request.by === userId || request.gameType !== gameType) {
        ack({ ok: false, reason: "no_restart_request" });
        return;
      }
      await redis.del(restartKey(roomCode));

      if (!accept) {
        socket.to(roomCode).emit("game:restart:declined", { by: userId });
        ack({ ok: true, accepted: false });
        return;
      }

      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }

      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      const [p1, p2] = orderedPlayers;
      if (!p1 || !p2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }

      const restartModule = GAME_MODULE_BY_TYPE.get(gameType);
      if (restartModule?.restart) {
        await restartModule.restart(roomCode, kit, { p1, p2, orderedPlayers, requestedBy: request.by });
      } else if (gameType === "yut") {
        const previousText = await redis.get(yutGameKey(roomCode));
        const previous = previousText ? JSON.parse(previousText) : {};
        const gameState = createYutGameState(p1, p2, {
          characters: previous.characters ?? {},
          bgm: previous.bgm ?? null,
        });
        gameState.stake = previous.stake ?? 0;
        gameState.gameId = randomUUID();
        gameState.catchCoinBonus = {};
        gameState.winCoinBonus = {};

        // 아이템 스탯/표시 정보 재적재
        const { rows: rp1 } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [p1]);
        const { rows: rp2 } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [p2]);
        const [p1Info, p2Info, p1Stats, p2Stats] = await Promise.all([
          rp1[0]?.UserId ? getEquippedItemsInfo(rp1[0].UserId) : Promise.resolve({}),
          rp2[0]?.UserId ? getEquippedItemsInfo(rp2[0].UserId) : Promise.resolve({}),
          rp1[0]?.UserId ? getEquippedStats(rp1[0].UserId) : Promise.resolve({}),
          rp2[0]?.UserId ? getEquippedStats(rp2[0].UserId) : Promise.resolve({}),
        ]);
        gameState.equippedItems = { [p1]: p1Info, [p2]: p2Info };
        gameState.playerStats = { [p1]: p1Stats, [p2]: p2Stats };

        await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);
        emitYutState(io, roomCode, "game:yut:started", gameState);
      } else if (gameType === "marble") {
        const previousText = await redis.get(marbleGameKey(roomCode));
        const previous = previousText ? JSON.parse(previousText) : {};
        await startMarbleGame(roomCode, p1, p2, previous.characters ?? {});
      } else if (gameType === "tank") {
        await restartTankGame(roomCode, p1, p2);
      } else if (gameType === "bomb") {
        const previousBombText = await redis.get(bombGameKey(roomCode));
        const previousBombDuration = previousBombText ? Math.round((JSON.parse(previousBombText).duration ?? 30000) / 1000) : 30;
        const gameState = createBombGameState(orderedPlayers, previousBombDuration);
        await redis.set(bombGameKey(roomCode), JSON.stringify(gameState), "EX", 300);
        scheduleBombExplosion(roomCode, gameState);
        io.to(roomCode).emit("game:bomb:started", {
          currentPlayer: gameState.currentPlayer,
          duration: Math.round(gameState.duration / 1000),
          startTime: gameState.startTime,
          quiz: { category: gameState.currentQuiz.category, question: gameState.currentQuiz.question },
        });
      }

      ack({ ok: true, accepted: true });
      }); // withRoomLock
    });

    socket.on("heart:send", (_, ackRaw) => {
      const ack = typeof ackRaw === "function" ? ackRaw : () => {};
      const { roomCode, userId } = socket.data;
      if (!roomCode) return ack({ ok: false });
      socket.to(roomCode).emit("heart:received", { from: userId });
      ack({ ok: true });
    });

    // ── 캐치마인드 ────────────────────────────────────────────────────────────

    socket.on("game:catch:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      try {
        const { roomCode, userId } = socket.data;
        if (!roomCode) return ack({ error: "not_in_room" });

        await withRoomLock(roomCode, async () => {
        // 로비 키는 game:lobby:start 처리 시 삭제되므로 presence에서 직접 players를 가져옴
        const players = await getOrderedPlayers(roomCode, getPresence(io, roomCode));
        if (players.length < 2) return ack({ error: "need_two_players" });
        const existing = await redis.get(`game:${roomCode}:catch`);
        if (existing) {
          const existingState = JSON.parse(existing);
          if (existingState.phase !== "gameover") {
            // 진행 중인 판: 거절하지 않고 요청자에게 현재 라운드를 다시 보여준다.
            await emitCatchStateTo(socket, roomCode, existingState);
            return ack({ ok: true, resumed: true });
          }
        }

        const maxRounds = Number.isInteger(payload?.maxRounds) && payload.maxRounds >= 2 && payload.maxRounds <= 20
          ? payload.maxRounds : 6;

        const { default: WORDS } = await import("./catch_words.js");
        const shuffled = [...WORDS].sort(() => Math.random() - 0.5);
        const word = shuffled[0];

        const drawerIdx = Math.floor(Math.random() * players.length);
        const drawer = players[drawerIdx] || userId;

        const scores = {};
        for (const p of players) scores[p] = 0;

        const state = {
          drawer,
          word,
          round: 1,
          maxRounds,
          scores,
          phase: "drawing",
          hintRevealed: [],
          hintUsedBy: [],
          roundEndsAt: Date.now() + CATCH_ROUND_MS,
          usedWords: [word],
        };
        await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

        const nicknames = await getPresenceNicknames(io, roomCode);

        // 모두에게 게임 시작 알림 (단어 제외)
        io.to(roomCode).emit("game:catch:started", {
          drawer,
          round: 1,
          maxRounds,
          scores,
          wordLen: [...word].length,
          nicknames,
        });

        // drawer에게만 단어 전송
        const drawerSocket = [...(io.sockets.adapter.rooms.get(roomCode) || [])]
          .map((sid) => io.sockets.sockets.get(sid))
          .find((s) => s?.data?.userId === drawer);
        drawerSocket?.emit("game:catch:word", { word });

        ack({ ok: true });
        });
      } catch (err) {
        console.error("game:catch:start error", err);
        ack({ error: "server_error" });
      }
    });

    // draw relay — no ack for performance
    socket.on("game:catch:draw", async (payload) => {
      const { roomCode, userId } = socket.data;
      if (!roomCode) return;
      const catchDrawRaw = await redis.get(`game:${roomCode}:catch`);
      if (!catchDrawRaw) return;
      const catchDrawState = JSON.parse(catchDrawRaw);
      if (catchDrawState.drawer !== userId || catchDrawState.phase !== "drawing") return;
      const parsedDraw = catchDrawSchema.safeParse(payload);
      if (!parsedDraw.success) return;
      // 과도한 전송(초당 120점 초과)은 버린다.
      const now = Date.now();
      const bucket = socket.data.catchDrawBucket ?? { windowStart: now, count: 0 };
      if (now - bucket.windowStart >= 1000) { bucket.windowStart = now; bucket.count = 0; }
      bucket.count += 1;
      socket.data.catchDrawBucket = bucket;
      if (bucket.count > 120) return;
      socket.to(roomCode).emit("game:catch:draw", parsedDraw.data);
    });

    // clear relay
    socket.on("game:catch:clear", async () => {
      const { roomCode, userId } = socket.data;
      if (!roomCode) return;
      const catchClearRaw = await redis.get(`game:${roomCode}:catch`);
      if (!catchClearRaw) return;
      const catchClearState = JSON.parse(catchClearRaw);
      if (catchClearState.drawer !== userId) return;
      socket.to(roomCode).emit("game:catch:clear");
    });

    socket.on("game:catch:guess", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      try {
        const { roomCode, userId } = socket.data;
        if (!roomCode) return ack({ ok: false });

        await withRoomLock(roomCode, async () => {

        const text = String(payload?.text || "").trim().slice(0, 50);
        if (!text) return ack({ ok: false, reason: "invalid_payload" });

        const raw = await redis.get(`game:${roomCode}:catch`);
        if (!raw) return ack({ ok: false });
        const state = JSON.parse(raw);

        if (state.phase !== "drawing") return ack({ ok: false });
        if (userId === state.drawer) return ack({ ok: false }); // drawer는 추측 불가

        // 모두에게 추측 로그
        io.to(roomCode).emit("game:catch:guess_log", { text, userId });

        // 정답 판정 (공백·대소문자 무시)
        const normalize = (s) => s.replace(/\s/g, "").toLowerCase();
        if (normalize(text) === normalize(state.word)) {
          state.scores[userId] = (state.scores[userId] || 0) + 2;
          state.scores[state.drawer] = (state.scores[state.drawer] || 0) + 1;
          state.phase = "guessed";
          await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

          io.to(roomCode).emit("game:catch:correct", {
            word: state.word,
            scores: state.scores,
            guesser: userId,
          });
        }

        ack({ ok: true });
        });
      } catch (err) {
        console.error("game:catch:guess error", err);
        ack({ ok: false });
      }
    });

    socket.on("game:catch:hint_req", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      try {
        const { roomCode, userId } = socket.data;
        if (!roomCode) return ack({ ok: false });

        await withRoomLock(roomCode, async () => {

        const raw = await redis.get(`game:${roomCode}:catch`);
        if (!raw) return ack({ ok: false });
        const state = JSON.parse(raw);

        if (state.phase !== "drawing" || userId === state.drawer) return ack({ ok: false });
        if (!Object.prototype.hasOwnProperty.call(state.scores, userId)) return ack({ ok: false, reason: "not_a_player" });
        state.hintUsedBy ??= [];
        if (state.hintUsedBy.includes(userId)) return ack({ ok: false, reason: "hint_used" });

        const chars = [...state.word];
        const hidden = chars.map((_, i) => i).filter((i) => !state.hintRevealed.includes(i));
        if (hidden.length === 0) return ack({ ok: false });

        const revealIdx = hidden[Math.floor(Math.random() * hidden.length)];
        state.hintRevealed.push(revealIdx);
        state.hintUsedBy.push(userId);
        await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

        const hint = chars.map((c, i) => (state.hintRevealed.includes(i) ? c : "_")).join("");

        // guesser(본인)에게만 전송
        socket.emit("game:catch:hint", { hint });
        ack({ ok: true });
        });
      } catch (err) {
        console.error("game:catch:hint_req error", err);
        ack({ ok: false });
      }
    });

    socket.on("game:catch:timeout", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      try {
        const { roomCode, userId } = socket.data;
        if (!roomCode) return ack({ ok: false });

        await withRoomLock(roomCode, async () => {

        const raw = await redis.get(`game:${roomCode}:catch`);
        if (!raw) return ack({ ok: false });
        const state = JSON.parse(raw);

        // 방장 권한 대신 서버 시각으로 검증한다: 출제자는 언제든 포기할 수 있고,
        // 다른 참가자는 서버에 기록된 마감 시각(시계 오차 2초 허용)이 지난 뒤에만 가능하다.
        if (!Object.prototype.hasOwnProperty.call(state.scores, userId)) return ack({ ok: false, reason: 'not_a_player' });
        if (state.phase !== "drawing") return ack({ ok: false });
        const deadline = state.roundEndsAt ?? 0;
        if (userId !== state.drawer && Date.now() < deadline - 2000) {
          return ack({ ok: false, reason: "round_not_over" });
        }
        state.phase = "timeout";
        await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

        io.to(roomCode).emit("game:catch:timeout_result", { word: state.word });
        ack({ ok: true });
        });
      } catch (err) {
        console.error("game:catch:timeout error", err);
        ack({ ok: false });
      }
    });

    socket.on("game:catch:next", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      try {
        const { roomCode, userId } = socket.data;
        if (!roomCode) return ack({ ok: false });

        await withRoomLock(roomCode, async () => {

        const raw = await redis.get(`game:${roomCode}:catch`);
        if (!raw) return ack({ ok: false });
        const state = JSON.parse(raw);

        if (!Object.prototype.hasOwnProperty.call(state.scores, userId)) return ack({ ok: false, reason: 'not_a_player' });

        if (state.phase !== "guessed" && state.phase !== "timeout") {
          return ack({ ok: false, reason: "round_not_finished" });
        }

        const nextRound = state.round + 1;

        if (nextRound > state.maxRounds) {
          // 게임 종료: 상태를 지워 다음 게임이 막히지 않게 한다.
          await redis.del(`game:${roomCode}:catch`);

          const entries = Object.entries(state.scores);
          const maxScore = Math.max(...entries.map(([, s]) => s));
          const winners = entries.filter(([, s]) => s === maxScore).map(([uid]) => uid);
          const winner = winners.length === 1 ? winners[0] : "draw";

          io.to(roomCode).emit("game:catch:gameover", { winner, scores: state.scores });
          await recordGameOutcome(roomCode, {
            winner: winner === 'draw' ? null : winner,
            players: Object.keys(state.scores),
            gameType: 'catch',
          });
          return ack({ ok: true });
        }

        // 다음 라운드: 역할 교대
        const players = Object.keys(state.scores); // start에서 저장된 players
        const prevDrawerIdx = players.indexOf(state.drawer);
        const nextDrawer = players[(prevDrawerIdx + 1) % players.length];

        const { default: WORDS } = await import("./catch_words.js");
        const available = WORDS.filter((w) => !state.usedWords.includes(w));
        const pool = available.length > 0 ? available : WORDS;
        const word = pool[Math.floor(Math.random() * pool.length)];

        state.drawer = nextDrawer;
        state.word = word;
        state.round = nextRound;
        state.phase = "drawing";
        state.hintRevealed = [];
        state.hintUsedBy = [];
        state.roundEndsAt = Date.now() + CATCH_ROUND_MS;
        state.usedWords.push(word);
        await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

        const nicknames = await getPresenceNicknames(io, roomCode);

        io.to(roomCode).emit("game:catch:round_start", {
          drawer: nextDrawer,
          round: nextRound,
          maxRounds: state.maxRounds,
          scores: state.scores,
          wordLen: [...word].length,
          nicknames,
        });

        // 새 drawer에게만 단어 전송
        const drawerSocket = [...(io.sockets.adapter.rooms.get(roomCode) || [])]
          .map((sid) => io.sockets.sockets.get(sid))
          .find((s) => s?.data?.userId === nextDrawer);
        drawerSocket?.emit("game:catch:word", { word });

        ack({ ok: true });
        });
      } catch (err) {
        console.error("game:catch:next error", err);
        ack({ ok: false });
      }
    });

    socket.on("game:catch:reset", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      try {
        const { roomCode, userId } = socket.data;
        if (!roomCode) return ack({ ok: false });

        await withRoomLock(roomCode, async () => {
        const catchResetRaw = await redis.get(`game:${roomCode}:catch`);
        if (catchResetRaw) {
          const catchResetState = JSON.parse(catchResetRaw);
          if (!Object.prototype.hasOwnProperty.call(catchResetState.scores ?? {}, userId)) {
            return ack({ ok: false, reason: 'not_a_player' });
          }
        } else {
          const presence = getPresence(io, roomCode);
          if (!presence.includes(userId)) {
            return ack({ ok: false, reason: 'not_in_room' });
          }
        }
        await redis.del(`game:${roomCode}:catch`);
        io.to(roomCode).emit("game:catch:reset_done");
        ack({ ok: true });
        });
      } catch (err) {
        console.error("game:catch:reset error", err);
        ack({ ok: false });
      }
    });

    // ── Tank 대작전 2.0 ─────────────────────────────────────────────────────────
    // 모든 판정은 fortress-engine이 하고, 여기서는 저장·마스킹 브로드캐스트·턴 타이머·
    // 정산(멱등)·재대결을 담당한다. 조준값은 발사 이벤트에만 실려 오므로 상대에게 새지 않는다.
    const tankSelectSchema = z.object({ tankClass: z.enum(TANK_CLASS_IDS) });
    const tankFireSchema = z.object({
      angle: z.number().min(0).max(180).optional(),
      power: z.number().min(1).max(100).optional(),
      weapon: z.enum(TANK_WEAPON_IDS).optional(),
    }).optional().default({});

    const loadTank = async (roomCode) => {
      const raw = await redis.get(tankGameKey(roomCode));
      return raw ? JSON.parse(raw) : null;
    };

    socket.on("game:tank:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      await withRoomLock(roomCode, async () => {
      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const existing = await loadTank(roomCode);
      if (existing && existing.phase !== "result") {
        // 진행 중인 판: 거절하지 않고 요청자에게 이어서 보여준다.
        socket.emit("game:tank:started", tankViewFor(existing, userId));
        return ack({ ok: true, resumed: true });
      }

      const [p1, p2] = orderedPlayers;
      // 판돈은 로비에서 합의된 서버 기록만 사용한다(payload의 stake 무시).
      const pending = await consumePendingGame(roomCode, "tank");
      const state = createFortressState(p1, p2, { stake: pending.stake, gameId: pending.gameId });
      await saveTank(roomCode, state);
      await emitTankState(roomCode, "game:tank:started", state);
      ack({ ok: true });
      });
    });

    socket.on("game:tank:select", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const parsed = tankSelectSchema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
      const state = await loadTank(roomCode);
      if (!state) return ack({ ok: false, reason: "no_game" });
      const result = selectTankClass(state, userId, parsed.data.tankClass);
      if (!result.ok) return ack({ ok: false, reason: result.error });
      if (result.state.phase === "aiming") {
        result.state.turnDeadline = Date.now() + TANK_TURN_TIME_MS;
      }
      await saveTank(roomCode, result.state);
      await emitTankState(roomCode, "game:tank:updated", result.state);
      if (result.state.phase === "aiming") scheduleTankTimer(roomCode, result.state);
      ack({ ok: true, battleStarted: result.state.phase === "aiming" });
      });
    });

    socket.on("game:tank:move", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ delta: z.number().int().min(-10).max(10) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
      const state = await loadTank(roomCode);
      if (!state) return ack({ ok: false, reason: "no_game" });

      const result = moveTank(state, userId, parsed.data.delta);
      if (!result.ok) return ack({ ok: false, reason: result.error });

      await saveTank(roomCode, result.state);
      await emitTankState(roomCode, "game:tank:updated", result.state);
      if (result.events?.length) io.to(roomCode).emit("game:tank:moved", { by: userId, events: result.events });
      ack({ ok: true });
      });
    });

    // 하위호환: 조준값을 서버에 미리 저장(본인에게만 응답). 상대에게는 브로드캐스트하지 않는다.
    socket.on("game:tank:aim", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({
        angle: z.number().min(0).max(180),
        power: z.number().min(1).max(100),
      });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
      const state = await loadTank(roomCode);
      if (!state) return ack({ ok: false, reason: "no_game" });
      const result = aimTank(state, userId, parsed.data.angle, parsed.data.power);
      if (!result.ok) return ack({ ok: false, reason: result.error });
      await saveTank(roomCode, result.state);
      ack({ ok: true });
      });
    });

    socket.on("game:tank:weapon", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ weapon: z.enum(TANK_WEAPON_IDS) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
      const state = await loadTank(roomCode);
      if (!state) return ack({ ok: false, reason: "no_game" });
      const result = selectWeapon(state, userId, parsed.data.weapon);
      if (!result.ok) return ack({ ok: false, reason: result.error });
      await saveTank(roomCode, result.state);
      await emitTankState(roomCode, "game:tank:updated", result.state);
      ack({ ok: true });
      });
    });

    socket.on("game:tank:fire", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const parsed = tankFireSchema.safeParse(payload ?? {});
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
      const state = await loadTank(roomCode);
      if (!state) return ack({ ok: false, reason: "no_game" });

      const result = fireTank(state, userId, parsed.data);
      if (!result.ok) return ack({ ok: false, reason: result.error });

      io.to(roomCode).emit("game:tank:shot", result.shotResult);
      if (result.state.phase === "result") {
        await finishTankGame(roomCode, result.state);
      } else {
        result.state.turnDeadline = Date.now() + TANK_TURN_TIME_MS;
        await saveTank(roomCode, result.state);
        await emitTankState(roomCode, "game:tank:updated", result.state);
        scheduleTankTimer(roomCode, result.state);
      }
      ack({ ok: true });
      });
    });

    // ── 고스톱 (2인 맞고) ──────────────────────────────────────────────
    // 상대 손패 숨김이 필요하므로 per-viewer 직렬화로 개별 emit
    const emitGostop = (eventName, state) => {
      const roomCode = socket.data.roomCode;
      const room = io.sockets.adapter.rooms.get(roomCode);
      if (!room) return;
      for (const sid of room) {
        const s = io.sockets.sockets.get(sid);
        const uid = s?.data?.userId;
        if (!uid) continue;
        s.emit(eventName, serializeGostopFor(state, uid));
      }
    };

    // 종료 처리: 지갑 정산이 성공한 뒤에만 게임 상태를 지운다.
    // 실패하면 Redis에 pending 상태를 남겨 재시도할 수 있게 한다.
    const finishGostop = async (roomCode, state) => {
      const st = state.settlement;
      if (st && st.amount > 0) {
        const gameRef = state.gameId ?? `gostop:${roomCode}:legacy:${state.turn ?? 0}`;
        const wallet = await settleAndEmitWallet(
          io, roomCode, st.winnerId, st.loserId, st.amount, gameRef,
        );
        if (!wallet.ok) {
          const pending = {
            ...state,
            settlementStatus: 'pending',
            settlementError: wallet.reason ?? 'wallet_settlement_failed',
          };
          await redis.set(gostopGameKey(roomCode), JSON.stringify(pending), "EX", 7200);
          emitGostop("game:gostop:settlement_pending", pending);
          return false;
        }
      }
      if (st) {
        await Promise.all([
          saveGameResult(roomCode, st.winnerId, st.loserId, 'gostop', st.amount ?? 0),
          grantGameXpAndMissions(st.winnerId, st.loserId, 'gostop'),
        ]);
      }
      await redis.del(gostopGameKey(roomCode));
      emitGostop("game:gostop:ended", { ...state, settlementStatus: 'settled' });
      return true;
    };

    // 나가리: 배수 이월 + 선 유지로 자동 재배분
    const handleGostopResult = async (roomCode, state) => {
      if (state.phase === 'finished') {
        await finishGostop(roomCode, state);
        return;
      }
      if (state.phase === 'nageori') {
        io.to(roomCode).emit("game:gostop:nageori", {
          baseMultiplier: state.baseMultiplier,
        });
        const next = createGostopGameState(state.players[0], state.players[1], {
          perPointBet: state.perPointBet,
          baseMultiplier: state.baseMultiplier,
          firstPlayerIdx: state.firstPlayerIdx,
          gameId: state.gameId,
        });
        if (next.phase === 'finished') {
          emitGostop("game:gostop:started", next);
          await finishGostop(roomCode, next);
          return;
        }
        await redis.set(gostopGameKey(roomCode), JSON.stringify(next), "EX", 7200);
        emitGostop("game:gostop:started", next);
        return;
      }
      await redis.set(gostopGameKey(roomCode), JSON.stringify(state), "EX", 7200);
      emitGostop("game:gostop:updated", state);
    };

    socket.on("game:gostop:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      await withRoomLock(roomCode, async () => {
        const presence = getPresence(io, roomCode);
        if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });

        const schema = z.object({
          perPointBet: z.union([
            z.literal(0), z.literal(100), z.literal(500), z.literal(1000),
          ]).optional().default(100),
        });
        const parsed = schema.safeParse(payload ?? {});
        if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

        const existing = await redis.get(gostopGameKey(roomCode));
        if (existing) return ack({ ok: false, reason: "game_in_progress" });

        const orderedPlayers = await getOrderedPlayers(roomCode, presence);
        if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });

        const [p1, p2] = orderedPlayers;
        // 점당 금액은 로비에서 합의된 서버 기록만 사용한다(payload의 perPointBet 무시).
        const pendingGostop = await consumePendingGame(roomCode, "gostop");
        const state = createGostopGameState(p1, p2, {
          perPointBet: GOSTOP_STAKES.has(pendingGostop.stake) ? pendingGostop.stake : 0,
          gameId: `gostop:${pendingGostop.gameId}`,
        });

        if (state.phase === 'finished') {
          // 총통 즉시 승리
          emitGostop("game:gostop:started", state);
          await finishGostop(roomCode, state);
          return ack({ ok: true });
        }

        await redis.set(gostopGameKey(roomCode), JSON.stringify(state), "EX", 7200);
        emitGostop("game:gostop:started", state);
        ack({ ok: true });
      });
    });

    socket.on("game:gostop:play", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ cardId: z.string().min(1) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(gostopGameKey(roomCode));
        if (!raw) return ack({ ok: false, reason: "no_game" });

        let result;
        try {
          result = playHandCard(JSON.parse(raw), userId, parsed.data.cardId);
        } catch (err) {
          return ack({ ok: false, reason: err.message });
        }
        await handleGostopResult(roomCode, result);
        ack({ ok: true });
      });
    });

    socket.on("game:gostop:shake", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const parsed = z.object({ decision: z.enum(["shake", "pass"]) }).safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(gostopGameKey(roomCode));
        if (!raw) return ack({ ok: false, reason: "no_game" });
        let result;
        try {
          result = declareShake(JSON.parse(raw), userId, parsed.data.decision);
        } catch (err) {
          return ack({ ok: false, reason: err.message });
        }
        await handleGostopResult(roomCode, result);
        ack({ ok: true });
      });
    });

    socket.on("game:gostop:bomb", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const parsed = z.object({ month: z.number().int().min(1).max(12) }).safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(gostopGameKey(roomCode));
        if (!raw) return ack({ ok: false, reason: "no_game" });
        let result;
        try {
          result = playBomb(JSON.parse(raw), userId, parsed.data.month);
        } catch (err) {
          return ack({ ok: false, reason: err.message });
        }
        await handleGostopResult(roomCode, result);
        ack({ ok: true });
      });
    });

    socket.on("game:gostop:pick", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ fieldCardId: z.string().min(1) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(gostopGameKey(roomCode));
        if (!raw) return ack({ ok: false, reason: "no_game" });

        let result;
        try {
          result = selectDeckCapture(JSON.parse(raw), userId, parsed.data.fieldCardId);
        } catch (err) {
          return ack({ ok: false, reason: err.message });
        }
        await handleGostopResult(roomCode, result);
        ack({ ok: true });
      });
    });

    socket.on("game:gostop:gostop", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ decision: z.enum(["go", "stop"]) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(gostopGameKey(roomCode));
        if (!raw) return ack({ ok: false, reason: "no_game" });

        let result;
        try {
          result = declareGoStop(JSON.parse(raw), userId, parsed.data.decision);
        } catch (err) {
          return ack({ ok: false, reason: err.message });
        }
        await handleGostopResult(roomCode, result);
        ack({ ok: true });
      });
    });

    socket.on("game:gostop:settlement_retry", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      await withRoomLock(roomCode, async () => {
        const raw = await redis.get(gostopGameKey(roomCode));
        if (!raw) return ack({ ok: false, reason: "no_pending_settlement" });
        const state = JSON.parse(raw);
        if (state.phase !== 'finished' || state.settlementStatus !== 'pending') {
          return ack({ ok: false, reason: "no_pending_settlement" });
        }
        const completed = await finishGostop(roomCode, state);
        ack(completed
          ? { ok: true }
          : { ok: false, reason: 'wallet_settlement_failed' });
      });
    });

    // 재접속 복원용 현재 상태 조회
    socket.on("game:gostop:state", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const raw = await redis.get(gostopGameKey(roomCode));
      if (!raw) return ack({ ok: false, reason: "no_game" });
      const storedState = JSON.parse(raw);
      const state = resolveGostopTerminalState(storedState);
      if (state.phase !== storedState.phase) {
        // 이미 양쪽 손패가 소진된 구버전 상태를 조회 시점에 복구한다.
        await handleGostopResult(roomCode, state);
      }
      ack({ ok: true, state: serializeGostopFor(state, userId) });
    });

    socket.on("disconnect", () => {
      const roomCode = socket.data.roomCode;
      if (!roomCode) {
        return;
      }
      emitPresence(io, roomCode);
      for (const gameType of gameTypes) {
        cleanupLobbyForUser(io, roomCode, gameType, socket.data.userId).catch((err) =>
          console.error(`lobby cleanup error: ${err.message}`),
        );
      }

      // 게임 화면을 보던 소켓이 끊기면 마지막 뷰어일 때 활성 상태 삭제
      cleanupGameSessionOnDisconnect(socket, io, redis, sessionScheduler).catch((err) =>
        console.error(`game session cleanup error: ${err.message}`),
      );

      // 가위바위보: 끊긴 사용자의 다른 소켓이 없고, 그 사용자가 참가 중인 미완료 판이 있을 때만 취소한다.
      const leftUserId = socket.data.userId;
      if (!getPresence(io, roomCode).includes(leftUserId)) {
        void withRoomLock(roomCode, async () => {
          const rpsRaw = await redis.get(rpsGameKey(roomCode));
          if (!rpsRaw) return;
          const rpsGame = JSON.parse(rpsRaw);
          if (rpsGame.gameWinner || !rpsGame.players?.includes(leftUserId)) return;
          await redis.del(rpsGameKey(roomCode));
          io.to(roomCode).emit("game:rps:cancelled", { reason: "player_disconnected", by: leftUserId });
        }).catch((err) => console.error(`rps cancel error: ${err.message}`));
      }
    });
  });
};
