import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import express from 'express';
import { createApp } from '../src/app/create-app.js';

const webRoot = new URL('../../../apps/secret_base_app/web/', import.meta.url);
const pages = [
  ['privacy', '개인정보 처리방침', ['privacy.html']],
  ['terms', '이용약관', ['terms.html']],
  ['delete-account', '계정 삭제 요청', ['delete-account.html', 'account-deletion.html']],
];

async function withServer(app, body) {
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try {
    await body(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

for (const [route, title, aliases] of pages) {
  test(`Express serves /${route} and aliases without authentication or SPA fallback`, async () => {
    const app = createApp({
      config: { CORS_ORIGIN: [] },
      redis: { ping: async () => 'PONG' },
      routes: express.Router(),
    });
    app.use((_, res) => res.status(404).send('SPA fallback'));
    await withServer(app, async base => {
      for (const url of [`/${route}`, `/${route}/`, ...aliases.map(alias => `/${alias}`)]) {
        const response = await fetch(`${base}${url}`);
        assert.equal(response.status, 200, url);
        assert.match(response.headers.get('content-type'), /text\/html/);
        const html = await response.text();
        assert.ok(html.includes(`<h1>${title}</h1>`), url);
        assert.ok(html.includes(`href="https://secretbase.cloud/${route}"`));
        assert.ok(!html.includes('flutter_bootstrap.js'));
      }
    });
  });

  test(`Flutter static directory /${route} contains the same legal document as aliases`, async () => {
    const expected = await readFile(new URL(`${route}/index.html`, webRoot), 'utf8');
    for (const alias of aliases) {
      assert.equal(await readFile(new URL(alias, webRoot), 'utf8'), expected);
    }
    const app = express();
    app.use(express.static(webRoot.pathname));
    app.use((_, res) => res.send('SPA fallback'));
    await withServer(app, async base => {
      for (const url of [`/${route}`, `/${route}/`]) {
        const response = await fetch(`${base}${url}`);
        assert.equal(await response.text(), expected);
      }
    });
  });
}

test('privacy draft describes actual collection and retention limitations', async () => {
  const html = await readFile(new URL('privacy/index.html', webRoot), 'utf8');
  for (const text of ['법률 검토 미완료', '생년월일', '사진', '영상', '장소', '푸시 토큰', '심리검사', '상담', '출생', '30세대', '완전 파기', '운영자', '미확인']) {
    assert.ok(html.includes(text), text);
  }
  assert.ok(!html.includes('30일 이내에 파기합니다'));
});
