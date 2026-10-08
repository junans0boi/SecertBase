import { createServer } from 'node:http';
import { Server } from 'socket.io';
import { createApp } from './create-app.js';

export function createRealtimeServer({
  app,
  config,
  redis,
  routes,
  registerSocketHandlers,
  createHttpServer = createServer,
  SocketServer = Server,
} = {}) {
  if (!config || !redis || !registerSocketHandlers) {
    throw new TypeError(
      'createRealtimeServer requires config, redis, and registerSocketHandlers',
    );
  }
  const application =
    app ?? createApp({ config, redis, routes });
  const httpServer = createHttpServer(application);
  const io = new SocketServer(httpServer, {
    cors: {
      origin: config.CORS_ORIGIN,
      credentials: true,
    },
    transports: ['websocket'],
  });

  application.locals.io = io;
  registerSocketHandlers(io);

  return {
    app: application,
    httpServer,
    io,
    async close() {
      await new Promise((resolve) => io.close(() => resolve()));
      if (httpServer.listening) {
        await new Promise((resolve) => httpServer.close(() => resolve()));
      }
    },
  };
}
