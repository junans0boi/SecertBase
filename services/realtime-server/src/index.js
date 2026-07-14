import cors from "cors";
import express from "express";
import { createServer } from "node:http";
import { Server } from "socket.io";
import { config } from "./config.js";
import { redis } from "./redis.js";
import { registerSocketHandlers } from "./socket.js";
import apiRoutes from "./routes.js";

const app = express();
app.use(cors({ origin: config.CORS_ORIGIN, credentials: true }));
app.use(express.json());

// Static files (uploads)
app.use('/uploads', express.static('uploads'));

// Health check
app.get("/health", async (_, res) => {
  try {
    await redis.ping();
    res.status(200).json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

// REST API routes (Phase 3)
app.use('/api', apiRoutes);

const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: config.CORS_ORIGIN,
    credentials: true,
  },
  transports: ["websocket"],
});
app.locals.io = io;

registerSocketHandlers(io);

server.listen(config.PORT, () => {
  console.log(`Secret Base realtime server listening on :${config.PORT}`);
  console.log(`REST API available at http://localhost:${config.PORT}/api`);
});
