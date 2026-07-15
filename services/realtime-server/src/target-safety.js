import os from 'node:os';
import path from 'node:path';

const loopbackHosts = new Set(['127.0.0.1', '::1', '[::1]', 'localhost']);

const parseUrl = (value, label) => {
  try {
    return new URL(value);
  } catch {
    throw new Error(`${label} must be a valid URL`);
  }
};

const isWithin = (parent, child) => {
  const relative = path.relative(path.resolve(parent), path.resolve(child));
  return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
};

const normalizedEndpoint = (url, defaultPort) => ({
  host: loopbackHosts.has(url.hostname) ? 'loopback' : url.hostname,
  port: url.port || defaultPort,
});

const assertDifferentEndpoint = (testUrl, productionUrl, defaultPort, label) => {
  if (!productionUrl) return;
  const production = parseUrl(productionUrl, `Known production ${label} URL`);
  const testEndpoint = normalizedEndpoint(testUrl, defaultPort);
  const productionEndpoint = normalizedEndpoint(production, defaultPort);

  if (
    testEndpoint.host === productionEndpoint.host &&
    testEndpoint.port === productionEndpoint.port
  ) {
    throw new Error(`Test target matches the known production ${label} server`);
  }
};

const assertSafeDatabase = ({
  databaseUrl,
  label,
  allowedDatabaseName,
  errorMessage,
  productionDatabaseUrl,
}) => {
  const database = parseUrl(databaseUrl, label);
  const databasePort = database.port || '3306';
  const databaseName = database.pathname.replace(/^\//, '');
  const databaseUser = decodeURIComponent(database.username).toLowerCase();

  if (
    !['mysql:', 'mariadb:'].includes(database.protocol) ||
    !loopbackHosts.has(database.hostname) ||
    databasePort !== '3306' ||
    !allowedDatabaseName(databaseName) ||
    !databaseUser.includes('test')
  ) {
    throw new Error(errorMessage);
  }
  assertDifferentEndpoint(database, productionDatabaseUrl, '3306', 'database');
};

const assertSafeRedisAndUploads = ({
  redisUrl,
  redisNamespace,
  uploadsRoot,
  productionRedisUrl,
}) => {
  const redis = parseUrl(redisUrl, 'Test Redis URL');
  const redisPort = redis.port || '6379';
  if (
    !['redis:', 'rediss:'].includes(redis.protocol) ||
    !loopbackHosts.has(redis.hostname) ||
    redisPort !== '6379'
  ) {
    throw new Error('Test Redis URL must use the local port 6379 target');
  }
  assertDifferentEndpoint(redis, productionRedisUrl, '6379', 'Redis');

  if (!/^secretbase:test:[a-zA-Z0-9_-]+:$/.test(redisNamespace ?? '')) {
    throw new Error('Test Redis namespace must uniquely match secretbase:test:<run>:');
  }

  if (!uploadsRoot || !isWithin(os.tmpdir(), uploadsRoot)) {
    throw new Error('Test uploads root must be inside the system temporary directory');
  }
};

export function assertSafeTestEnvironment({
  databaseAdminUrl,
  redisUrl,
  redisNamespace,
  uploadsRoot,
  productionDatabaseUrl,
  productionRedisUrl,
}) {
  assertSafeDatabase({
    databaseUrl: databaseAdminUrl,
    label: 'Test database admin URL',
    allowedDatabaseName: (name) => name === 'mysql',
    errorMessage:
      'Test database admin URL must use a local :3306/mysql target and a test-only user',
    productionDatabaseUrl,
  });
  assertSafeRedisAndUploads({
    redisUrl,
    redisNamespace,
    uploadsRoot,
    productionRedisUrl,
  });
}

export function assertSafeTestRuntime({
  databaseUrl,
  redisUrl,
  redisNamespace,
  uploadsRoot,
  productionDatabaseUrl,
  productionRedisUrl,
}) {
  assertSafeDatabase({
    databaseUrl,
    label: 'Test database URL',
    allowedDatabaseName: (name) =>
      /^secretbase_test_[a-zA-Z0-9_]+$/.test(name),
    errorMessage:
      'Test database URL must target a local disposable secretbase_test_* schema',
    productionDatabaseUrl,
  });
  assertSafeRedisAndUploads({
    redisUrl,
    redisNamespace,
    uploadsRoot,
    productionRedisUrl,
  });
}
