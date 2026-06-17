import { z } from "zod";
import { config } from "./config.js";
import { redis } from "./redis.js";
import { throwYut, movePiece, createYutGameState, checkWin } from "./yut-engine.js";
import {
  createUnoGameState,
  canPlayCard,
  drawCards,
  applyCardEffect,
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
  declaredColor: z.enum(["red", "yellow", "green", "blue"]).optional(),
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

export const registerSocketHandlers = (io) => {
  io.on("connection", (socket) => {
    socket.on("session:join", async (payload, ackRaw) => {
      const ack = normalizeAck(ackRaw);
      const parsed = joinSchema.safeParse(payload);
      if (!parsed.success) {
        ack({ ok: false, reason: "invalid_payload" });
        return;
      }

      const { userId, roomCode, roomSecret } = parsed.data;
      if (roomSecret !== config.ROOM_SECRET) {
        ack({ ok: false, reason: "invalid_secret" });
        return;
      }
      if (!config.ALLOWED_USERS.includes(userId)) {
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
      await socket.join(roomCode);

      const stateText = await redis.get(roomKey(roomCode));
      const state = stateText ? JSON.parse(stateText) : defaultState;

      io.to(roomCode).emit("room:presence", {
        roomCode,
        users: getPresence(io, roomCode),
      });

      ack({ ok: true, state });
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
          activeGames.yut = {
            gameId: game.gameId,
            turn: game.turn,
            p1Pieces: game.p1.pieces,
            p2Pieces: game.p2.pieces,
          };
        }

        if (unoGame) {
          const game = JSON.parse(unoGame);
          const userId = socket.data.userId;
          activeGames.uno = {
            gameId: game.gameId,
            turn: game.turn,
            topCard: game.topCard,
            p1Count: game.p1.hand.length,
            p2Count: game.p2.hand.length,
            hand: userId === "p1" ? game.p1.hand : game.p2.hand,
          };
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
        log.error(`session:restore error: ${err.message}`);
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

      const [player1, player2] = presence;
      const gameState = createYutGameState(player1, player2);
      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      io.to(roomCode).emit("game:yut:started", {
        players: presence,
        currentTurn: gameState.currentTurn,
      });
      ack({ ok: true, gameState });
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

      const throwResult = throwYut();
      gameState.lastThrow = throwResult;
      gameState.pendingMoves.push(throwResult.result);

      if (!throwResult.bonusThrow) {
        // No bonus, next player's turn
        const presence = getPresence(io, roomCode);
        gameState.currentTurn = presence.find((p) => p !== userId);
      }

      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      io.to(roomCode).emit("game:yut:throw_result", {
        by: userId,
        throwResult,
        pendingMoves: gameState.pendingMoves,
        currentTurn: gameState.currentTurn,
      });
      ack({ ok: true, throwResult, pendingMoves: gameState.pendingMoves });
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

      const { pieceId } = parsed.data;
      const piece = gameState.players[userId].pieces[pieceId];
      if (!piece || piece.finished) {
        ack({ ok: false, reason: "invalid_piece" });
        return;
      }

      const steps = gameState.pendingMoves.shift();
      const newPosition = movePiece(piece.position, steps);

      if (newPosition === null) {
        ack({ ok: false, reason: "invalid_move" });
        return;
      }

      if (newPosition >= 20) {
        piece.finished = true;
        piece.position = 20;
      } else {
        piece.position = newPosition;
      }

      const won = checkWin(gameState.players[userId]);
      if (won) {
        gameState.winner = userId;
      }

      await redis.set(yutGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        pieceId,
        newPosition: piece.position,
        finished: piece.finished,
        winner: gameState.winner,
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

      const gameState = createUnoGameState(presence);
      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      // Send game state to each player separately (hide opponent's hand)
      presence.forEach((player) => {
        const playerView = {
          ...gameState,
          hands: {
            [player]: gameState.hands[player],
            opponent: gameState.hands[presence.find((p) => p !== player)].map(() => "hidden"),
          },
        };
        io.to(roomCode).emit("game:uno:started", {
          topCard: gameState.discardPile[gameState.discardPile.length - 1],
          currentPlayer: gameState.currentPlayer,
          handCount: {
            [player]: gameState.hands[player].length,
            opponent: gameState.hands[presence.find((p) => p !== player)].length,
          },
        });
      });

      ack({ ok: true, hand: gameState.hands[userId] });
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

      if (!canPlayCard(card, topCard, gameState.declaredColor)) {
        ack({ ok: false, reason: "cannot_play_card" });
        return;
      }

      // Remove card from hand
      hand.splice(cardIndex, 1);
      gameState.discardPile.push(card);
      gameState.declaredColor = declaredColor || null;

      // Apply card effect
      applyCardEffect(gameState, card);

      // Check win
      const won = checkUnoWin(gameState, userId);
      if (won) {
        gameState.winner = userId;
      }

      // Next turn
      if (!won) {
        gameState.currentPlayer = getNextPlayer(gameState);
      }

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        card,
        declaredColor: gameState.declaredColor,
        nextPlayer: gameState.currentPlayer,
        drawStack: gameState.drawStack,
        winner: gameState.winner,
      };

      io.to(roomCode).emit("game:uno:played", event);
      ack({ ok: true, event });

      if (gameState.winner) {
        io.to(roomCode).emit("game:uno:ended", { winner: gameState.winner });
        await redis.del(unoGameKey(roomCode));
      }
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

      const drawCount = gameState.drawStack > 0 ? gameState.drawStack : 1;
      const drawnCards = drawCards(gameState, drawCount);
      gameState.hands[userId].push(...drawnCards);
      gameState.drawStack = 0;

      // Next turn
      gameState.currentPlayer = getNextPlayer(gameState);

      await redis.set(unoGameKey(roomCode), JSON.stringify(gameState), "EX", 3600);

      const event = {
        by: userId,
        count: drawCount,
        nextPlayer: gameState.currentPlayer,
      };

      io.to(roomCode).emit("game:uno:drawn", event);
      ack({ ok: true, drawnCards, event });
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

      const gameState = createBombGameState(presence, parsed.data.duration);
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

    socket.on("disconnect", () => {
      const roomCode = socket.data.roomCode;
      if (!roomCode) {
        return;
      }
      io.to(roomCode).emit("room:presence", {
        roomCode,
        users: getPresence(io, roomCode),
      });
    });
  });
};
