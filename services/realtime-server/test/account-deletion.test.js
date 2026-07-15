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
