import { z } from "zod";
import { config } from "./config.js";
import { installSocketFeatureGate } from "./backend-access.js";
import { query } from "./db.js";
import { redis } from "./redis.js";
import {
  throwYut,
  movePiece,
  createYutGameState,
  checkWin,
  checkCatch,
  getCarriedPieces,
  hasBackdoMove,
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

const joinSchema = z.object({
  userId: z.string().min(1),
  roomCode: z.string().min(1).max(24),
  roomSecret: z.string().min(1),
  profileEmoji: z.string().min(1).max(16).optional(),
  nickname: z.string().max(50).optional(),
});

const profileSchema = z.object({
  profileEmoji: z.string().min(1).max(16),
});

const gameTypes = [
  "dice",
  "roulette",
  "rps",
  "zero",
  "telepathy",
  "pirate",
  "yut",
  "uno",
  "uno_classic",
  "uno_go_wild",
  "bomb",
  "catch",
];

const lobbySchema = z.object({
  gameType: z.enum(gameTypes),
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
  })
  .optional()
  .default({ characters: {}, bgm: null });

const unoNewSchema = z
  .object({
    mode: z.enum(UNO_MODES).optional().default(DEFAULT_UNO_MODE),
  })
  .optional()
  .default({ mode: DEFAULT_UNO_MODE });

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

const roomKey = (roomCode) => `room:${roomCode}:state`;
const yutGameKey = (roomCode) => `yut:${roomCode}:game`;
const unoGameKey = (roomCode) => `uno:${roomCode}:game`;
const bombGameKey = (roomCode) => `bomb:${roomCode}:game`;
const gameLobbyKey = (roomCode, gameType) => `lobby:${roomCode}:${gameType}`;
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
    installSocketFeatureGate(socket, config.PUBLIC_FEATURE_SET);
    socket.on("session:join", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const parsed = joinSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { userId, roomCode, roomSecret, profileEmoji, nickname } = parsed.data;
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
      socket.data.nickname = nickname ?? userId;
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
      ack({ ok: true, lobby: { ...lobby, profileEmojis: getPresenceProfiles(io, roomCode), nicknames: getPresenceNicknames(io, roomCode) } });
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
          }
        : {};
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
    const rpsGameKey = (rc) => `rps:${rc}:game`;
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

      const isNak = throwResult.result === -1 &&
        !hasBackdoMove(gameState.players[userId].pieces);
      throwResult.nak = isNak;

      if (!isNak) {
        gameState.pendingMoves.push(throwResult.result);
      }

      if (isNak && gameState.pendingMoves.length === 0) {
        gameState.currentTurn = getNextYutPlayer(gameState, userId);
        gameState.phase = "throwing";
      } else if (!throwResult.bonusThrow) {
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

      const { pieceId, moveIndex } = parsed.data;
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

      const moveResult = movePiece(piece, steps);

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
        const opponentId = getNextYutPlayer(gameState, userId);
        capturedPieces = checkCatch(piece.position, gameState.players[opponentId].pieces);
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
        io.to(roomCode).emit("game:yut:ended", { winner: gameState.winner });
        await redis.del(yutGameKey(roomCode));
      }
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
        const previousText = await redis.get(yutGameKey(roomCode));
        const previous = previousText ? JSON.parse(previousText) : {};
        const gameState = createYutGameState(p1, p2, {
          characters: previous.characters ?? {},
          bgm: previous.bgm ?? null,
        });
        await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);
        emitYutState(io, roomCode, "game:yut:started", gameState);
      } else if (gameType === "uno") {
        const previousText = await redis.get(unoGameKey(roomCode));
        const previous = previousText ? JSON.parse(previousText) : {};
        const gameState = createUnoGameState(orderedPlayers, 7, {
          mode: previous.mode ?? DEFAULT_UNO_MODE,
        });
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
