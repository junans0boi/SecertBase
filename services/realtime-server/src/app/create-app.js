import cors from 'cors';
import express from 'express';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { setUploadResponseHeaders } from '../shared/upload-safety.js';
import { thumbHandler } from '../shared/upload-thumbs.js';

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

  app.disable('x-powered-by');
  // 리버스 프록시(nginx/Caddy) 한 단계를 신뢰해 req.ip가 실제 클라이언트 IP가 되게 한다.
  app.set('trust proxy', 1);
  app.use((_, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    next();
  });

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
    // Small WebP copies for lists and thumbnails (made on first request).
    app.get('/uploads/w/:width/:file', thumbHandler(config.UPLOADS_ROOT));
    // Upload names are unique, so browsers may keep them for a year.
    app.use('/uploads', express.static(config.UPLOADS_ROOT, {
      dotfiles: 'ignore',
      immutable: true,
      maxAge: '365d',
      setHeaders: setUploadResponseHeaders,
    }));
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
