import cors from 'cors';
import express from 'express';
import { mkdirSync } from 'node:fs';

export function createApp({
  config,
  redis,
  routes,
} = {}) {
  if (!config || !redis || !routes) {
    throw new TypeError('createApp requires config, redis, and routes');
  }
  if (config.UPLOADS_ROOT) {
    mkdirSync(config.UPLOADS_ROOT, { recursive: true });
  }

  const app = express();
  app.locals.config = config;
  app.locals.redis = redis;

  app.use(cors({ origin: config.CORS_ORIGIN, credentials: true }));
  app.use(express.json());

  if (config.UPLOADS_ROOT) {
    app.use('/uploads', express.static(config.UPLOADS_ROOT));
  }

  app.get('/health', async (_, res) => {
    try {
      await redis.ping();
      res.status(200).json({ ok: true });
    } catch (error) {
      res.status(500).json({ ok: false, error: error.message });
    }
  });

  app.use('/api', routes);
  return app;
}
