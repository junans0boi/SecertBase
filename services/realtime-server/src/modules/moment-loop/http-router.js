import express from 'express';
import multer from 'multer';
import fs from 'node:fs';
import path from 'node:path';
import { normalizeMomentClip } from '../../moment-clip.js';
import { AccessContextError, getAuthenticatedActor } from '../../shared/access-context.js';
import {
  MOMENT_MEDIA_MAX_BYTES,
  MomentLoopError,
} from './domain.js';

const filePathFor = (file, uploadsRoot) => file?.path || (file?.filename
  ? path.join(uploadsRoot, file.filename)
  : null);

export function createMomentUploadStore({
  config,
  fsImpl = fs,
  normalizeClip = normalizeMomentClip,
} = {}) {
  if (!config?.UPLOADS_ROOT) throw new Error('Moment upload store requires UPLOADS_ROOT');

  const storage = multer.diskStorage({
    destination: (req, file, callback) => callback(null, config.UPLOADS_ROOT),
    filename: (req, file, callback) => {
      const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1E9)}`;
      const extension = file.mimetype?.split('/')[1] || 'bin';
      callback(null, `${file.fieldname}-${uniqueSuffix}.${extension}`);
    },
  });

  const middleware = multer({
    storage,
    limits: { fileSize: MOMENT_MEDIA_MAX_BYTES },
    fileFilter: (req, file, callback) => callback(null, true),
  });

  const remove = async (file) => {
    const target = filePathFor(file, config.UPLOADS_ROOT);
    if (!target) return;
    await fsImpl.promises.rm(target, { force: true });
  };

  return {
    middleware,
    async prepare(file) {
      if (!file) return null;
      if (file.mimetype?.startsWith('video/')) {
        const normalizedPath = await normalizeClip(file.path);
        file.path = normalizedPath;
        file.filename = path.basename(normalizedPath);
        file.mimetype = 'video/mp4';
        return {
          file,
          mediaType: 'video',
          mediaUrl: `/uploads/${file.filename}`,
        };
      }
      return {
        file,
        mediaType: 'image',
        mediaUrl: `/uploads/${file.filename}`,
      };
    },
    remove,
    async removeByUrl(mediaUrl) {
      const filename = path.basename(String(mediaUrl || ''));
      if (!filename) return;
      await fsImpl.promises.rm(path.join(config.UPLOADS_ROOT, filename), { force: true });
    },
  };
}

const errorResponse = (res, error, operation) => {
  if (error instanceof MomentLoopError) {
    return res.status(error.status).json({ ok: false, reason: error.reason });
  }
  if (error instanceof AccessContextError) {
    const status = error.code === 'AUTH_REQUIRED' ? 401 : 403;
    return res.status(status).json({ ok: false, error: { code: error.code } });
  }
  console.error(`[API] ${operation} error:`, error);
  return res.status(500).json({ ok: false, reason: 'internal_error' });
};

export function createMomentLoopRouter({ service, uploadStore }) {
  if (!service) throw new Error('MomentLoop router requires a service');
  if (!uploadStore?.middleware) throw new Error('MomentLoop router requires an upload store');

  const router = express.Router();

  const route = (operation, handler) => async (req, res) => {
    try {
      const actor = getAuthenticatedActor(req);
      return await handler(actor, req, res);
    } catch (error) {
      return errorResponse(res, error, operation);
    }
  };

  const uploadRoute = (operation, handler) => (req, res) => {
    uploadStore.middleware.single('media')(req, res, async (uploadError) => {
      if (uploadError) {
        await uploadStore.remove(req.file).catch(() => {});
        const error = uploadError.code === 'LIMIT_FILE_SIZE'
          ? new MomentLoopError(413, 'media_too_large')
          : new MomentLoopError(400, 'invalid_media_upload');
        return errorResponse(res, error, operation);
      }
      return route(operation, handler)(req, res);
    });
  };

  router.get('/setlog', route('GET /setlog', async (actor, req, res) => {
    const posts = await service.listFeed(actor, req.query.month);
    return res.json({ ok: true, posts });
  }));

  router.post('/setlog', uploadRoute('POST /setlog', async (actor, req, res) => {
    const post = await service.createMoment(actor, req.body, req.file);
    return res.status(201).json({ ok: true, post });
  }));

  router.post('/setlog/reaction', route('POST /setlog/reaction', async (actor, req, res) => {
    const reactions = await service.toggleReaction(actor, req.body);
    return res.json({ ok: true, reactions });
  }));

  router.patch('/setlog/:id', route('PATCH /setlog/:id', async (actor, req, res) => {
    const post = await service.updateMoment(actor, req.params.id, req.body);
    return res.json({ ok: true, post });
  }));

  router.delete('/setlog/:id', route('DELETE /setlog/:id', async (actor, req, res) => {
    await service.deleteMoment(actor, req.params.id);
    return res.json({ ok: true });
  }));

  router.get('/retention/today', route('GET /retention/today', async (actor, req, res) => {
    return res.json(await service.readToday(actor));
  }));

  router.post('/retention/today/view', route('POST /retention/today/view', async (actor, req, res) => {
    return res.json(await service.markTodayViewed(actor));
  }));

  router.get('/retention/beta/summary', route('GET /retention/beta/summary', async (actor, req, res) => {
    return res.json(await service.summarize(actor, req.query.days));
  }));

  router.put('/retention/today/moment', route('PUT /retention/today/moment', async (actor, req, res) => {
    return res.json(await service.selectToday(actor, req.body.post_id));
  }));

  router.delete('/retention/today/moment', route('DELETE /retention/today/moment', async (actor, req, res) => {
    return res.json(await service.removeToday(actor));
  }));

  return router;
}
