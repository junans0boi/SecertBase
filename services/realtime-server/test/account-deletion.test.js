import test from 'node:test';
import assert from 'node:assert/strict';

import {
  isPasswordUser,
  buildTombstoneFields,
  classifyPinsForDeletion,
  collectMediaPaths,
} from '../src/account-deletion.js';

// ── isPasswordUser ──────────────────────────────────────────────────────────

test('isPasswordUser: null authProvider → true', () => {
  assert.equal(isPasswordUser(null), true);
});

test('isPasswordUser: "password" authProvider → true', () => {
  assert.equal(isPasswordUser('password'), true);
});

test('isPasswordUser: "google" authProvider → false', () => {
  assert.equal(isPasswordUser('google'), false);
});

// ── buildTombstoneFields ─────────────────────────────────────────────────────

test('buildTombstoneFields replaces email and credentials with tombstone values', () => {
  const fields = buildTombstoneFields(42);
  assert.equal(fields.Email, 'deleted_42@__tombstone__');
  assert.equal(fields.UserName, 'deleted_42');
  assert.equal(fields.IsDeleted, 1);
  assert.equal(fields.PasswordHash, null);
  assert.equal(fields.GoogleId, null);
  assert.ok(fields.DeletedAt, 'DeletedAt should be set');
});

test('buildTombstoneFields userId is embedded in unique identifiers', () => {
  const a = buildTombstoneFields(1);
  const b = buildTombstoneFields(2);
  assert.notEqual(a.Email, b.Email);
  assert.notEqual(a.UserName, b.UserName);
});

// ── classifyPinsForDeletion ──────────────────────────────────────────────────

test('classifyPinsForDeletion: linked pins go to anonymize, unlinked to delete', () => {
  const pins = [
    { id: 1, hasLinkedMoment: true },
    { id: 2, hasLinkedMoment: false },
    { id: 3, hasLinkedMoment: true },
    { id: 4, hasLinkedMoment: false },
  ];
  const { toAnonymize, toDelete } = classifyPinsForDeletion(pins);
  assert.deepEqual(toAnonymize, [1, 3]);
  assert.deepEqual(toDelete, [2, 4]);
});

test('classifyPinsForDeletion: empty input returns empty arrays', () => {
  const { toAnonymize, toDelete } = classifyPinsForDeletion([]);
  assert.deepEqual(toAnonymize, []);
  assert.deepEqual(toDelete, []);
});

test('classifyPinsForDeletion: all linked', () => {
  const pins = [{ id: 10, hasLinkedMoment: true }];
  const { toAnonymize, toDelete } = classifyPinsForDeletion(pins);
  assert.deepEqual(toAnonymize, [10]);
  assert.deepEqual(toDelete, []);
});

// ── collectMediaPaths ────────────────────────────────────────────────────────

test('collectMediaPaths returns resolved paths for posts with media_url', () => {
  const mediaFilePath = (url) => (url ? `/uploads/${url}` : null);
  const posts = [
    { media_url: 'a.jpg' },
    { media_url: null },
    { media_url: 'b.mp4' },
  ];
  const paths = collectMediaPaths(posts, mediaFilePath);
  assert.deepEqual(paths, ['/uploads/a.jpg', '/uploads/b.mp4']);
});

test('collectMediaPaths returns empty array when no posts have media', () => {
  const mediaFilePath = () => null;
  const paths = collectMediaPaths([{ media_url: null }], mediaFilePath);
  assert.deepEqual(paths, []);
});

// ── tombstone must satisfy NOT NULL columns ──────────────────────────────────

test('buildTombstoneFields never nulls NOT NULL columns and erases birth data', () => {
  const fields = buildTombstoneFields(7);
  assert.equal(fields.Nickname, '', 'Users.Nickname is NOT NULL');
  assert.equal(fields.BirthDate, '1900-01-01', 'Users.BirthDate is NOT NULL');
  assert.equal(fields.BirthTime, null);
  assert.equal(fields.BirthPlace, null);
});

// ── USER_DATA_PURGE ──────────────────────────────────────────────────────────

import { readdirSync, readFileSync } from 'node:fs';
import {
  USER_DATA_PURGE,
  USER_MEDIA_COLUMNS,
  purgeUserData,
} from '../src/account-deletion.js';

const migrationsDir = new URL('../migrations/', import.meta.url);
const schema = new Map();
for (const file of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
  const sql = readFileSync(new URL(file, migrationsDir), 'utf8');
  for (const [, table, body] of sql.matchAll(/CREATE TABLE IF NOT EXISTS (\w+) \(([\s\S]*?)\n\)/g)) {
    const columns = schema.get(table.toLowerCase()) ?? new Set();
    for (const line of body.split('\n')) {
      const match = line.trim().match(/^(\w+)\s+(INT|BIGINT|VARCHAR|TEXT|TINYINT|DATE|DATETIME|TIMESTAMP|ENUM|JSON|DECIMAL|SMALLINT|LONGTEXT|MEDIUMTEXT|TIME)\b/i);
      if (match) columns.add(match[1].toLowerCase());
    }
    schema.set(table.toLowerCase(), columns);
  }
  for (const [, table, body] of sql.matchAll(/ALTER TABLE (\w+)([\s\S]*?);/g)) {
    const columns = schema.get(table.toLowerCase()) ?? new Set();
    for (const [, column] of body.matchAll(/ADD COLUMN(?: IF NOT EXISTS)? (\w+)/gi)) {
      columns.add(column.toLowerCase());
    }
    schema.set(table.toLowerCase(), columns);
  }
}

test('USER_DATA_PURGE only names tables and columns that exist in the migrations', () => {
  for (const { table, where } of USER_DATA_PURGE) {
    const columns = schema.get(table.toLowerCase());
    assert.ok(columns, `table ${table} is not created by any migration`);
    for (const column of where) {
      assert.ok(columns.has(column.toLowerCase()), `${table}.${column} does not exist`);
    }
  }
  for (const { table, column, userColumn } of USER_MEDIA_COLUMNS) {
    const columns = schema.get(table.toLowerCase());
    assert.ok(columns?.has(column.toLowerCase()), `${table}.${column} does not exist`);
    assert.ok(columns?.has(userColumn.toLowerCase()), `${table}.${userColumn} does not exist`);
  }
});

test('USER_DATA_PURGE covers the personal-data tables added after the first release', () => {
  const tables = new Set(USER_DATA_PURGE.map((entry) => entry.table));
  for (const required of [
    'relationship_counseling_sessions',
    'relationship_mindcare_sessions',
    'relationship_saju_results',
    'device_tokens',
    'setlog_comments',
    'private_reflections',
  ]) {
    assert.ok(tables.has(required), `${required} must be purged on account deletion`);
  }
});

test('purgeUserData deletes by user id and binds it to every listed column', async () => {
  const calls = [];
  const conn = { execute: async (sql, params) => { calls.push({ sql, params }); } };
  await purgeUserData(conn, 42);
  assert.equal(calls.length, USER_DATA_PURGE.length);
  const pairing = calls.find((c) => c.sql.includes('PairingRequests'));
  assert.match(pairing.sql, /SenderUserId = \? OR RecipientUserId = \?/);
  assert.deepEqual(pairing.params, [42, 42]);
  assert.ok(calls.every((c) => c.params.every((p) => p === 42)));
});

test('purgeUserData skips a missing table but rethrows real errors', async () => {
  const missing = Object.assign(new Error('no table'), { code: 'ER_NO_SUCH_TABLE' });
  const skipped = await purgeUserData(
    { execute: async (sql) => { if (sql.includes('device_tokens')) throw missing; } },
    1,
  );
  assert.deepEqual(skipped, ['device_tokens']);

  const deadlock = Object.assign(new Error('deadlock'), { code: 'ER_LOCK_DEADLOCK' });
  await assert.rejects(
    purgeUserData({ execute: async () => { throw deadlock; } }, 1),
    /deadlock/,
  );
});
