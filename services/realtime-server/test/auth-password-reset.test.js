import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import bcrypt from 'bcryptjs';
import express from 'express';
import { createPasswordResetRouter } from '../src/modules/auth/password-reset.js';
import { createMailer, MailUnavailableError, resolveMailTransport } from '../src/modules/auth/mailer.js';

// Users / password_reset_tokens 를 흉내 내는 작은 메모리 DB. 라우터가 쓰는 쿼리만 해석한다.
function fakeDb({ users }) {
  const tokens = [];
  let nextId = 1;
  const queryFn = async (sql, params) => {
    const text = sql.replace(/\s+/g, ' ').trim();
    if (text.startsWith('SELECT UserId, Email, PasswordHash')) {
      return { rows: users.filter((u) => u.Email === params[0]).slice(0, 1) };
    }
    if (text.startsWith('UPDATE password_reset_tokens SET used_at = ? WHERE user_id = ?')) {
      let n = 0;
      for (const t of tokens) if (t.user_id === params[1] && !t.used_at) { t.used_at = params[0]; n++; }
      return { rows: { affectedRows: n } };
    }
    if (text.startsWith('INSERT INTO password_reset_tokens')) {
      const [user_id, code_hash, link_hash, expires_at] = params;
      const row = { id: nextId++, user_id, code_hash, link_hash, expires_at, attempts: 0, used_at: null };
      tokens.push(row);
      return { rows: { insertId: row.id, affectedRows: 1 } };
    }
    if (text.startsWith('UPDATE password_reset_tokens SET used_at = ? WHERE id = ? AND used_at IS NULL')) {
      const t = tokens.find((x) => x.id === params[1] && !x.used_at);
      if (t) t.used_at = params[0];
      return { rows: { affectedRows: t ? 1 : 0 } };
    }
    if (text.startsWith('UPDATE password_reset_tokens SET used_at = ? WHERE id = ?')) {
      const t = tokens.find((x) => x.id === params[1]);
      if (t) t.used_at = params[0];
      return { rows: { affectedRows: t ? 1 : 0 } };
    }
    if (text.includes('FROM password_reset_tokens WHERE link_hash = ?')) {
      return { rows: tokens.filter((t) => t.link_hash === params[0]).slice(0, 1).map((t) => ({ ...t })) };
    }
    if (text.includes('FROM password_reset_tokens t JOIN Users u')) {
      const user = users.find((u) => u.Email === params[0]);
      const rows = tokens
        .filter((t) => user && t.user_id === user.UserId && !t.used_at)
        .sort((a, b) => b.id - a.id)
        .slice(0, 1)
        .map((t) => ({ ...t }));
      return { rows };
    }
    if (text.startsWith('UPDATE password_reset_tokens SET attempts = attempts + 1')) {
      const t = tokens.find((x) => x.id === params[0]);
      t.attempts += 1;
      return { rows: { affectedRows: 1 } };
    }
    if (text.startsWith('UPDATE Users SET PasswordHash = ?')) {
      const u = users.find((x) => x.UserId === params[2]);
      u.PasswordHash = params[0];
      u.PasswordSalt = params[1];
      return { rows: { affectedRows: 1 } };
    }
    throw new Error(`unexpected sql: ${text}`);
  };
  return { queryFn, tokens };
}

function recordingMailer({ available = true, fail = false } = {}) {
  const sent = [];
  return {
    sent,
    available,
    async send(mail) {
      if (fail) throw new MailUnavailableError('down');
      sent.push(mail);
    },
  };
}

async function withServer(router, run) {
  const app = express();
  app.use(express.json());
  app.use(router);
  const server = createServer(app).listen(0);
  await new Promise((r) => server.once('listening', r));
  try {
    const base = `http://127.0.0.1:${server.address().port}`;
    const post = async (path, body) => {
      const response = await fetch(base + path, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      return { status: response.status, body: await response.json() };
    };
    await run(post);
  } finally {
    await new Promise((r) => server.close(r));
  }
}

const silentLog = { error() {}, info() {} };
const passwordUser = () => ({
  UserId: 7,
  Email: 'minji@example.test',
  PasswordHash: bcrypt.hashSync('oldpass123', 4),
  AuthProvider: 'password',
  IsDeleted: 0,
});

const build = ({ users = [passwordUser()], mailer = recordingMailer(), clock } = {}) => {
  const db = fakeDb({ users });
  let t = clock ?? new Date('2026-11-06T10:00:00Z').getTime();
  let codeSeq = 0;
  const router = createPasswordResetRouter({
    queryFn: db.queryFn,
    mailer,
    secret: 'test-secret-test-secret-test-secret',
    appUrl: 'https://app.example.test/',
    now: () => new Date(t),
    generateCode: () => ['123456', '654321', '111222'][codeSeq++ % 3],
    generateLinkToken: () => `link-token-${codeSeq}`,
    limiterEnabled: false,
    log: silentLog,
  });
  return { router, db, users, mailer, advance: (ms) => { t += ms; } };
};

test('request sends a code and a link; unknown emails get the same answer without mail', async () => {
  const ctx = build();
  await withServer(ctx.router, async (post) => {
    const ok = await post('/auth/password-reset/request', { email: 'minji@example.test' });
    assert.equal(ok.status, 200);
    assert.deepEqual(ok.body, { ok: true, cooldownSeconds: 60, expiresInMinutes: 60 });
    assert.equal(ctx.mailer.sent.length, 1);
    assert.match(ctx.mailer.sent[0].text, /123456/);
    assert.match(ctx.mailer.sent[0].text, /https:\/\/app\.example\.test\/\?reset=link-token-1/);
    // 코드는 해시로만 저장된다.
    assert.equal(ctx.db.tokens.length, 1);
    assert.doesNotMatch(JSON.stringify(ctx.db.tokens), /123456/);

    const unknown = await post('/auth/password-reset/request', { email: 'nobody@example.test' });
    assert.equal(unknown.status, 200);
    assert.deepEqual(unknown.body, ok.body);
    assert.equal(ctx.mailer.sent.length, 1);

    const bad = await post('/auth/password-reset/request', { email: 'not-an-email' });
    assert.equal(bad.status, 400);
    assert.equal(bad.body.reason, 'invalid_email');
  });
});

test('mail_unavailable is reported before any lookup when no transport is configured', async () => {
  const mailer = recordingMailer({ available: false });
  const ctx = build({ mailer });
  await withServer(ctx.router, async (post) => {
    const res = await post('/auth/password-reset/request', { email: 'nobody@example.test' });
    assert.equal(res.status, 503);
    assert.equal(res.body.reason, 'mail_unavailable');
  });
});

test('a failing transport returns mail_unavailable and voids the issued code', async () => {
  const ctx = build({ mailer: recordingMailer({ fail: true }) });
  await withServer(ctx.router, async (post) => {
    const res = await post('/auth/password-reset/request', { email: 'minji@example.test' });
    assert.equal(res.status, 503);
    assert.equal(res.body.reason, 'mail_unavailable');
    assert.ok(ctx.db.tokens[0].used_at, 'unsent code must not stay usable');
  });
});

test('Google-only accounts get a "use Google" mail and no code', async () => {
  const ctx = build({
    users: [{ UserId: 9, Email: 'g@example.test', PasswordHash: null, AuthProvider: 'google', IsDeleted: 0 }],
  });
  await withServer(ctx.router, async (post) => {
    const res = await post('/auth/password-reset/request', { email: 'g@example.test' });
    assert.equal(res.status, 200);
    assert.equal(ctx.db.tokens.length, 0);
    assert.match(ctx.mailer.sent[0].text, /Google/);
  });
});

test('verify + confirm with the code sets a new password once', async () => {
  const ctx = build();
  await withServer(ctx.router, async (post) => {
    await post('/auth/password-reset/request', { email: 'minji@example.test' });
    const wrong = await post('/auth/password-reset/verify', { email: 'minji@example.test', code: '000000' });
    assert.equal(wrong.status, 400);
    assert.equal(wrong.body.reason, 'invalid_code');
    assert.equal(wrong.body.attemptsLeft, 4);

    const right = await post('/auth/password-reset/verify', { email: 'minji@example.test', code: '123456' });
    assert.equal(right.status, 200);

    const weak = await post('/auth/password-reset/confirm', {
      email: 'minji@example.test', code: '123456', password: 'abcdefgh',
    });
    assert.equal(weak.status, 400);
    assert.equal(weak.body.reason, 'weak_password');

    const done = await post('/auth/password-reset/confirm', {
      email: 'minji@example.test', code: '123456', password: 'newpass123',
    });
    assert.equal(done.status, 200);
    assert.ok(bcrypt.compareSync('newpass123', ctx.users[0].PasswordHash));

    const replay = await post('/auth/password-reset/confirm', {
      email: 'minji@example.test', code: '123456', password: 'another123',
    });
    assert.equal(replay.status, 400);
    assert.equal(replay.body.reason, 'invalid_code');
  });
});

test('the emailed link token works without the code', async () => {
  const ctx = build();
  await withServer(ctx.router, async (post) => {
    await post('/auth/password-reset/request', { email: 'minji@example.test' });
    assert.equal((await post('/auth/password-reset/verify', { token: 'link-token-1' })).status, 200);
    const done = await post('/auth/password-reset/confirm', { token: 'link-token-1', password: 'linkpass123' });
    assert.equal(done.status, 200);
    assert.ok(bcrypt.compareSync('linkpass123', ctx.users[0].PasswordHash));
    assert.equal((await post('/auth/password-reset/verify', { token: 'link-token-1' })).status, 400);
  });
});

test('codes expire after an hour and lock after five wrong tries; a new code replaces the old', async () => {
  const ctx = build();
  await withServer(ctx.router, async (post) => {
    await post('/auth/password-reset/request', { email: 'minji@example.test' });
    ctx.advance(60 * 60 * 1000 + 1);
    const expired = await post('/auth/password-reset/verify', { email: 'minji@example.test', code: '123456' });
    assert.equal(expired.status, 410);
    assert.equal(expired.body.reason, 'code_expired');

    await post('/auth/password-reset/request', { email: 'minji@example.test' }); // code 654321
    assert.equal(
      (await post('/auth/password-reset/verify', { email: 'minji@example.test', code: '123456' })).body.reason,
      'invalid_code',
    );
    for (let i = 0; i < 3; i++) {
      await post('/auth/password-reset/verify', { email: 'minji@example.test', code: '999999' });
    }
    const locked = await post('/auth/password-reset/verify', { email: 'minji@example.test', code: '999999' });
    assert.equal(locked.status, 429);
    assert.equal(locked.body.reason, 'too_many_attempts');
    const stillLocked = await post('/auth/password-reset/verify', { email: 'minji@example.test', code: '654321' });
    assert.equal(stillLocked.body.reason, 'too_many_attempts');
  });
});

test('resend cooldown: one request per email per minute when limits are on', async () => {
  const db = fakeDb({ users: [passwordUser()] });
  const router = createPasswordResetRouter({
    queryFn: db.queryFn,
    mailer: recordingMailer(),
    secret: 's'.repeat(32),
    limiterEnabled: true,
    log: silentLog,
  });
  await withServer(router, async (post) => {
    assert.equal((await post('/auth/password-reset/request', { email: 'minji@example.test' })).status, 200);
    const again = await post('/auth/password-reset/request', { email: 'minji@example.test' });
    assert.equal(again.status, 429);
    assert.equal(again.body.reason, 'rate_limited');
  });
});

test('mailer: transport resolution and adapters', async () => {
  assert.equal(resolveMailTransport({ NODE_ENV: 'development' }), 'log');
  assert.equal(resolveMailTransport({ NODE_ENV: 'production' }), 'none');
  assert.equal(resolveMailTransport({ NODE_ENV: 'test' }), 'none');
  assert.equal(resolveMailTransport({ NODE_ENV: 'production', MAIL_WEBHOOK_URL: 'https://x.test' }), 'webhook');
  assert.equal(resolveMailTransport({ MAIL_TRANSPORT: 'log', NODE_ENV: 'production' }), 'log');

  const none = createMailer({ transport: 'none' });
  assert.equal(none.available, false);
  await assert.rejects(none.send({ to: 'a@b.c' }), MailUnavailableError);

  const logged = [];
  const log = createMailer({ transport: 'log', log: { info: (m) => logged.push(m) } });
  await log.send({ to: 'a@b.c', subject: 's', text: 'code 123456' });
  assert.match(logged[0], /123456/);

  const calls = [];
  const hook = createMailer({
    transport: 'webhook',
    webhookUrl: 'https://mail.example.test/send',
    webhookToken: 'tok',
    fetchFn: async (url, init) => { calls.push({ url, init }); return { ok: true }; },
  });
  await hook.send({ to: 'a@b.c', subject: 's', text: 't' });
  assert.equal(calls[0].url, 'https://mail.example.test/send');
  assert.equal(calls[0].init.headers.authorization, 'Bearer tok');
  assert.equal(JSON.parse(calls[0].init.body).to, 'a@b.c');

  const failing = createMailer({
    transport: 'webhook',
    webhookUrl: 'https://mail.example.test/send',
    fetchFn: async () => ({ ok: false, status: 500 }),
  });
  await assert.rejects(failing.send({ to: 'a@b.c' }), MailUnavailableError);
});
