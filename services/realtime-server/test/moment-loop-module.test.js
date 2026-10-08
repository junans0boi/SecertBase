import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import express from 'express';
import test from 'node:test';
import {
  MOMENT_MEDIA_MAX_BYTES,
  MomentLoopError,
  resolveMomentScope,
} from '../src/modules/moment-loop/domain.js';
import { MomentLoopService } from '../src/modules/moment-loop/application.js';
import { createMomentLoopRouter } from '../src/modules/moment-loop/http-router.js';

const couple = { CoupleId: 7, User1Id: 1, User2Id: 2 };

const fakeMedia = () => ({
  prepared: [],
  removed: [],
  removedUrls: [],
  async prepare(file) {
    this.prepared.push(file);
    return {
      file,
      mediaType: file.mimetype.startsWith('video/') ? 'video' : 'image',
      mediaUrl: `/uploads/${file.filename}`,
    };
  },
  async remove(file) {
    this.removed.push(file);
  },
  async removeByUrl(url) {
    this.removedUrls.push(url);
  },
});

const fakeRepository = (overrides = {}) => ({
  resolveActiveCouple: async () => couple,
  getUserCode: async () => 'USER01',
  listFeed: async () => [],
  findMapPin: async () => null,
  createMoment: async () => ({ id: 10 }),
  toggleReaction: async () => [],
  findMoment: async () => ({ id: 10, user_id: 1, couple_id: 7 }),
  updateMoment: async () => ({ id: 10 }),
  deleteMoment: async () => '/uploads/moment.jpg',
  readToday: async () => ({ rows: [], viewedAt: null }),
  markTodayViewed: async () => null,
  summary: async () => ({ days: 7, row: {} }),
  selectTodayMoment: async () => {},
  removeToday: async () => false,
  ...overrides,
});

const actor = (userId = 1) => ({ userId, userCode: `USER0${userId}` });

test('resolveMomentScope only returns an active couple scope containing the actor', () => {
  assert.deepEqual(resolveMomentScope(actor(1), couple), {
    userId: 1,
    coupleId: 7,
    userCode: 'USER01',
    partnerUserId: 2,
  });
  assert.throws(
    () => resolveMomentScope(actor(3), couple),
    (error) => error instanceof MomentLoopError
      && error.status === 403
      && error.reason === 'active_couple_required',
  );
  assert.throws(
    () => resolveMomentScope(actor(1), null),
    (error) => error.status === 409 && error.reason === 'active_couple_required',
  );
});

test('MomentLoop feed is scoped to the actor active couple', async () => {
  let feedArgs;
  const repository = fakeRepository({
    listFeed: async (args) => {
      feedArgs = args;
      return [{ id: 1, user_id: 1, couple_id: 7 }];
    },
  });
  const service = MomentLoopService({ repository, media: fakeMedia() });

  const posts = await service.listFeed(actor(2), '2026-07');

  assert.deepEqual(feedArgs, { coupleId: 7, viewerUserId: 2, month: '2026-07' });
  assert.deepEqual(posts, [{ id: 1, user_id: 1, couple_id: 7 }]);
});

test('MomentLoop partner cannot edit or delete the author moment', async () => {
  let updateCalled = false;
  let deleteCalled = false;
  const repository = fakeRepository({
    updateMoment: async () => { updateCalled = true; },
    deleteMoment: async () => { deleteCalled = true; return '/uploads/nope'; },
  });
  const service = MomentLoopService({ repository, media: fakeMedia() });

  await assert.rejects(
    service.updateMoment(actor(2), 10, { caption: 'tampered' }),
    (error) => error.status === 403 && error.reason === 'moment_author_required',
  );
  await assert.rejects(
    service.deleteMoment(actor(2), 10),
    (error) => error.status === 403 && error.reason === 'moment_author_required',
  );
  assert.equal(updateCalled, false);
  assert.equal(deleteCalled, false);
});

test('MomentLoop rejects oversized and unsupported media before persistence', async () => {
  let createCalled = false;
  const repository = fakeRepository({
    createMoment: async () => { createCalled = true; },
  });
  const media = fakeMedia();
  const service = MomentLoopService({ repository, media });
  const fields = { caption: 'clip', media_type: 'video', taken_at: '2026-07-15' };

  await assert.rejects(
    service.createMoment(actor(), fields, {
      filename: 'large.mp4',
      mimetype: 'video/mp4',
      size: MOMENT_MEDIA_MAX_BYTES + 1,
    }),
    (error) => error.status === 413 && error.reason === 'media_too_large',
  );
  await assert.rejects(
    service.createMoment(actor(), fields, {
      filename: 'document.pdf',
      mimetype: 'application/pdf',
      size: 10,
    }),
    (error) => error.status === 415 && error.reason === 'unsupported_media_type',
  );
  assert.equal(createCalled, false);
  assert.deepEqual(media.prepared, []);
});

test('MomentLoop preserves clip normalization errors as 422 domain errors', async () => {
  const media = fakeMedia();
  media.prepare = async () => {
    throw new Error('clip_too_long');
  };
  const service = MomentLoopService({ repository: fakeRepository(), media });

  await assert.rejects(
    service.createMoment(actor(), {
      caption: 'clip',
      media_type: 'video',
      taken_at: '2026-07-15',
    }, {
      filename: 'long.mp4',
      mimetype: 'video/mp4',
      size: 10,
    }),
    (error) => error instanceof MomentLoopError
      && error.status === 422
      && error.reason === 'clip_too_long',
  );
  assert.equal(media.removed.length, 1);
});

test('MomentLoop delete removes database record and its media after author check', async () => {
  const media = fakeMedia();
  const service = MomentLoopService({ repository: fakeRepository(), media });

  assert.equal(await service.deleteMoment(actor(), 10), true);
  assert.deepEqual(media.removedUrls, ['/uploads/moment.jpg']);
});

test('MomentLoop router maps domain errors to stable JSON responses', async () => {
  const app = express();
  app.use(express.json());
  app.use((req, res, next) => {
    req.auth = { userId: 1, userCode: 'USER01' };
    next();
  });
  const uploadStore = {
    middleware: { single: () => (req, res, next) => next() },
    remove: async () => {},
  };
  const router = createMomentLoopRouter({
    service: {
      listFeed: async () => {
        throw new MomentLoopError(409, 'today_loop_locked');
      },
    },
    uploadStore,
  });
  app.use(router);
  const server = createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  try {
    const response = await fetch(`http://127.0.0.1:${port}/setlog`);
    assert.equal(response.status, 409);
    assert.deepEqual(await response.json(), {
      ok: false,
      reason: 'today_loop_locked',
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('MomentLoop router returns 422 for an overlong clip', async () => {
  const app = express();
  app.use(express.json());
  app.use((req, res, next) => {
    req.auth = { userId: 1, userCode: 'USER01' };
    next();
  });
  const media = fakeMedia();
  media.prepare = async () => {
    throw new Error('clip_too_long');
  };
  const service = MomentLoopService({ repository: fakeRepository(), media });
  const uploadStore = {
    middleware: {
      single: () => (req, res, next) => {
        req.body = {
          caption: 'clip',
          media_type: 'video',
          taken_at: '2026-07-15',
        };
        req.file = {
          filename: 'long.mp4',
          mimetype: 'video/mp4',
          size: 10,
        };
        next();
      },
    },
    remove: async () => {},
  };
  app.use(createMomentLoopRouter({ service, uploadStore }));
  const server = createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  try {
    const response = await fetch(`http://127.0.0.1:${port}/setlog`, {
      method: 'POST',
      body: new URLSearchParams(),
    });
    assert.equal(response.status, 422);
    assert.deepEqual(await response.json(), {
      ok: false,
      reason: 'clip_too_long',
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
