import express from 'express';
import { AccessContextError, getAuthenticatedActor } from '../../shared/access-context.js';
import { NotesError } from './domain.js';

const errorResponse = (res, error, operation) => {
  if (error instanceof NotesError) {
    return res.status(error.status).json({ ok: false, reason: error.reason });
  }
  if (error instanceof AccessContextError) {
    const status = error.code === 'AUTH_REQUIRED' ? 401 : 403;
    return res.status(status).json({ ok: false, error: { code: error.code } });
  }
  console.error(`[API] ${operation} error:`, error?.message);
  return res.status(500).json({ ok: false, reason: 'internal_error' });
};

export function createNotesRouter({ service, uploadStore, sendLimiter = (_req, _res, next) => next() }) {
  if (!service) throw new Error('Notes router requires a service');
  if (!uploadStore?.middleware) throw new Error('Notes router requires an upload store');

  const router = express.Router();
  const route = (operation, handler) => async (req, res) => {
    try {
      return await handler(getAuthenticatedActor(req), req, res);
    } catch (error) {
      return errorResponse(res, error, operation);
    }
  };

  router.get('/notes', route('GET /notes', async (actor, req, res) =>
    res.json({ ok: true, ...(await service.list(actor, req.query)) })));

  router.get('/notes/unread', route('GET /notes/unread', async (actor, _req, res) =>
    res.json({ ok: true, ...(await service.unread(actor)) })));

  // 사진 1장(multipart `media`) 또는 JSON. 레이트리밋이 업로드 파싱보다 먼저다.
  router.post('/notes', sendLimiter, (req, res) => {
    uploadStore.middleware.single('media')(req, res, async (uploadError) => {
      if (uploadError) {
        await uploadStore.remove(req.file).catch(() => {});
        const error = new NotesError(uploadError.code === 'LIMIT_FILE_SIZE' ? 413 : 400,
          uploadError.code === 'LIMIT_FILE_SIZE' ? 'media_too_large' : 'invalid_media');
        return errorResponse(res, error, 'POST /notes');
      }
      return route('POST /notes', async (actor) => {
        const { note, created } = await service.send(actor, req.body ?? {}, req.file);
        return res.status(created ? 201 : 200).json({ ok: true, note });
      })(req, res);
    });
  });

  router.post('/notes/read', route('POST /notes/read', async (actor, req, res) =>
    res.json({ ok: true, ...(await service.markRead(actor, req.body)) })));

  router.delete('/notes/:id', route('DELETE /notes/:id', async (actor, req, res) =>
    res.json(await service.remove(actor, req.params.id))));

  router.post('/notes/:id/reaction', route('POST /notes/:id/reaction', async (actor, req, res) =>
    res.json({ ok: true, ...(await service.react(actor, req.params.id, req.body)) })));

  return router;
}
