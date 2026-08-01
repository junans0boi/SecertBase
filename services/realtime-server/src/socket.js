import { z } from "zod";
import { config } from "./config.js";
import { installSocketAuthentication, installSocketFeatureGate } from "./backend-access.js";
import { query } from "./db.js";
import { redis } from "./redis.js";
import { transferGameReward, getBalance, getEquippedStats, getEquippedItemsInfo } from "./wallet-engine.js";
import { grantXp, updateMissionProgress } from "./level-engine.js";
import {
  throwYut,
  movePiece,
  createYutGameState,
  checkWin,
  checkCatch,
  getCarriedPieces,
  hasBackdoMove,
  getNextPlayer as getNextYutPlayer,
  recordCapture,
  settleTurnAfterMove,
  serializeYutGame,
} from "./yut-engine.js";
import {
  createUnoGameState,
  canPlayCard,
  drawCards,
  applyCardEffect,
  clearDrawStack,
  hadPlayableCardOfColor,
  collectDiscardAllBatch,
  UNO_MODES,
  DEFAULT_UNO_MODE,
  getNextPlayer,
  checkWin as checkUnoWin,
} from "./uno-engine.js";
import {
  createBombGameState,
  checkAnswer,
  isTimeUp,
  passBomb,
} from "./bomb-engine.js";

import {
  initGame as initBlackjackGame,
  playerHit as hitBlackjack,
  playerStand as standBlackjack,
} from "./blackjack-engine.js";

import {
  initGame as initOldMaidGame,
  drawCard as drawOldMaidCard,
} from "./oldmaid-engine.js";

import {
  initBowlingGame,
  rollFrame as rollBowlingFrame,
  buildFrameDisplayData,
} from "./bowling-engine.js";

import {
  createFortressState,
  moveTank,
  aimTank,
  selectWeapon,
  fireTank,
} from "./fortress-engine.js";

import {
  createGostopGameState,
  playHandCard,
  selectDeckCapture,
  declareGoStop,
  serializeFor as serializeGostopFor,
} from "./gostop-engine.js";

function withBowlingFrames(gameState) {
  const frames = {};
  for (const [pid, rolls] of Object.entries(gameState.rolls || {})) {
    frames[pid] = buildFrameDisplayData(rolls);
  }
  return { ...gameState, frames };
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

const yutCharacters = ["honggilldong", "nolbu", "miho"];

const lobbyCharacterSchema = z.object({
  gameType: z.literal("yut"),
  character: z.enum(yutCharacters),
});

const yutNewSchema = z
  .object({
    characters: z.record(z.string(), z.enum(yutCharacters)).optional().default({}),
    bgm: z.enum(["yut1.mp3", "yut2.mp3", "yut3.mp3"]).optional().nullable(),
    stake: z.number().int().min(0).max(10000).optional().default(0),
  })
  .optional()
  .default({ characters: {}, bgm: null, stake: 0 });

const unoNewSchema = z
  .object({
    mode: z.enum(UNO_MODES).optional().default(DEFAULT_UNO_MODE),
    stake: z.number().int().min(0).max(10000).optional().default(0),
  })
  .optional()
  .default({ mode: DEFAULT_UNO_MODE, stake: 0 });

const rouletteSchema = z.object({
  options: z.array(z.string().min(1)).min(2).max(12),
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
  choice: z.string().min(1),
  options: z.array(z.string().min(1)).min(2).max(10),
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

const unoPlaySchema = z.object({
  cardId: z.string().min(1),
  declaredColor: z.preprocess(
    (value) => (value === null ? undefined : value),
    z.enum(["red", "yellow", "green", "blue"]).optional(),
  ),
});

const unoReactionSchema = z.object({
  type: z.enum([
    "cake",
    "candy",
    "coffee",
    "flyby",
    "pillow",
    "pizza",
    "sportscar",
    "tomato",
  ]),
});

const bombAnswerSchema = z.object({
  answer: z.string().min(1),
});

const bombNewSchema = z.object({
  duration: z.number().int().min(10).max(120).optional().default(30),
});

async function saveGameResult(roomCode, winnerCode, loserCode, gameType, stake) {
  try {
    const { rows } = await query('SELECT CoupleId FROM Couples WHERE RoomCode = ? LIMIT 1', [roomCode]);
    if (!rows[0]) return;
    await query(
      'INSERT INTO game_results (couple_id, game_type, winner_user_code, loser_user_code, stake) VALUES (?,?,?,?,?)',
      [rows[0].CoupleId, gameType, winnerCode, loserCode, stake ?? 0],
    );
  } catch (err) {
    console.error('[game_results] insert error:', err.message);
  }
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
  if (!stake || stake <= 0) return;
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
  } catch (err) {
    console.error("[wallet] settle error:", err.message);
  }
}

const roomKey = (roomCode) => `room:${roomCode}:state`;
const yutGameKey = (roomCode) => `yut:${roomCode}:game`;
const unoGameKey = (roomCode) => `uno:${roomCode}:game`;
const bombGameKey = (roomCode) => `bomb:${roomCode}:game`;
const gameLobbyKey = (roomCode, gameType) => `lobby:${roomCode}:${gameType}`;
const rpsGameKey = (roomCode) => `rps:${roomCode}:game`;
const pirateKey = (roomCode) => `pirate:${roomCode}:game`;
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
  return {
    gameType: lobby?.gameType,
    host,
    players,
    characterSelections,
    stake: lobby?.stake ?? 0,
    updatedAt: Date.now(),
  };
};

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
  const result = await query(
    `SELECT c.RoomCode, u.UserCode,
            COALESCE(u.Nickname, u.UserName, u.UserCode) AS Nickname
     FROM Couples c
     JOIN Users u ON u.UserId = ?
     WHERE c.Status = 'active' AND (c.User1Id = ? OR c.User2Id = ?)
     LIMIT 1`,
    [userId, userId, userId],
  );
  const row = result.rows[0];
  return row ? { userId: row.UserCode, roomCode: row.RoomCode, nickname: row.Nickname } : null;
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

const getUnoHandCount = (gameState) =>
  Object.fromEntries(
    gameState.players.map((player) => [
      player,
      gameState.hands[player]?.length ?? 0,
    ]),
  );

export const registerSocketHandlers = (io) => {
  installSocketAuthentication(io, config.JWT_SECRET, resolveSocketSession);
  io.on("connection", (socket) => {
    installSocketFeatureGate(socket, config.PUBLIC_FEATURE_SET);
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
      const key = gameLobbyKey(roomCode, gameType);
      const presence = getPresence(io, roomCode);
      const lobbyText = await redis.get(key);
      const baseLobby = lobbyText ? JSON.parse(lobbyText) : { gameType, host: null, players: [], stake: 0 };
      const lobby = normalizeLobby({ ...baseLobby, gameType }, presence);

      if (!lobby.players.includes(userId)) {
        lobby.players.push(userId);
      }
      if (!lobby.host) {
        lobby.host = userId;
      }
      // 방장만 stake 변경 가능
      if (userId === lobby.host && stake > 0) {
        lobby.stake = stake;
      } else if (!lobby.stake) {
        lobby.stake = 0;
      }
      lobby.updatedAt = Date.now();

      await redis.set(key, JSON.stringify(lobby), "EX", 1800);
      emitLobby(io, roomCode, lobby);
      ack({ ok: true, lobby: { ...lobby, profileEmojis: getPresenceProfiles(io, roomCode), nicknames: getPresenceNicknames(io, roomCode) } });
    });

    socket.on("game:lobby:set_stake", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = lobbyStakeSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }
      const { gameType, stake } = parsed.data;
      const key = gameLobbyKey(roomCode, gameType);
      const lobbyText = await redis.get(key);
      if (!lobbyText) { ack({ ok: false, reason: "lobby_not_found" }); return; }
      const lobby = normalizeLobby(JSON.parse(lobbyText), getPresence(io, roomCode));
      if (lobby.host !== userId) { ack({ ok: false, reason: "not_host" }); return; }
      lobby.stake = stake;
      lobby.updatedAt = Date.now();
      await redis.set(key, JSON.stringify(lobby), "EX", 1800);
      emitLobby(io, roomCode, lobby);
      ack({ ok: true });
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
      if (gameType === "yut") {
        const selectedCharacters = lobby.players.map(
          (player) => lobby.characterSelections[player],
        );
        if (selectedCharacters.some((character) => !character)) {
          ack({ ok: false, reason: "need_character_selection" });
          return;
        }
        if (new Set(selectedCharacters).size !== selectedCharacters.length) {
          ack({ ok: false, reason: "duplicate_character" });
          return;
        }
      }

      const metadata = gameType === "yut"
        ? {
            yutBgm: randomYutBgm(),
            yutCharacters: lobby.characterSelections,
            stake: lobby.stake ?? 0,
          }
        : { stake: lobby.stake ?? 0 };
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
        const unoKey = `uno:${roomCode}:game`;
        const bombKey = `bomb:${roomCode}:game`;

        const [yutGame, unoGame, bombGame] = await Promise.all([
          redis.get(yutKey),
          redis.get(unoKey),
          redis.get(bombKey),
        ]);

        const activeGames = {};
        
        if (yutGame) {
          const game = JSON.parse(yutGame);
          if (game.players) {
            activeGames.yut = serializeYutGame(game);
          }
        }

        if (unoGame) {
          const game = JSON.parse(unoGame);
          const userId = socket.data.userId;
          if (game.hands && game.discardPile) {
            activeGames.uno = {
              gameId: "active",
              turn: game.currentPlayer,
              mode: game.mode ?? DEFAULT_UNO_MODE,
              topCard: game.discardPile[game.discardPile.length - 1],
              declaredColor: game.declaredColor ?? null,
              drawStack: game.drawStack ?? 0,
              drawStackType: game.drawStackType ?? null,
              handCount: getUnoHandCount(game),
              hand: game.hands?.[userId] ?? [],
              unoCallNeeded: game.unoCallNeeded ?? null,
            };
          }
        }

        if (bombGame) {
          const game = JSON.parse(bombGame);
          const elapsed = Math.floor((Date.now() - game.startTime) / 1000);
          const remaining = Math.max(0, game.duration - elapsed);
          
          activeGames.bomb = {
            gameId: game.gameId,
            holder: game.holder,
            timer: remaining,
            category: game.category,
          };
        }

        ack({ ok: true, activeGames });
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

      const value = Math.floor(Math.random() * 6) + 1;
      const event = { value, by: userId, at: Date.now() };

      const stateText = await redis.get(roomKey(roomCode));
      const state = stateText ? JSON.parse(stateText) : defaultState;
      const nextState = { ...state, lastDice: event, updatedAt: Date.now() };
      await redis.set(roomKey(roomCode), JSON.stringify(nextState));

      io.to(roomCode).emit("game:dice:result", event);
      ack({ ok: true, event });
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

      const { options } = parsed.data;
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

    // ── RPS legacy (kept for safety) ─────────────────────────────────────────
    socket.on("game:rps:select", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = rpsSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }
      const { choice } = parsed.data;
      const sessionKey = `rps:${roomCode}:session`;
      const existing = await redis.get(sessionKey);
      const session = existing ? JSON.parse(existing) : { choices: {}, revealed: false };
      session.choices[userId] = choice;
      const presence = getPresence(io, roomCode);
      if (Object.keys(session.choices).length === presence.length && presence.length === 2) {
        const [u1, u2] = Object.keys(session.choices);
        const c1 = session.choices[u1], c2 = session.choices[u2];
        let winner = c1 === c2 ? "draw"
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
      const presence = getPresence(io, roomCode);
      if (presence.length < 2) { ack({ ok: false, reason: "need_two_players" }); return; }
      const players = await getOrderedPlayers(roomCode, presence);
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

    socket.on("game:rps:pick", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }
      const parsed = rpsPickSchema.safeParse(payload);
      if (!parsed.success) { ack({ ok: false, reason: "invalid_payload" }); return; }

      const raw = await redis.get(rpsGameKey(roomCode));
      if (!raw) { ack({ ok: false, reason: "no_game" }); return; }
      const game = JSON.parse(raw);
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
        const total = pick1.fingers + pick2.fingers;
        const p1Hit = pick1.guess === total;
        const p2Hit = pick2.guess === total;
        if (p1Hit && !p2Hit) {
          roundWinner = p1;
          game.scores[p1] = (game.scores[p1] || 0) + 1;
        } else if (p2Hit && !p1Hit) {
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

      ack({ ok: true });
    });

    socket.on("game:rps:reset", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      if (!roomCode) { ack({ ok: false, reason: "not_joined" }); return; }
      await redis.del(rpsGameKey(roomCode));
      io.to(roomCode).emit("game:rps:reset_done");
      ack({ ok: true });
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

      const { choice, options } = parsed.data;
      const sessionKey = `telepathy:${roomCode}:session`;
      const existing = await redis.get(sessionKey);
      const session = existing ? JSON.parse(existing) : { choices: {}, options, revealed: false };

      session.choices[userId] = choice;
      session.updatedAt = Date.now();

      const presence = getPresence(io, roomCode);
      if (Object.keys(session.choices).length === presence.length && presence.length === 2) {
        session.revealed = true;
        const choiceValues = Object.values(session.choices);
        const success = choiceValues.every((c) => c === choiceValues[0]);

        await redis.del(sessionKey);

        const event = {
          choices: session.choices,
          success,
          selected: success ? choiceValues[0] : null,
          at: Date.now(),
        };

        const stateText = await redis.get(roomKey(roomCode));
        const state = stateText ? JSON.parse(stateText) : defaultState;
        const nextState = { ...state, lastTelepathy: event, updatedAt: Date.now() };
        await redis.set(roomKey(roomCode), JSON.stringify(nextState));

        io.to(roomCode).emit("game:telepathy:result", event);
        ack({ ok: true, result: event });
      } else {
        await redis.set(sessionKey, JSON.stringify(session), "EX", 60);
        ack({ ok: true, waiting: true });
      }
    });

    socket.on("game:pirate:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

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

    socket.on("game:pirate:reset", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      await redis.del(pirateKey(roomCode));
      io.to(roomCode).emit("game:pirate:reset_done", { by: userId, at: Date.now() });
      ack({ ok: true });
    });

    socket.on("game:yut:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) {
        ack({ ok: false, reason: "need_two_players" });
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
      gameState.characters = parsed.data.characters ?? {};
      gameState.bgm = parsed.data.bgm ?? null;
      gameState.stake = parsed.data.stake ?? 0;

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

    socket.on("game:yut:roll_start", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

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

      if (gameState.phase === "order_countdown") {
        setTimeout(async () => {
          try {
            const latestText = await redis.get(yutGameKey(roomCode));
            if (!latestText) return;
            const latestState = JSON.parse(latestText);
            if (latestState.id !== gameState.id || latestState.phase !== "order_countdown") {
              return;
            }
            latestState.phase = "throwing";
            latestState.orderCountdownUntil = null;
            await redis.set(yutGameKey(roomCode), JSON.stringify(latestState), "EX", 3600);
            emitYutState(io, roomCode, "game:yut:started", latestState, {
              orderReady: true,
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

      const { rows: numericRows } = await query(
        'SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [userId]
      );
      const numericUserId = numericRows[0]?.UserId;
      const stats = numericUserId ? await getEquippedStats(numericUserId) : {};

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
      gameState.lastThrow = throwResult;

      // yut_win_coin_pct: 윷(4)/모(5) 투척 시 스테이크 % 보너스 코인 누적
      if (throwResult.result === 4 || throwResult.result === 5) {
        const winCoinPct = Math.min(stats.yut_win_coin_pct ?? 0, 15);
        if (winCoinPct > 0 && (gameState.stake ?? 0) > 0) {
          const bonus = Math.floor(gameState.stake * winCoinPct / 100);
          gameState.winCoinBonus = gameState.winCoinBonus ?? {};
          gameState.winCoinBonus[userId] = (gameState.winCoinBonus[userId] ?? 0) + bonus;
        }
      }

      const isNak = throwResult.result === -1 &&
        !hasBackdoMove(gameState.players[userId].pieces);
      throwResult.nak = isNak;

      if (!isNak) {
        gameState.pendingMoves.push(throwResult.result);
      }

      // New 윷/모 grants another bonus throw
      if (throwResult.bonusThrow) {
        gameState.hasBonusThrow = true;
      }

      if (isNak && gameState.pendingMoves.length === 0) {
        gameState.hasBonusThrow = false;
        gameState.currentTurn = getNextYutPlayer(gameState, userId);
        gameState.phase = "throwing";
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

      const gameText = await redis.get(yutGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }

      const gameState = JSON.parse(gameText);
      if (gameState.pendingMoves.length === 0) {
        ack({ ok: false, reason: "no_pending_moves" });
        return;
      }
      if (gameState.currentTurn !== userId) {
        ack({ ok: false, reason: "not_your_turn" });
        return;
      }

      const { pieceId, moveIndex, backdoDir } = parsed.data;
      if (moveIndex >= gameState.pendingMoves.length) {
        ack({ ok: false, reason: "invalid_move_index" });
        return;
      }

      const piece = gameState.players[userId].pieces[pieceId];
      if (!piece || piece.finished) {
        ack({ ok: false, reason: "invalid_piece" });
        return;
      }

      const steps = gameState.pendingMoves[moveIndex];
      if (steps === -1 && piece.position === 0) {
        ack({ ok: false, reason: "invalid_piece_for_move" });
        return;
      }

      const preMovePos = piece.position; // 백도 보너스 체크용 원래 위치 기록
      const moveResult = movePiece(piece, steps, { backdoDir });

      if (moveResult === null) {
        ack({ ok: false, reason: "invalid_move" });
        return;
      }
      gameState.pendingMoves.splice(moveIndex, 1);

      const carriedPieces = getCarriedPieces(piece, gameState.players[userId].pieces);
      const stackedPieces = moveResult.position > 0 && moveResult.position !== 20
        ? gameState.players[userId].pieces.filter(
            (candidate) =>
              candidate.id !== pieceId &&
              !candidate.finished &&
              candidate.position === moveResult.position,
          )
        : [];
      let capturedPieces = [];
      const moverStats = gameState.playerStats?.[userId] ?? {};
      const opponentId = getNextYutPlayer(gameState, userId);
      const defenderStats = gameState.playerStats?.[opponentId] ?? {};

      if (moveResult.finished) {
        for (const carriedPiece of carriedPieces) {
          carriedPiece.lastPos = moveResult.lastPos;
          carriedPiece.finished = true;
          carriedPiece.position = 20;
        }
      } else {
        for (const carriedPiece of carriedPieces) {
          carriedPiece.lastPos = moveResult.lastPos;
          carriedPiece.position = moveResult.position;
        }

        // piece_group_pct: chance to auto-pull one lonely friendly piece to current position
        const groupPct = Math.min(moverStats.piece_group_pct ?? 0, 15);
        if (groupPct > 0 && moveResult.position > 0 && moveResult.position !== 20) {
          const loner = gameState.players[userId].pieces.find(
            (p) => p.id !== pieceId && !p.finished && p.position > 0 && p.position !== moveResult.position,
          );
          if (loner && Math.random() * 100 < groupPct) {
            loner.position = moveResult.position;
            loner.lastPos = moveResult.lastPos;
            stackedPieces.push(loner);
          }
        }

        const rawCaptured = checkCatch(piece.position, gameState.players[opponentId].pieces);

        // piece_catch_resist_pct + piece_safe_zone_pct (defender): each piece independently resists
        const resistPct = Math.min((defenderStats.piece_catch_resist_pct ?? 0), 15);
        const safePct = Math.min((defenderStats.piece_safe_zone_pct ?? 0), 15);
        capturedPieces = rawCaptured.filter(() => {
          const survivedResist = resistPct > 0 && Math.random() * 100 < resistPct;
          const survivedSafe = safePct > 0 && Math.random() * 100 < safePct;
          return !survivedResist && !survivedSafe;
        });

        for (const capturedPiece of capturedPieces) {
          capturedPiece.position = 0;
          capturedPiece.lastPos = 0;
          capturedPiece.finished = false;
        }
        recordCapture(gameState, capturedPieces.length);

        // piece_catch_coin_bonus: 잡은 말 1개당 플랫 코인 (최대 25)
        const catchCoinPer = Math.min(Math.floor(moverStats.piece_catch_coin_bonus ?? 0), 25);
        if (catchCoinPer > 0 && capturedPieces.length > 0) {
          gameState.catchCoinBonus = gameState.catchCoinBonus ?? {};
          gameState.catchCoinBonus[userId] = (gameState.catchCoinBonus[userId] ?? 0) + catchCoinPer * capturedPieces.length;
        }

        // yut_catch_bonus: 잡기 이벤트당 플랫 코인, 잡은 말 수 무관 (최대 300)
        const catchFlatBonus = Math.min(Math.floor(moverStats.yut_catch_bonus ?? 0), 300);
        if (catchFlatBonus > 0 && capturedPieces.length > 0) {
          gameState.catchCoinBonus = gameState.catchCoinBonus ?? {};
          gameState.catchCoinBonus[userId] = (gameState.catchCoinBonus[userId] ?? 0) + catchFlatBonus;
        }
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
          }
        }
      }

      const won = checkWin(gameState.players[userId]);
      if (won) {
        gameState.winner = userId;
      } else {
        settleTurnAfterMove(gameState, userId);
      }

      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        pieceId,
        newPosition: piece.position,
        finished: piece.finished,
        movedPieceIds: carriedPieces.map((carriedPiece) => carriedPiece.id),
        capturedPieceIds: capturedPieces.map((capturedPiece) => capturedPiece.id),
        capturedCount: capturedPieces.length,
        carriedCount: carriedPieces.length,
        stackedCount: stackedPieces.length,
        winner: gameState.winner,
        at: Date.now(),
        ...serializeYutGame(gameState),
      };

      io.to(roomCode).emit("game:yut:move_result", event);
      ack({ ok: true, event });

      if (gameState.winner) {
        const yutLoserId = gameState.playersOrder.find(p => p !== gameState.winner);
        io.to(roomCode).emit("game:yut:ended", { winner: gameState.winner });
        await redis.del(yutGameKey(roomCode));
        const [{ rows: winnerRows }, { rows: loserRows }] = await Promise.all([
          query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [gameState.winner]),
          query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [yutLoserId]),
        ]);
        const winnerExtraBonus = (gameState.catchCoinBonus?.[gameState.winner] ?? 0)
          + (gameState.winCoinBonus?.[gameState.winner] ?? 0);
        const yutPreStreak = await _getWinStreak(roomCode, gameState.winner);
        await Promise.all([
          settleAndEmitWallet(io, roomCode, gameState.winner, yutLoserId, gameState.stake ?? 0, `yut:${roomCode}:${Date.now()}`, winnerRows[0]?.UserId, winnerExtraBonus, loserRows[0]?.UserId, yutPreStreak),
          saveGameResult(roomCode, gameState.winner, yutLoserId, 'yut', gameState.stake ?? 0),
          grantGameXpAndMissions(gameState.winner, yutLoserId, 'yut'),
        ]);
      }
    });

    socket.on("game:blackjack:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
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
      const gameState = initBlackjackGame(orderedPlayers[0], orderedPlayers[1]);
      await redis.set(`game:${roomCode}:blackjack`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:blackjack:updated", gameState);
      ack({ ok: true });
    });

    socket.on("game:blackjack:hit", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      const raw = await redis.get(`game:${roomCode}:blackjack`);
      if (!raw) {
        ack({ ok: false, reason: "no_game" });
        return;
      }
      let gameState = JSON.parse(raw);
      gameState = hitBlackjack(gameState, String(userId));
      await redis.set(`game:${roomCode}:blackjack`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:blackjack:updated", gameState);
      if (gameState.status === 'finished' && gameState.result?.winner && gameState.result.winner !== 'draw') {
        const loser = Object.keys(gameState.players).find(p => p !== gameState.result.winner);
        await saveGameResult(roomCode, gameState.result.winner, loser, 'blackjack', 0).catch(() => {});
        grantGameXpAndMissions(gameState.result.winner, loser, 'blackjack').catch(() => {});
      }
      ack({ ok: true });
    });

    socket.on("game:blackjack:stand", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      const raw = await redis.get(`game:${roomCode}:blackjack`);
      if (!raw) {
        ack({ ok: false, reason: "no_game" });
        return;
      }
      let gameState = JSON.parse(raw);
      gameState = standBlackjack(gameState, String(userId));
      await redis.set(`game:${roomCode}:blackjack`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:blackjack:updated", gameState);
      if (gameState.status === 'finished' && gameState.result?.winner && gameState.result.winner !== 'draw') {
        const loser = Object.keys(gameState.players).find(p => p !== gameState.result.winner);
        await saveGameResult(roomCode, gameState.result.winner, loser, 'blackjack', 0).catch(() => {});
        grantGameXpAndMissions(gameState.result.winner, loser, 'blackjack').catch(() => {});
      }
      ack({ ok: true });
    });

    socket.on("game:oldmaid:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
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
      const gameState = initOldMaidGame(orderedPlayers[0], orderedPlayers[1]);
      await redis.set(`game:${roomCode}:oldmaid`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:oldmaid:updated", gameState);
      ack({ ok: true });
    });

    socket.on("game:oldmaid:draw", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }
      const raw = await redis.get(`game:${roomCode}:oldmaid`);
      if (!raw) {
        ack({ ok: false, reason: "no_game" });
        return;
      }
      const cardId = payload?.cardId;
      if (!cardId) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }
      let gameState = JSON.parse(raw);
      gameState = drawOldMaidCard(gameState, String(userId), String(cardId));
      await redis.set(`game:${roomCode}:oldmaid`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:oldmaid:updated", gameState);
      if (gameState.status === 'finished' && gameState.result?.winner) {
        await saveGameResult(roomCode, gameState.result.winner, gameState.result.loser, 'oldmaid', 0).catch(() => {});
        grantGameXpAndMissions(gameState.result.winner, gameState.result.loser, 'oldmaid').catch(() => {});
      }
      ack({ ok: true });
    });

    // ── Penalty Shootout ──────────────────────────────────────────────────
    socket.on("game:penalty:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });
      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const gameState = {
        status: "playing",
        round: 1, // 1 ~ 10
        kicker: orderedPlayers[0],
        keeper: orderedPlayers[1],
        submissions: {},
        scores: { [orderedPlayers[0]]: 0, [orderedPlayers[1]]: 0 },
        rounds: [],
        result: null,
      };
      await redis.set(`game:${roomCode}:penalty`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:penalty:updated", gameState);
      ack({ ok: true });
    });

    socket.on("game:penalty:submit", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const raw = await redis.get(`game:${roomCode}:penalty`);
      if (!raw) return ack({ ok: false, reason: "no_game" });

      let gameState = JSON.parse(raw);
      if (gameState.status !== "playing") return ack({ ok: false, reason: "finished" });

      const choice = Number(payload?.choice);
      if (!Number.isInteger(choice)) return ack({ ok: false, reason: "invalid_choice" });

      gameState.submissions[String(userId)] = choice;

      const kickerId = String(gameState.kicker);
      const keeperId = String(gameState.keeper);

      if (
        gameState.submissions[kickerId] !== undefined &&
        gameState.submissions[keeperId] !== undefined
      ) {
        const kickerDir = gameState.submissions[kickerId]; // 0~8 (3x3)
        const keeperDir = gameState.submissions[keeperId]; // 0~8 (3x3 exact match)

        // Exact match required to save!
        const isSaved = kickerDir === keeperDir;
        const isGoal = !isSaved;

        if (isGoal) {
          gameState.scores[kickerId] = (gameState.scores[kickerId] || 0) + 1;
        }

        gameState.rounds.push({
          round: gameState.round,
          kicker: kickerId,
          keeper: keeperId,
          kickerDir,
          keeperDir,
          isGoal,
        });

        gameState.submissions = {};

        if (gameState.round >= 10) {
          gameState.status = "finished";
          const s1 = gameState.scores[kickerId];
          const s2 = gameState.scores[keeperId];
          let winner = "draw";
          if (s1 > s2) winner = kickerId;
          else if (s2 > s1) winner = keeperId;
          gameState.result = { winner, scores: gameState.scores };
        } else {
          gameState.round += 1;
          // Swap roles
          gameState.kicker = keeperId;
          gameState.keeper = kickerId;
        }
      }

      await redis.set(`game:${roomCode}:penalty`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:penalty:updated", gameState);
      if (gameState.status === 'finished' && gameState.result?.winner && gameState.result.winner !== 'draw') {
        const loser = Object.keys(gameState.scores).find(p => p !== gameState.result.winner);
        await saveGameResult(roomCode, gameState.result.winner, loser, 'penalty', 0).catch(() => {});
      }
      ack({ ok: true });
    });

    // ── Bowling ───────────────────────────────────────────────────────────
    socket.on("game:bowling:start", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });
      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const gameState = initBowlingGame(orderedPlayers[0], orderedPlayers[1]);
      await redis.set(`game:${roomCode}:bowling`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:bowling:updated", withBowlingFrames(gameState));
      ack({ ok: true });
    });

    socket.on("game:bowling:roll", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });
      const raw = await redis.get(`game:${roomCode}:bowling`);
      if (!raw) return ack({ ok: false, reason: "no_game" });

      let gameState = JSON.parse(raw);
      const pins = Math.min(10, Math.max(0, Number(payload?.pins) || 0));
      const clampUnit = (v) => Math.min(1, Math.max(-1, Number(v) || 0));
      gameState = rollBowlingFrame(gameState, String(userId), pins, {
        aim: clampUnit(payload?.aim),
        curve: clampUnit(payload?.curve),
      });

      await redis.set(`game:${roomCode}:bowling`, JSON.stringify(gameState), "EX", 3600);
      io.to(roomCode).emit("game:bowling:updated", withBowlingFrames(gameState));
      if (gameState.status === 'finished' && gameState.result?.winner && gameState.result.winner !== 'draw') {
        const loser = Object.keys(gameState.scores).find(p => p !== gameState.result.winner);
        await saveGameResult(roomCode, gameState.result.winner, loser, 'bowling', 0).catch(() => {});
      }
      ack({ ok: true });
    });

    socket.on("game:uno:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }

      const parsed = unoNewSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }
      const { mode } = parsed.data;

      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) {
        ack({ ok: false, reason: "need_two_players" });
        return;
      }

      const gameState = createUnoGameState(orderedPlayers, 7, { mode });
      gameState.stake = parsed.data.stake ?? 0;

      // 양 플레이어 스탯 미리 로드
      const unoPlayerStats = {};
      for (const code of orderedPlayers) {
        const { rows } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [code]);
        const numId = rows[0]?.UserId;
        unoPlayerStats[code] = numId ? await getEquippedStats(numId) : {};
      }
      gameState.playerStats = unoPlayerStats;

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      // Broadcast common info to room
      io.to(roomCode).emit("game:uno:started", {
        topCard: gameState.discardPile[gameState.discardPile.length - 1],
        currentPlayer: gameState.currentPlayer,
        mode: gameState.mode,
        declaredColor: gameState.declaredColor,
        drawStack: 0,
        drawStackType: null,
        handCount: getUnoHandCount(gameState),
      });

      // Send each player their private hand separately
      const sockets = await io.in(roomCode).fetchSockets();
      for (const sock of sockets) {
        const pid = sock.data.userId;
        if (gameState.hands[pid]) {
          sock.emit("game:uno:hand_update", { hand: gameState.hands[pid] });
        }
      }

      ack({ ok: true });
    });

    socket.on("game:uno:play", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = unoPlaySchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const gameText = await redis.get(unoGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }

      const gameState = JSON.parse(gameText);
      if (gameState.currentPlayer !== userId) {
        ack({ ok: false, reason: "not_your_turn" });
        return;
      }

      const { cardId, declaredColor } = parsed.data;
      const hand = gameState.hands[userId];
      const cardIndex = hand.findIndex((c) => c.id === cardId);

      if (cardIndex === -1) {
        ack({ ok: false, reason: "card_not_found" });
        return;
      }

      const card = hand[cardIndex];
      const topCard = gameState.discardPile[gameState.discardPile.length - 1];

      // Draw stack restriction: when stack is pending, only matching defense cards allowed
      const hasStack = (gameState.drawStack || 0) > 0 && gameState.drawStackType;
      if (hasStack) {
        if (!canPlayCard(
          card,
          topCard,
          gameState.declaredColor,
          gameState.drawStack,
          gameState.drawStackType,
          { mode: gameState.mode },
        )) {
          ack({ ok: false, reason: "must_draw_or_defend" });
          return;
        }
      } else if (!canPlayCard(card, topCard, gameState.declaredColor, 0, null, { mode: gameState.mode })) {
        ack({ ok: false, reason: "cannot_play_card" });
        return;
      }

      // Capture previous effective color (needed for +4 challenge tracking)
      const previousColor = gameState.declaredColor || topCard.color;

      // Remove card from hand. Discard All is a colored card: after the
      // trigger card is removed, all remaining cards of that color are also
      // discarded in current hand order.
      hand.splice(cardIndex, 1);
      const playedCards = gameState.mode === "go_wild"
        ? collectDiscardAllBatch(hand, card)
        : [card];
      for (const playedCard of playedCards) {
        gameState.discardPile.push(playedCard);
      }
      gameState.declaredColor = declaredColor || null;

      // Apply card effects in the same order the cards reached the discard pile.
      for (const playedCard of playedCards) {
        applyCardEffect(gameState, playedCard, previousColor);
      }

      // card_reverse_bonus: 리버스 카드 플레이 시 상대방이 1장 추가 드로우 (capped 20%)
      if (card.value === 'reverse') {
        const myPlayStats = gameState.playerStats?.[userId] ?? {};
        const reversePct = Math.min(myPlayStats.card_reverse_bonus ?? 0, 20);
        if (reversePct > 0 && Math.random() * 100 < reversePct) {
          const opponentId = gameState.players.find((p) => p !== userId);
          if (opponentId && gameState.hands[opponentId]) {
            const bonusCards = drawCards(gameState, 1);
            gameState.hands[opponentId].push(...bonusCards);
          }
        }
      }

      // Check win
      const won = checkUnoWin(gameState, userId);
      if (won) {
        gameState.winner = userId;
      }

      // Next turn
      if (!won) {
        gameState.currentPlayer = getNextPlayer(gameState);
      }

      // UNO call window: previous window from opponent is now expired
      if (gameState.unoCallNeeded && gameState.unoCallNeeded !== userId) {
        gameState.unoCallNeeded = null;
      }
      // Open new window if this player now has exactly 1 card
      if (!won && hand.length === 1) {
        gameState.unoCallNeeded = userId;
      }

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        card: playedCards[playedCards.length - 1],
        cards: playedCards,
        count: playedCards.length,
        mode: gameState.mode,
        declaredColor: gameState.declaredColor,
        nextPlayer: gameState.currentPlayer,
        drawStack: gameState.drawStack,
        drawStackType: gameState.drawStackType ?? null,
        handCount: getUnoHandCount(gameState),
        winner: gameState.winner,
        unoCallNeeded: gameState.unoCallNeeded ?? null,
        at: Date.now(),
      };

      io.to(roomCode).emit("game:uno:played", event);
      socket.emit("game:uno:hand_update", { hand: gameState.hands[userId] });

      // card_reverse_bonus 발동 시 상대방 핸드도 업데이트
      if (card.value === 'reverse') {
        const opponentForHand = gameState.players.find((p) => p !== userId);
        if (opponentForHand && gameState.hands[opponentForHand]) {
          const roomSockets = await io.in(roomCode).fetchSockets();
          for (const sock of roomSockets) {
            if (sock.data.userId === opponentForHand) {
              sock.emit("game:uno:hand_update", { hand: gameState.hands[opponentForHand] });
              break;
            }
          }
        }
      }

      ack({ ok: true, event });

      if (gameState.winner) {
        const unoLoserId = gameState.players.find(p => p !== gameState.winner);
        io.to(roomCode).emit("game:uno:ended", { winner: gameState.winner });
        await redis.del(unoGameKey(roomCode));
        const [{ rows: unoWinnerRows }, { rows: unoLoserRows }] = await Promise.all([
          query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [gameState.winner]),
          query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [unoLoserId]),
        ]);
        const unoPreStreak = await _getWinStreak(roomCode, gameState.winner);
        await Promise.all([
          settleAndEmitWallet(io, roomCode, gameState.winner, unoLoserId, gameState.stake ?? 0, `uno:${roomCode}:${Date.now()}`, unoWinnerRows[0]?.UserId, 0, unoLoserRows[0]?.UserId, unoPreStreak),
          saveGameResult(roomCode, gameState.winner, unoLoserId, 'uno', gameState.stake ?? 0),
          grantGameXpAndMissions(gameState.winner, unoLoserId, 'onecard'),
        ]);
      }
    });

    socket.on("game:uno:call", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }

      const gameText = await redis.get(unoGameKey(roomCode));
      if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }

      const gameState = JSON.parse(gameText);
      if (gameState.unoCallNeeded !== userId) {
        ack({ ok: false, reason: "not_needed" });
        return;
      }

      gameState.unoCallNeeded = null;
      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      io.to(roomCode).emit("game:uno:called", { by: userId });
      ack({ ok: true });
    });

    socket.on("game:uno:catch", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }

      const gameText = await redis.get(unoGameKey(roomCode));
      if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }

      const gameState = JSON.parse(gameText);
      const target = gameState.unoCallNeeded;
      if (!target || target === userId) {
        ack({ ok: false, reason: "no_target" });
        return;
      }

      // card_uno_protect_pct: target has % chance to avoid penalty (capped 15%)
      const targetUnoStats = gameState.playerStats?.[target] ?? {};
      const protectPct = Math.min(targetUnoStats.card_uno_protect_pct ?? 0, 15);
      if (protectPct > 0 && Math.random() * 100 < protectPct) {
        gameState.unoCallNeeded = null;
        await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);
        io.to(roomCode).emit("game:uno:penalty", {
          target,
          caughtBy: userId,
          count: 0,
          protected: true,
          handCount: getUnoHandCount(gameState),
        });
        ack({ ok: true, protected: true });
        return;
      }

      // Penalty: draw 2 cards for target
      const drawnCards = drawCards(gameState, 2);
      gameState.hands[target].push(...drawnCards);
      gameState.unoCallNeeded = null;

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      io.to(roomCode).emit("game:uno:penalty", {
        target,
        caughtBy: userId,
        count: 2,
        handCount: getUnoHandCount(gameState),
      });

      // Send updated hand to penalty target
      const sockets = await io.in(roomCode).fetchSockets();
      for (const sock of sockets) {
        if (sock.data.userId === target) {
          sock.emit("game:uno:hand_update", { hand: gameState.hands[target] });
          break;
        }
      }

      ack({ ok: true });
    });

    // +4 도전: 상대가 +4를 낼 자격이 있었는지 확인
    socket.on("game:uno:challenge", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false, reason: "not_joined" }); return; }

      const gameText = await redis.get(unoGameKey(roomCode));
      if (!gameText) { ack({ ok: false, reason: "no_game" }); return; }

      const gameState = JSON.parse(gameText);

      // Only allowed when draw4 stack is pending and it's the challenger's turn
      if (gameState.drawStackType !== "wild_draw4" || gameState.currentPlayer !== userId) {
        ack({ ok: false, reason: "cannot_challenge" });
        return;
      }

      const attackerPlayer = gameState.lastDraw4Player;
      const colorBefore = gameState.colorBeforeDraw4;

      if (!attackerPlayer || !colorBefore) {
        ack({ ok: false, reason: "no_challenge_data" });
        return;
      }

      // Did the attacker have a card of colorBefore? → challenge success
      const attackerHand = gameState.hands[attackerPlayer] ?? [];
      const challengeSuccess = hadPlayableCardOfColor(attackerHand, colorBefore);

      let drawnPlayer, drawnCount, nextPlayer;

      if (challengeSuccess) {
        // B의 도전 성공: A가 +4를 불법으로 냈음 → A가 4장 받기, B 턴 유지, 선언 색상 유지
        drawnCount = 4;
        drawnPlayer = attackerPlayer;
        nextPlayer = userId; // B(challenger)의 턴 유지
      } else {
        // B의 도전 실패: A가 정당하게 냈음 → B가 6장 받기(4장+벌칙2장), A 턴 유지
        drawnCount = 6;
        drawnPlayer = userId;
        nextPlayer = attackerPlayer; // A 턴 유지
      }

      const drawnCards = drawCards(gameState, drawnCount);
      gameState.hands[drawnPlayer].push(...drawnCards);
      clearDrawStack(gameState);
      gameState.currentPlayer = nextPlayer;
      // 선언 색상: 성공/실패 모두 A가 선언한 색상 유지 (공식 룰)
      // gameState.declaredColor는 이미 +4 플레이 시 설정된 상태로 유지

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      io.to(roomCode).emit("game:uno:challenged", {
        by: userId,
        challenged: attackerPlayer,
        success: challengeSuccess,
        drawnPlayer,
        drawnCount,
        nextPlayer,
        mode: gameState.mode,
        drawStack: 0,
        drawStackType: null,
        handCount: getUnoHandCount(gameState),
      });

      // Send updated hand to the player who drew
      const sockets = await io.in(roomCode).fetchSockets();
      for (const sock of sockets) {
        if (sock.data.userId === drawnPlayer) {
          sock.emit("game:uno:hand_update", { hand: gameState.hands[drawnPlayer] });
          break;
        }
      }

      ack({ ok: true, success: challengeSuccess });
    });

    socket.on("game:uno:reaction", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = unoReactionSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const gameText = await redis.get(unoGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }

      const event = {
        by: userId,
        type: parsed.data.type,
        at: Date.now(),
      };
      io.to(roomCode).emit("game:uno:reaction", event);
      ack({ ok: true, event });
    });

    // ── 모두 내기 (Discard All) ────────────────────────────────────────────────
    // Deprecated: Discard All is now a colored card handled by game:uno:play.
    socket.on("game:uno:discard_all", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      ack({ ok: false, reason: "discard_all_is_card" });
    });

    socket.on("game:uno:draw", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const gameText = await redis.get(unoGameKey(roomCode));
      if (!gameText) {
        ack({ ok: false, reason: "no_game" });
        return;
      }

      const gameState = JSON.parse(gameText);
      if (gameState.currentPlayer !== userId) {
        ack({ ok: false, reason: "not_your_turn" });
        return;
      }

      const myUnoStats = gameState.playerStats?.[userId] ?? {};
      let drawCount = (gameState.drawStack || 0) > 0 ? gameState.drawStack : 1;

      // card_shield_pct: chance to fully negate an attack draw stack (capped 15%)
      if (gameState.drawStack > 0) {
        const shieldPct = Math.min(myUnoStats.card_shield_pct ?? 0, 15);
        if (shieldPct > 0 && Math.random() * 100 < shieldPct) {
          drawCount = 0;
        }
      }

      // card_lucky_draw_pct: chance to draw 1 less card (capped 20%)
      if (drawCount > 1) {
        const luckyPct = Math.min(myUnoStats.card_lucky_draw_pct ?? 0, 20);
        if (luckyPct > 0 && Math.random() * 100 < luckyPct) {
          drawCount = Math.max(1, drawCount - 1);
        }
      }

      // onecard_draw_reduce: 보장된 드로우 감소 (최소 1장)
      const drawReduce = Math.floor(myUnoStats.onecard_draw_reduce ?? 0);
      if (drawReduce > 0 && drawCount > 1) {
        drawCount = Math.max(1, drawCount - drawReduce);
      }

      const drawnCards = drawCards(gameState, drawCount);
      gameState.hands[userId].push(...drawnCards);
      clearDrawStack(gameState);

      // Next turn
      gameState.currentPlayer = getNextPlayer(gameState);

      // UNO window expires when opponent takes their turn
      if (gameState.unoCallNeeded && gameState.unoCallNeeded !== userId) {
        gameState.unoCallNeeded = null;
      }

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        count: drawCount,
        nextPlayer: gameState.currentPlayer,
        mode: gameState.mode,
        declaredColor: gameState.declaredColor,
        drawStack: 0,
        drawStackType: null,
        handCount: getUnoHandCount(gameState),
        unoCallNeeded: gameState.unoCallNeeded ?? null,
      };

      io.to(roomCode).emit("game:uno:drawn", event);
      // Send updated hand privately to the player who drew
      socket.emit("game:uno:hand_update", { hand: gameState.hands[userId] });
      ack({ ok: true, event });
    });

    socket.on("game:bomb:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

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

      const gameState = createBombGameState(orderedPlayers, parsed.data.duration);
      await redis.set(bombGameKey(roomCode), JSON.stringify(gameState), "EX", 300);

      io.to(roomCode).emit("game:bomb:started", {
        currentPlayer: gameState.currentPlayer,
        duration: gameState.duration,
        startTime: gameState.startTime,
        quiz: {
          category: gameState.currentQuiz.category,
          question: gameState.currentQuiz.question,
        },
      });
      ack({ ok: true, gameState });
    });

    socket.on("game:bomb:answer", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

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
        gameState.loser = userId;
        const bombWinner = gameState.players.find(p => p !== userId);
        await redis.del(bombGameKey(roomCode));

        io.to(roomCode).emit("game:bomb:exploded", {
          loser: userId,
          correctAnswer: gameState.currentQuiz.answer,
        });
        if (bombWinner) {
          await saveGameResult(roomCode, bombWinner, userId, 'bomb', 0).catch(() => {});
        }
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
    });

    socket.on("game:restart:request", async (_, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false }); return; }

      socket.to(roomCode).emit("game:restart:requested", { by: userId });
      ack({ ok: true });
    });

    socket.on("game:restart:respond", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) { ack({ ok: false }); return; }

      const { accept, gameType } = payload || {};

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

      if (gameType === "yut") {
        const previousText = await redis.get(yutGameKey(roomCode));
        const previous = previousText ? JSON.parse(previousText) : {};
        const gameState = createYutGameState(p1, p2, {
          characters: previous.characters ?? {},
          bgm: previous.bgm ?? null,
        });
        gameState.stake = previous.stake ?? 0;
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
      } else if (gameType === "uno") {
        const previousText = await redis.get(unoGameKey(roomCode));
        const previous = previousText ? JSON.parse(previousText) : {};
        const gameState = createUnoGameState(orderedPlayers, 7, {
          mode: previous.mode ?? DEFAULT_UNO_MODE,
        });
        gameState.stake = previous.stake ?? 0;

        // 아이템 스탯 재적재
        const unoRestartStats = {};
        for (const code of orderedPlayers) {
          const { rows } = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [code]);
          const numId = rows[0]?.UserId;
          unoRestartStats[code] = numId ? await getEquippedStats(numId) : {};
        }
        gameState.playerStats = unoRestartStats;

        await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);
        io.to(roomCode).emit("game:uno:started", {
          topCard: gameState.discardPile[gameState.discardPile.length - 1],
          currentPlayer: gameState.currentPlayer,
          mode: gameState.mode,
          declaredColor: gameState.declaredColor,
          drawStack: 0,
          drawStackType: null,
          handCount: getUnoHandCount(gameState),
        });
        const sockets = await io.in(roomCode).fetchSockets();
        for (const sock of sockets) {
          const pid = sock.data.userId;
          if (gameState.hands[pid]) sock.emit("game:uno:hand_update", { hand: gameState.hands[pid] });
        }
      } else if (gameType === "bomb") {
        const gameState = createBombGameState(orderedPlayers, 30);
        await redis.set(bombGameKey(roomCode), JSON.stringify(gameState), "EX", 300);
        io.to(roomCode).emit("game:bomb:started", {
          currentPlayer: gameState.currentPlayer,
          duration: gameState.duration,
          startTime: gameState.startTime,
          quiz: { category: gameState.currentQuiz.category, question: gameState.currentQuiz.question },
        });
      }

      ack({ ok: true, accepted: true });
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

        // 로비 키는 game:lobby:start 처리 시 삭제되므로 presence에서 직접 players를 가져옴
        const players = await getOrderedPlayers(roomCode, getPresence(io, roomCode));
        if (players.length < 2) return ack({ error: "need_two_players" });

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
      } catch (err) {
        console.error("game:catch:start error", err);
        ack({ error: "server_error" });
      }
    });

    // draw relay — no ack for performance
    socket.on("game:catch:draw", (payload) => {
      const { roomCode } = socket.data;
      if (!roomCode) return;
      socket.to(roomCode).emit("game:catch:draw", payload);
    });

    // clear relay
    socket.on("game:catch:clear", () => {
      const { roomCode } = socket.data;
      if (!roomCode) return;
      socket.to(roomCode).emit("game:catch:clear");
    });

    socket.on("game:catch:guess", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      try {
        const { roomCode, userId } = socket.data;
        if (!roomCode) return ack({ ok: false });

        const text = String(payload?.text || "").trim();
        if (!text) return ack({ ok: false });

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

        const raw = await redis.get(`game:${roomCode}:catch`);
        if (!raw) return ack({ ok: false });
        const state = JSON.parse(raw);

        if (state.phase !== "drawing" || userId === state.drawer) return ack({ ok: false });

        const chars = [...state.word];
        const hidden = chars.map((_, i) => i).filter((i) => !state.hintRevealed.includes(i));
        if (hidden.length === 0) return ack({ ok: false });

        const revealIdx = hidden[Math.floor(Math.random() * hidden.length)];
        state.hintRevealed.push(revealIdx);
        await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

        const hint = chars.map((c, i) => (state.hintRevealed.includes(i) ? c : "_")).join("");

        // guesser(본인)에게만 전송
        socket.emit("game:catch:hint", { hint });
        ack({ ok: true });
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

        const raw = await redis.get(`game:${roomCode}:catch`);
        if (!raw) return ack({ ok: false });
        const state = JSON.parse(raw);

        if (state.phase !== "drawing") return ack({ ok: false });
        state.phase = "timeout";
        await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

        io.to(roomCode).emit("game:catch:timeout_result", { word: state.word });
        ack({ ok: true });
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

        const raw = await redis.get(`game:${roomCode}:catch`);
        if (!raw) return ack({ ok: false });
        const state = JSON.parse(raw);

        const nextRound = state.round + 1;

        if (nextRound > state.maxRounds) {
          // 게임 종료
          state.phase = "gameover";
          await redis.set(`game:${roomCode}:catch`, JSON.stringify(state), "EX", 86400);

          const entries = Object.entries(state.scores);
          const maxScore = Math.max(...entries.map(([, s]) => s));
          const winners = entries.filter(([, s]) => s === maxScore).map(([uid]) => uid);
          const winner = winners.length === 1 ? winners[0] : "draw";

          io.to(roomCode).emit("game:catch:gameover", { winner, scores: state.scores });
          if (winner !== 'draw') {
            const catchLoser = Object.keys(state.scores).find(p => p !== winner);
            if (catchLoser) {
              await saveGameResult(roomCode, winner, catchLoser, 'catch', 0).catch(() => {});
            }
          }
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

        await redis.del(`game:${roomCode}:catch`);
        io.to(roomCode).emit("game:catch:reset_done");
        ack({ ok: true });
      } catch (err) {
        console.error("game:catch:reset error", err);
        ack({ ok: false });
      }
    });

    // ── Tank 대작전 ─────────────────────────────────────────────────────────────
    const tankGameKey = (rc) => `game:${rc}:tank`;

    const tankNewSchema = z.object({
      stake: z.number().int().min(0).max(10000).optional().default(0),
    }).optional().default({ stake: 0 });

    socket.on("game:tank:new", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const parsed = tankNewSchema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const [p1, p2] = orderedPlayers;
      const stake = parsed.data?.stake ?? 0;
      const state = createFortressState(p1, p2, { stake });
      await redis.set(tankGameKey(roomCode), JSON.stringify(state), "EX", 7200);
      io.to(roomCode).emit("game:tank:started", state);
      ack({ ok: true });
    });

    socket.on("game:tank:move", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ delta: z.number().int().min(-10).max(10) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      const raw = await redis.get(tankGameKey(roomCode));
      if (!raw) return ack({ ok: false, reason: "no_game" });
      const state = JSON.parse(raw);

      const result = moveTank(state, userId, parsed.data.delta);
      if (!result.ok) return ack({ ok: false, reason: result.error });

      await redis.set(tankGameKey(roomCode), JSON.stringify(result.state), "EX", 7200);
      io.to(roomCode).emit("game:tank:updated", result.state);
      ack({ ok: true });
    });

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

      const raw = await redis.get(tankGameKey(roomCode));
      if (!raw) return ack({ ok: false, reason: "no_game" });
      const state = JSON.parse(raw);

      const result = aimTank(state, userId, parsed.data.angle, parsed.data.power);
      if (!result.ok) return ack({ ok: false, reason: result.error });

      await redis.set(tankGameKey(roomCode), JSON.stringify(result.state), "EX", 7200);
      // Aim updates go only to the shooter (others see on fire)
      socket.emit("game:tank:updated", result.state);
      ack({ ok: true });
    });

    socket.on("game:tank:weapon", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ weapon: z.enum(["basic", "heavy", "triple", "mole"]) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      const raw = await redis.get(tankGameKey(roomCode));
      if (!raw) return ack({ ok: false, reason: "no_game" });
      const state = JSON.parse(raw);

      const result = selectWeapon(state, userId, parsed.data.weapon);
      if (!result.ok) return ack({ ok: false, reason: result.error });

      await redis.set(tankGameKey(roomCode), JSON.stringify(result.state), "EX", 7200);
      io.to(roomCode).emit("game:tank:updated", result.state);
      ack({ ok: true });
    });

    socket.on("game:tank:fire", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const raw = await redis.get(tankGameKey(roomCode));
      if (!raw) return ack({ ok: false, reason: "no_game" });
      const state = JSON.parse(raw);

      const result = fireTank(state, userId);
      if (!result.ok) return ack({ ok: false, reason: result.error });

      if (result.state.winner) {
        const winnerId = result.state.winner;
        const loserId = result.state.players.find(p => p.id !== winnerId)?.id;
        const stake = result.state.stake ?? 0;
        await redis.del(tankGameKey(roomCode));
        io.to(roomCode).emit("game:tank:shot", result.shotResult);
        io.to(roomCode).emit("game:tank:ended", { winner: winnerId });
        if (loserId) {
          await Promise.all([
            settleAndEmitWallet(io, roomCode, winnerId, loserId, stake, `tank:${roomCode}:${Date.now()}`),
            saveGameResult(roomCode, winnerId, loserId, 'tank', stake),
            grantGameXpAndMissions(winnerId, loserId, 'tank'),
          ]);
        }
      } else {
        await redis.set(tankGameKey(roomCode), JSON.stringify(result.state), "EX", 7200);
        io.to(roomCode).emit("game:tank:shot", result.shotResult);
        io.to(roomCode).emit("game:tank:updated", result.state);
      }
      ack({ ok: true });
    });

    // ── 고스톱 (2인 맞고) ──────────────────────────────────────────────
    // 상대 손패 숨김이 필요하므로 per-viewer 직렬화로 개별 emit
    const gostopGameKey = (rc) => `gostop:${rc}:game`;

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

    // 종료 처리: 정산(올인 캡 내장) + 전적 저장 + ended emit
    const finishGostop = async (roomCode, state) => {
      await redis.del(gostopGameKey(roomCode));
      emitGostop("game:gostop:ended", state);
      const st = state.settlement;
      if (st && st.amount > 0) {
        await Promise.all([
          settleAndEmitWallet(io, roomCode, st.winnerId, st.loserId, st.amount, `gostop:${roomCode}:${Date.now()}`),
          saveGameResult(roomCode, st.winnerId, st.loserId, 'gostop', st.amount),
          grantGameXpAndMissions(st.winnerId, st.loserId, 'gostop'),
        ]);
      }
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
        });
        next.firstPlayerIdx = state.firstPlayerIdx;
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

      const presence = getPresence(io, roomCode);
      if (presence.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const schema = z.object({
        perPointBet: z.union([z.literal(100), z.literal(500), z.literal(1000)]).optional().default(100),
      });
      const parsed = schema.safeParse(payload ?? {});
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

      const orderedPlayers = await getOrderedPlayers(roomCode, presence);
      if (orderedPlayers.length !== 2) return ack({ ok: false, reason: "need_two_players" });

      const [p1, p2] = orderedPlayers;
      const state = createGostopGameState(p1, p2, { perPointBet: parsed.data.perPointBet });
      state.firstPlayerIdx = state.currentPlayerIdx; // 나가리 선 유지용

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

    socket.on("game:gostop:play", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ cardId: z.string().min(1) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

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

    socket.on("game:gostop:pick", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ fieldCardId: z.string().min(1) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

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

    socket.on("game:gostop:gostop", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const schema = z.object({ decision: z.enum(["go", "stop"]) });
      const parsed = schema.safeParse(payload);
      if (!parsed.success) return ack({ ok: false, reason: "invalid_payload" });

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

    // 재접속 복원용 현재 상태 조회
    socket.on("game:gostop:state", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const { roomCode, userId } = socket.data;
      if (!roomCode || !userId) return ack({ ok: false, reason: "not_joined" });

      const raw = await redis.get(gostopGameKey(roomCode));
      if (!raw) return ack({ ok: false, reason: "no_game" });
      ack({ ok: true, state: serializeGostopFor(JSON.parse(raw), userId) });
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

      // 가위바위보 진행 중 연결 끊기면 미완료 판 취소
      redis.del(rpsGameKey(roomCode)).then(() => {
        io.to(roomCode).emit("game:rps:cancelled", {
          reason: "player_disconnected",
          by: socket.data.userId,
        });
      }).catch((err) => console.error(`rps cancel error: ${err.message}`));
    });
  });
};
