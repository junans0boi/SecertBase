import assert from 'node:assert/strict';
import { mkdtemp, rm, stat, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import express from 'express';
import sharp from 'sharp';
import { createApp } from '../src/app/create-app.js';

async function withApp(fn) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'secretbase-thumbs-'));
  const app = createApp({
    config: { CORS_ORIGIN: [], UPLOADS_ROOT: root, PUBLIC_FEATURE_SET: 'mvp' },
    redis: { ping: async () => 'PONG' },
    routes: express.Router(),
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn({ root, base });
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await rm(root, { recursive: true, force: true });
  }
}

test('a 1920px upload is served as a small cached WebP thumbnail', async () => {
  await withApp(async ({ root, base }) => {
    const name = '1730000000000-123456789.jpg';
    const jpeg = await sharp({
      create: { width: 1920, height: 1440, channels: 3, background: '#e9967a' },
    }).jpeg({ quality: 85 }).toBuffer();
    await writeFile(path.join(root, name), jpeg);

    const res = await fetch(`${base}/uploads/w/480/${name}`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-type'), 'image/webp');
    assert.match(res.headers.get('cache-control'), /immutable/);
    const body = Buffer.from(await res.arrayBuffer());
    const meta = await sharp(body).metadata();
    assert.equal(meta.width, 480);
    assert.ok(body.length < jpeg.length / 5, `${body.length} vs ${jpeg.length}`);
    // Stored for the next request.
    await stat(path.join(root, '.thumbs', 'w480', `${name}.webp`));

    // The original is cached for a year too (names are unique).
    const orig = await fetch(`${base}/uploads/${name}`);
    assert.equal(orig.status, 200);
    assert.match(orig.headers.get('cache-control'), /max-age=31536000/);
  });
});

test('thumbnail URL falls back safely', async () => {
  await withApp(async ({ root, base }) => {
    await writeFile(path.join(root, 'clip.mp4'), 'not really a video');
    await writeFile(path.join(root, 'broken.jpg'), 'not an image');

    const video = await fetch(`${base}/uploads/w/480/clip.mp4`, { redirect: 'manual' });
    assert.equal(video.status, 302);
    assert.equal(video.headers.get('location'), '/uploads/clip.mp4');

    const broken = await fetch(`${base}/uploads/w/160/broken.jpg`, { redirect: 'manual' });
    assert.equal(broken.status, 302);

    assert.equal((await fetch(`${base}/uploads/w/333/broken.jpg`)).status, 404);
    assert.equal((await fetch(`${base}/uploads/w/160/missing.jpg`)).status, 404);
    assert.equal((await fetch(`${base}/uploads/w/160/..%2Fsecret.jpg`)).status, 404);
    assert.equal((await fetch(`${base}/uploads/.thumbs/w160/x.webp`)).status, 404);
  });
});
