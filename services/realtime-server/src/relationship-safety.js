import fs from 'node:fs';

const catalog = JSON.parse(
  fs.readFileSync(new URL('./data/safety-resources-kr.json', import.meta.url), 'utf8'),
);

export const SAFETY_RESOURCE_VERSION = catalog.version;

const generalResources = () => catalog.fallback.map((item) => ({
  ...item,
  region: null,
}));

export const buildSafetyResources = ({
  locationPermission = 'denied',
  countryCode = null,
  adminArea = null,
} = {}) => {
  const country = String(countryCode ?? '').trim().toUpperCase();
  const region = String(adminArea ?? '').trim().slice(0, 64);
  const regionEntry = catalog.regions[region];
  if (locationPermission !== 'granted' || country !== catalog.countryCode || !regionEntry) {
    return {
      resourceVersion: SAFETY_RESOURCE_VERSION,
      source: catalog.source,
      validUntil: catalog.validUntil,
      locationMode: 'general',
      countryCode: null,
      adminArea: null,
      resources: generalResources(),
    };
  }
  return {
    resourceVersion: SAFETY_RESOURCE_VERSION,
    source: catalog.source,
    validUntil: catalog.validUntil,
    locationMode: 'region',
    countryCode: catalog.countryCode,
    adminArea: region,
    resources: catalog.fallback.map((item) => ({
      ...item,
      region,
      description: `${item.description} ${regionEntry.note}`,
    })),
  };
};
