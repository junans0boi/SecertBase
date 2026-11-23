import express from 'express';
import { AccessContextError, getAuthenticatedActor } from '../../shared/access-context.js';
import { DatePlanError } from './domain.js';

const errorResponse = (res, error, operation) => {
  if (error instanceof DatePlanError) {
    return res.status(error.status).json({ ok: false, reason: error.reason });
  }
  if (error instanceof AccessContextError) {
    const status = error.code === 'AUTH_REQUIRED' ? 401 : 403;
    return res.status(status).json({ ok: false, error: { code: error.code } });
  }
  console.error(`[API] ${operation} error:`, error);
  return res.status(500).json({ ok: false, reason: 'internal_error' });
};

export function createDatePlanRouter({ service }) {
  if (!service) throw new Error('Date-plan router requires a service');
  const router = express.Router();

  const route = (operation, handler) => async (req, res) => {
    try {
      const actor = getAuthenticatedActor(req);
      return await handler(actor, req, res);
    } catch (error) {
      return errorResponse(res, error, operation);
    }
  };

  router.post('/date-plans', route('POST /date-plans', async (actor, req, res) => (
    res.status(201).json({ ok: true, plan: await service.create(actor, req.body ?? {}) })
  )));

  router.get('/date-plans', route('GET /date-plans', async (actor, req, res) => (
    res.json({
      ok: true,
      ...(await service.list(actor, {
        scope: req.query.scope, cursor: req.query.cursor, limit: req.query.limit,
      })),
    })
  )));

  router.get('/date-plans/:id', route('GET /date-plans/:id', async (actor, req, res) => (
    res.json({ ok: true, plan: await service.get(actor, req.params.id) })
  )));

  router.patch('/date-plans/:id', route('PATCH /date-plans/:id', async (actor, req, res) => (
    res.json({ ok: true, plan: await service.update(actor, req.params.id, req.body ?? {}) })
  )));

  router.delete('/date-plans/:id', route('DELETE /date-plans/:id', async (actor, req, res) => {
    await service.remove(actor, req.params.id);
    return res.json({ ok: true });
  }));

  router.post('/date-plans/:id/complete', route('POST /date-plans/:id/complete', async (actor, req, res) => (
    res.json({ ok: true, ...(await service.complete(actor, req.params.id)) })
  )));

  return router;
}
