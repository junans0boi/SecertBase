import { z } from "zod";
import { config } from "./config.js";
import { query } from "./db.js";
import { redis } from "./redis.js";
import {
  throwYut,
  movePiece,
  createYutGameState,
  checkWin,
  checkCatch,
  getCarriedPieces,
  getNextPlayer as getNextYutPlayer,
  serializeYutGame,
} from "./yut-engine.js";
import {
  createUnoGameState,
  canPlayCard,
  drawCards,
  applyCardEffect,
  clearDrawStack,
  hadPlayableCardOfColor,
  getNextPlayer,
  checkWin as checkUnoWin,
} from "./uno-engine.js";
import {
  createBombGameState,
  checkAnswer,
  isTimeUp,
  passBomb,
} from "./bomb-engine.js";

const joinSchema = z.object({
  userId: z.string().min(1),
  roomCode: z.string().min(1).max(24),
  roomSecret: z.string().min(1),
  profileEmoji: z.string().min(1).max(16).optional(),
});

const profileSchema = z.object({
  profileEmoji: z.string().min(1).max(16),
});

const gameTypes = [
  "dice",
  "roulette",
  "rps",
  "telepathy",
  "pirate",
  "yut",
  "uno",
  "bomb",
];

const lobbySchema = z.object({
  gameType: z.enum(gameTypes),
});

const rouletteSchema = z.object({
  options: z.array(z.string().min(1)).min(2).max(12),
});

const rpsSchema = z.object({
  choice: z.enum(["rock", "paper", "scissors"]),
});

const telepathySchema = z.object({
  choice: z.string().min(1),
  options: z.array(z.string().min(1)).min(2).max(10),
});

const pirateSchema = z.object({
  slots: z.number().int().min(4).max(12),
});

const yutMoveSchema = z.object({
  pieceId: z.number().int().min(0).max(3),
});

const unoPlaySchema = z.object({
  cardId: z.string().min(1),
  declaredColor: z.preprocess(
    (value) => (value === null ? undefined : value),
    z.enum(["red", "yellow", "green", "blue"]).optional(),
  ),
});

const bombAnswerSchema = z.object({
  answer: z.string().min(1),
});

const bombNewSchema = z.object({
  duration: z.number().int().min(10).max(120).optional().default(30),
});

const roomKey = (roomCode) => `room:${roomCode}:state`;
const yutGameKey = (roomCode) => `yut:${roomCode}:game`;
const unoGameKey = (roomCode) => `uno:${roomCode}:game`;
const bombGameKey = (roomCode) => `bomb:${roomCode}:game`;
const gameLobbyKey = (roomCode, gameType) => `lobby:${roomCode}:${gameType}`;

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
  return [...room].map((socketId) => io.sockets.sockets.get(socketId)?.data?.userId).filter(Boolean);
};

const getPresenceProfiles = (io, roomCode) => {
  const room = io.sockets.adapter.rooms.get(roomCode);
  if (!room) {
    return {};
  }

  return Object.fromEntries(
    [...room]
      .map((socketId) => io.sockets.sockets.get(socketId))
      .filter(Boolean)
      .map((sock) => [sock.data.userId, sock.data.profileEmoji])
      .filter(([userId, emoji]) => userId && emoji),
  );
};

const emitPresence = (io, roomCode) => {
  io.to(roomCode).emit("room:presence", {
    roomCode,
    users: getPresence(io, roomCode),
    profileEmojis: getPresenceProfiles(io, roomCode),
  });
};

const normalizeLobby = (lobby, presence) => {
  const players = (lobby?.players ?? []).filter((player) => presence.includes(player));
  const host = players.includes(lobby?.host) ? lobby.host : (players[0] ?? null);
  return {
    gameType: lobby?.gameType,
    host,
    players,
    updatedAt: Date.now(),
  };
};

const emitLobby = (io, roomCode, lobby) => {
  io.to(roomCode).emit("game:lobby:updated", {
    ...lobby,
    profileEmojis: getPresenceProfiles(io, roomCode),
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

const getRoomMembers = async (roomCode, roomSecret) => {
  const result = await query(
    `SELECT c.RoomCode, c.RoomSecret, u1.UserCode AS User1Code, u2.UserCode AS User2Code
     FROM Couples c
     JOIN Users u1 ON c.User1Id = u1.UserId
     JOIN Users u2 ON c.User2Id = u2.UserId
     WHERE c.RoomCode = ? AND c.RoomSecret = ?`,
    [roomCode, roomSecret],
  );

  if (result.rows.length === 0) {
    return null;
  }

  const room = result.rows[0];
  return [room.User1Code, room.User2Code];
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
  io.on("connection", (socket) => {
    socket.on("session:join", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const parsed = joinSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { userId, roomCode, roomSecret, profileEmoji } = parsed.data;
      const roomMembers = await getRoomMembers(roomCode, roomSecret);
      const isLegacyRoom = roomSecret === config.ROOM_SECRET;

      if (!roomMembers && !isLegacyRoom) {
        ack({ ok: false, reason: "invalid_secret" });
        return;
      }
      if (roomMembers && !roomMembers.includes(userId)) {
        ack({ ok: false, reason: "forbidden_user" });
        return;
      }

      const presence = getPresence(io, roomCode);
      if (presence.length >= 2 && !presence.includes(userId)) {
        ack({ ok: false, reason: "room_full" });
        return;
      }

      socket.data.userId = userId;
      socket.data.roomCode = roomCode;
      socket.data.profileEmoji = profileEmoji ?? "🙂";
      await socket.join(roomCode);

      const stateText = await redis.get(roomKey(roomCode));
      const state = stateText ? JSON.parse(stateText) : defaultState;

      emitPresence(io, roomCode);

      ack({ ok: true, state });
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

      const { gameType } = parsed.data;
      const key = gameLobbyKey(roomCode, gameType);
      const presence = getPresence(io, roomCode);
      const lobbyText = await redis.get(key);
      const baseLobby = lobbyText ? JSON.parse(lobbyText) : { gameType, host: null, players: [] };
      const lobby = normalizeLobby({ ...baseLobby, gameType }, presence);

      if (!lobby.players.includes(userId)) {
        lobby.players.push(userId);
      }
      if (!lobby.host) {
        lobby.host = userId;
      }
      lobby.updatedAt = Date.now();

      await redis.set(key, JSON.stringify(lobby), "EX", 1800);
      emitLobby(io, roomCode, lobby);
      ack({ ok: true, lobby: { ...lobby, profileEmojis: getPresenceProfiles(io, roomCode) } });
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

      await redis.del(key);
      io.to(roomCode).emit("game:lobby:started", {
        gameType,
        host: lobby.host,
        players: lobby.players,
        profileEmojis: getPresenceProfiles(io, roomCode),
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
          if (game.p1 && game.p2) {
            activeGames.yut = {
              gameId: game.gameId,
              turn: game.turn,
              p1Pieces: game.p1.pieces ?? [],
              p2Pieces: game.p2.pieces ?? [],
            };
          }
        }

        if (unoGame) {
          const game = JSON.parse(unoGame);
          const userId = socket.data.userId;
          if (game.p1 && game.p2) {
            activeGames.uno = {
              gameId: game.gameId,
              turn: game.turn,
              topCard: game.topCard,
              p1Count: game.p1.hand?.length ?? 0,
              p2Count: game.p2.hand?.length ?? 0,
              hand: userId === "p1" ? (game.p1.hand ?? []) : (game.p2.hand ?? []),
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

    socket.on("game:rps:select", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = rpsSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { choice } = parsed.data;
      const sessionKey = `rps:${roomCode}:session`;
      const existing = await redis.get(sessionKey);
      const session = existing ? JSON.parse(existing) : { choices: {}, revealed: false };

      session.choices[userId] = choice;
      session.updatedAt = Date.now();

      const presence = getPresence(io, roomCode);
      if (Object.keys(session.choices).length === presence.length && presence.length === 2) {
        session.revealed = true;
        const [user1, user2] = Object.keys(session.choices);
        const choice1 = session.choices[user1];
        const choice2 = session.choices[user2];

        let winner = null;
        if (choice1 === choice2) {
          winner = "draw";
        } else if (
          (choice1 === "rock" && choice2 === "scissors") ||
          (choice1 === "scissors" && choice2 === "paper") ||
          (choice1 === "paper" && choice2 === "rock")
        ) {
          winner = user1;
        } else {
          winner = user2;
        }

        session.winner = winner;
        await redis.del(sessionKey);

        const event = {
          choices: session.choices,
          winner,
          at: Date.now(),
        };

        const stateText = await redis.get(roomKey(roomCode));
        const state = stateText ? JSON.parse(stateText) : defaultState;
        const nextState = { ...state, lastRps: event, updatedAt: Date.now() };
        await redis.set(roomKey(roomCode), JSON.stringify(nextState));

        io.to(roomCode).emit("game:rps:result", event);
        ack({ ok: true, result: event });
      } else {
        await redis.set(sessionKey, JSON.stringify(session), "EX", 60);
        ack({ ok: true, waiting: true });
      }
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

    socket.on("game:pirate:spin", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const roomCode = socket.data.roomCode;
      const userId = socket.data.userId;
      if (!roomCode || !userId) {
        ack({ ok: false, reason: "not_joined" });
        return;
      }

      const parsed = pirateSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { slots } = parsed.data;
      const bombSlot = Math.floor(Math.random() * slots);
      const event = {
        slots,
        bombSlot,
        by: userId,
        at: Date.now(),
      };

      const stateText = await redis.get(roomKey(roomCode));
      const state = stateText ? JSON.parse(stateText) : defaultState;
      const nextState = { ...state, lastPirate: event, updatedAt: Date.now() };
      await redis.set(roomKey(roomCode), JSON.stringify(nextState));

      io.to(roomCode).emit("game:pirate:result", event);
      ack({ ok: true, event });
    });

    socket.on("game:yut:new", async (_, ackRaw) => {
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
      const gameState = createYutGameState(player1, player2);
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
      if (gameState.phase !== "throwing") {
        ack({ ok: false, reason: "must_move_first" });
        return;
      }

      const throwResult = throwYut();
      gameState.lastThrow = throwResult;
      gameState.pendingMoves.push(throwResult.result);
      if (!throwResult.bonusThrow) {
        gameState.phase = "moving";
      }

      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      emitYutState(io, roomCode, "game:yut:throw_result", gameState, {
        by: userId,
        throwResult,
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

      const { pieceId } = parsed.data;
      const piece = gameState.players[userId].pieces[pieceId];
      if (!piece || piece.finished) {
        ack({ ok: false, reason: "invalid_piece" });
        return;
      }

      const steps = gameState.pendingMoves.shift();
      const moveResult = movePiece(piece, steps);

      if (moveResult === null) {
        ack({ ok: false, reason: "invalid_move" });
        return;
      }

      const carriedPieces = getCarriedPieces(piece, gameState.players[userId].pieces);
      if (moveResult.position >= 20) {
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
        const opponentId = getNextYutPlayer(gameState, userId);
        const capturedPieces = checkCatch(piece.position, gameState.players[opponentId].pieces);
        for (const capturedPiece of capturedPieces) {
          capturedPiece.position = 0;
          capturedPiece.lastPos = 0;
          capturedPiece.finished = false;
        }
        gameState.lastCaptureCount = capturedPieces.length;
      }

      const won = checkWin(gameState.players[userId]);
      if (won) {
        gameState.winner = userId;
      } else if (gameState.pendingMoves.length === 0) {
        const caughtOpponent = (gameState.lastCaptureCount ?? 0) > 0;
        gameState.currentTurn = caughtOpponent ? userId : getNextYutPlayer(gameState, userId);
        gameState.phase = "throwing";
      } else {
        gameState.phase = "moving";
      }
      gameState.lastCaptureCount = 0;

      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        pieceId,
        newPosition: piece.position,
        finished: piece.finished,
        movedPieceIds: carriedPieces.map((carriedPiece) => carriedPiece.id),
        winner: gameState.winner,
        ...serializeYutGame(gameState),
      };

      io.to(roomCode).emit("game:yut:move_result", event);
      ack({ ok: true, event });

      if (gameState.winner) {
        io.to(roomCode).emit("game:yut:ended", { winner: gameState.winner });
        await redis.del(yutGameKey(roomCode));
      }
    });

    socket.on("game:uno:new", async (_, ackRaw) => {
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

      const gameState = createUnoGameState(orderedPlayers);
      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      // Broadcast common info to room
      io.to(roomCode).emit("game:uno:started", {
        topCard: gameState.discardPile[gameState.discardPile.length - 1],
        currentPlayer: gameState.currentPlayer,
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
        if (!canPlayCard(card, topCard, gameState.declaredColor, gameState.drawStack, gameState.drawStackType)) {
          ack({ ok: false, reason: "must_draw_or_defend" });
          return;
        }
      } else if (!canPlayCard(card, topCard, gameState.declaredColor)) {
        ack({ ok: false, reason: "cannot_play_card" });
        return;
      }

      // Capture previous effective color (needed for +4 challenge tracking)
      const previousColor = gameState.declaredColor || topCard.color;

      // Remove card from hand
      hand.splice(cardIndex, 1);
      gameState.discardPile.push(card);
      gameState.declaredColor = declaredColor || null;

      // Apply card effect (pass previousColor for draw4 tracking)
      applyCardEffect(gameState, card, previousColor);

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
        card,
        declaredColor: gameState.declaredColor,
        nextPlayer: gameState.currentPlayer,
        drawStack: gameState.drawStack,
        drawStackType: gameState.drawStackType ?? null,
        handCount: getUnoHandCount(gameState),
        winner: gameState.winner,
        unoCallNeeded: gameState.unoCallNeeded ?? null,
      };

      io.to(roomCode).emit("game:uno:played", event);
      // Send updated hand privately to the player who played
      socket.emit("game:uno:hand_update", { hand: gameState.hands[userId] });
      ack({ ok: true, event });

      if (gameState.winner) {
        io.to(roomCode).emit("game:uno:ended", { winner: gameState.winner });
        await redis.del(unoGameKey(roomCode));
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
        // Attacker draws 6 (penalty for illegal +4)
        drawnCount = 6;
        drawnPlayer = attackerPlayer;
        nextPlayer = userId; // challenger gets their turn
      } else {
        // Challenger draws 6 (4 base + 2 fail penalty)
        drawnCount = 6;
        drawnPlayer = userId;
        nextPlayer = attackerPlayer; // challenger loses turn, attacker continues
      }

      const drawnCards = drawCards(gameState, drawnCount);
      gameState.hands[drawnPlayer].push(...drawnCards);
      clearDrawStack(gameState);
      gameState.currentPlayer = nextPlayer;
      gameState.declaredColor = challengeSuccess ? null : gameState.declaredColor;

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      io.to(roomCode).emit("game:uno:challenged", {
        by: userId,
        challenged: attackerPlayer,
        success: challengeSuccess,
        drawnPlayer,
        drawnCount,
        nextPlayer,
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

      const drawCount = (gameState.drawStack || 0) > 0 ? gameState.drawStack : 1;
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
        await redis.del(bombGameKey(roomCode));

        io.to(roomCode).emit("game:bomb:exploded", {
          loser: userId,
          correctAnswer: gameState.currentQuiz.answer,
        });
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
        const gameState = createYutGameState(p1, p2);
        await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);
        emitYutState(io, roomCode, "game:yut:started", gameState);
      } else if (gameType === "uno") {
        const gameState = createUnoGameState(orderedPlayers);
        await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);
        io.to(roomCode).emit("game:uno:started", {
          topCard: gameState.discardPile[gameState.discardPile.length - 1],
          currentPlayer: gameState.currentPlayer,
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
    });
  });
};
