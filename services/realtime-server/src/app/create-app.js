import cors from 'cors';
import express from 'express';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const legalWebRoot = fileURLToPath(new URL('../../../../apps/secret_base_app/web/', import.meta.url));

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

  for (const [route, aliases] of [
    ['privacy', ['privacy.html']],
    ['terms', ['terms.html']],
    ['delete-account', ['delete-account.html', 'account-deletion.html']],
  ]) {
    app.get([`/${route}`, ...aliases.map(alias => `/${alias}`)], (_, res) => {
      res.sendFile(`${route}/index.html`, { root: legalWebRoot });
    });
  }
  app.use('/legal', express.static(`${legalWebRoot}/legal`));

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
