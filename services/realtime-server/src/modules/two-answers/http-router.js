import express from 'express';
import { AccessContextError, getAuthenticatedActor } from '../../shared/access-context.js';
import { TwoAnswersError } from './domain.js';

const errorResponse = (res, error, operation) => {
  if (error instanceof TwoAnswersError) {
    return res.status(error.status).json({ ok: false, reason: error.reason });
  }
  if (error instanceof AccessContextError) {
    const status = error.code === 'AUTH_REQUIRED' ? 401 : 403;
    return res.status(status).json({ ok: false, error: { code: error.code } });
  }
  console.error(`[API] ${operation} error:`, error);
  return res.status(500).json({ ok: false, reason: 'internal_error' });
};

export function createTwoAnswersRouter({ service }) {
  if (!service) throw new Error('Two-answers router requires a service');
  const router = express.Router();

  const route = (operation, handler) => async (req, res) => {
    try {
      const actor = getAuthenticatedActor(req);
      return await handler(actor, req, res);
    } catch (error) {
      return errorResponse(res, error, operation);
    }
  };

  router.get('/two-answers/today', route('GET /two-answers/today', async (actor, req, res) => (
    res.json({ ok: true, today: await service.getToday(actor) })
  )));

  router.put('/two-answers/today/answer', route('PUT /two-answers/today/answer', async (actor, req, res) => (
    res.json({ ok: true, today: await service.answerToday(actor, req.body?.body) })
  )));

  router.get('/two-answers/history', route('GET /two-answers/history', async (actor, req, res) => (
    res.json({
      ok: true,
      ...(await service.listHistory(actor, { cursor: req.query.cursor, limit: req.query.limit })),
    })
  )));

  router.get('/two-answers/missed', route('GET /two-answers/missed', async (actor, req, res) => (
    res.json({ ok: true, items: await service.listMissed(actor) })
  )));

  router.post('/two-answers/:id/answer-late', route('POST /two-answers/:id/answer-late', async (actor, req, res) => (
    res.json({ ok: true, question: await service.answerLate(actor, req.params.id, req.body?.body) })
  )));

  return router;
}
