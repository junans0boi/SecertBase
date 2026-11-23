import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import mysql from 'mysql2/promise';
import test from 'node:test';
import { createIntegrationEnvironment } from '../src/integration-environment.js';
import { createNotifier } from '../src/modules/notifications/notifier.js';
import { notifyAnniversaryEve, notifyTwoAnswersWaiting } from '../src/modules/notifications/reminders.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;
const silent = { log() {}, error() {} };

test('anniversary D-1 and 마주 열기 reminders against real MariaDB/Redis: scope, dedupe, quiet hours, inactive couple',
  { skip: !adminUrl || !redisUrl }, async () => {
    const env = await createIntegrationEnvironment({ adminUrl, redisUrl });
    let db;
    try {
      const migration = spawnSync(process.execPath, ['scripts/migrate.js', 'up'], {
        cwd: new URL('..', import.meta.url), encoding: 'utf8',
        env: { ...process.env, ...env.environmentVariables },
      });
      assert.equal(migration.status, 0, migration.stderr);
      db = await mysql.createConnection(env.databaseUrl);
      const queryFn = async (sql, params = []) => ({ rows: (await db.execute(sql, params))[0] });
      for (const id of [1, 2, 3, 4]) {
        await queryFn(`INSERT INTO Users (UserId, Email, UserName, FullName, Nickname, BirthDate, UserCode)
          VALUES (?, ?, ?, ?, ?, '2000-01-01', ?)`, [id, `u${id}@example.test`, `U${id}`, `U${id}`, `U${id}`, `CODE${id}`]);
        await queryFn("INSERT INTO device_tokens (user_id, platform, token) VALUES (?, 'web', ?)", [id, `tok${id}`]);
      }
      await queryFn(`INSERT INTO Couples (CoupleId, RoomCode, RoomSecret, User1Id, User2Id, Status, PairKey)
        VALUES (7, 'r12', 'x', 1, 2, 'active', '1:2'), (8, 'r34', 'x', 3, 4, 'inactive', '3:4')`);
      // 2026-11-24 is "tomorrow" at 10:00 KST on 2026-11-23.
      await queryFn(`INSERT INTO anniversaries (couple_id, label, date, repeat_yearly) VALUES
        (7, '비밀 기념일', '2024-11-24', 1), (7, '다른 날', '2024-11-25', 1), (8, '끝난 커플', '2024-11-24', 1)`);
      await queryFn("INSERT INTO two_answers (id, couple_id, business_date, question_id, category, question_text) VALUES (1, 7, '2026-11-23', 'q', 'daily', '질문')");
      await queryFn("INSERT INTO two_answer_responses (two_answer_id, couple_id, user_id, body) VALUES (1, 7, 1, '비밀 답변')");

      const sent = [];
      let now = new Date('2026-11-23T01:00:00Z'); // 10:00 KST
      const notifier = createNotifier({ queryFn, log: silent, now: () => now, sender: {
        async send(m) { sent.push(m); return m.tokens.map((token) => ({ token, errorCode: null })); },
      } });
      const run = { queryFn, redis: env.redis, notifier, now: () => now };

      assert.equal(await notifyAnniversaryEve(run), 2);
      assert.equal(await notifyAnniversaryEve(run), 0);
      assert.equal(await notifyTwoAnswersWaiting(run), 1);
      assert.equal(await notifyTwoAnswersWaiting(run), 0);
      const byType = (type) => sent.filter((m) => m.data.type === type).flatMap((m) => m.tokens).sort();
      assert.deepEqual(byType('anniversary_eve'), ['tok1', 'tok2']);
      assert.deepEqual(byType('two_answers_waiting'), ['tok2']); // only the one who has not answered
      assert.doesNotMatch(JSON.stringify(sent), /비밀 기념일|비밀 답변|질문2/);

      // Both answered -> nothing; a new day's recipient is gated by quiet hours then released.
      await queryFn("INSERT INTO two_answer_responses (two_answer_id, couple_id, user_id, body) VALUES (1, 7, 2, 'x')");
      await queryFn("INSERT INTO two_answers (id, couple_id, business_date, question_id, category, question_text) VALUES (2, 7, '2026-11-24', 'q2', 'daily', '질문2')");
      await queryFn("INSERT INTO two_answer_responses (two_answer_id, couple_id, user_id, body) VALUES (2, 7, 2, 'y')");
      now = new Date('2026-11-24T14:00:00Z'); // 23:00 KST on 11-24 (default quiet 22-08)
      assert.equal(await notifyTwoAnswersWaiting({ ...run, now: () => now }), 0);
      now = new Date('2026-11-24T23:30:00Z'); // 08:30 KST on 11-25 — new date, no row for it
      assert.equal(await notifyTwoAnswersWaiting({ ...run, now: () => now }), 0);
      await queryFn('UPDATE notification_prefs SET quiet_hours_enabled = 0 WHERE user_id = 1');
      await queryFn("INSERT INTO notification_prefs (user_id, quiet_hours_enabled) VALUES (1, 0) ON DUPLICATE KEY UPDATE quiet_hours_enabled = 0");
      now = new Date('2026-11-24T14:00:00Z');
      assert.equal(await notifyTwoAnswersWaiting({ ...run, now: () => now }), 1);
    } finally {
      await db?.end();
      await env.cleanup();
    }
  });
