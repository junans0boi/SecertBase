import assert from 'node:assert/strict';
import test from 'node:test';
import {
  SAFETY_RESOURCE_VERSION,
  buildSafetyResources,
} from '../src/relationship-safety.js';

test('safety resources use the versioned Korea catalog without storing coordinates', () => {
  const general = buildSafetyResources({ locationPermission: 'denied' });
  assert.equal(general.resourceVersion, SAFETY_RESOURCE_VERSION);
  assert.equal(general.locationMode, 'general');
  assert.ok(general.resources.some((item) => item.key === 'emergency'));

  const region = buildSafetyResources({
    locationPermission: 'granted',
    countryCode: 'KR',
    adminArea: '서울특별시',
  });
  assert.equal(region.locationMode, 'region');
  assert.equal(region.countryCode, 'KR');
  assert.equal(region.adminArea, '서울특별시');
  assert.ok(region.resources.some((item) => item.region === '서울특별시'));
  assert.equal('latitude' in region, false);
  assert.equal('longitude' in region, false);
});

test('unknown or ungranted location falls back to general safety resources', () => {
  const unknown = buildSafetyResources({
    locationPermission: 'granted',
    countryCode: 'US',
    adminArea: 'New York',
  });
  assert.equal(unknown.locationMode, 'general');
  assert.equal(unknown.countryCode, null);
  assert.equal(unknown.adminArea, null);
  assert.ok(unknown.resources.every((item) => item.region == null));
});
