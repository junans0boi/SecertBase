import assert from 'node:assert/strict';
import test from 'node:test';
import { featureForRestPath, isRestEnabled } from '../src/shared/feature-registry.js';

test('disabled REST features stay disabled regardless of path casing', () => {
  for (const path of ['/premium/activate', '/PREMIUM/activate', '/Premium/Activate', '/api/ALBUM/folders', '/Capsules', '/reflections/12']) {
    assert.notEqual(featureForRestPath(path), null, path);
    assert.equal(isRestEnabled(path, 'mvp'), false, path);
  }
});

test('legacy feature set and unrelated paths are unaffected', () => {
  assert.equal(isRestEnabled('/PREMIUM/activate', 'legacy'), true);
  assert.equal(featureForRestPath('/auth/login'), null);
  assert.equal(featureForRestPath('/premiumx'), null);
});
