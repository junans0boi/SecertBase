import { z } from "zod";
import { config } from "./config.js";
import { redis } from "./redis.js";

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

const roomKey = (roomCode) => `room:${roomCode}:state`;

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
