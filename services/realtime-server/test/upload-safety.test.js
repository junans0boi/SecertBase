import assert from 'node:assert/strict';
import test from 'node:test';
import { extensionForMime, isAllowedUploadMime, setUploadResponseHeaders } from '../src/shared/upload-safety.js';

test('extensions come from a whitelist, never from the raw mime subtype', () => {
  assert.equal(extensionForMime('image/jpeg'), 'jpg');
  assert.equal(extensionForMime('video/quicktime'), 'mov');
  assert.equal(extensionForMime('IMAGE/PNG; charset=binary'), 'png');
  for (const bad of ['image/html', 'image/svg+xml', 'text/html', 'application/javascript', '', null, undefined]) {
    assert.equal(extensionForMime(bad), null, String(bad));
    assert.equal(isAllowedUploadMime(bad), false);
  }
});

test('served uploads get nosniff and a sandboxing CSP', () => {
  const headers = {};
  setUploadResponseHeaders({ setHeader: (k, v) => { headers[k] = v; } });
  assert.equal(headers['X-Content-Type-Options'], 'nosniff');
  assert.match(headers['Content-Security-Policy'], /sandbox/);
});
