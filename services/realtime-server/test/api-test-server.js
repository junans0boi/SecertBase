import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import Redis from 'ioredis';
import { createIntegrationEnvironment } from '../src/integration-environment.js';

export async function createApiTestServer({ adminUrl, redisUrl }) {
  const environment = await createIntegrationEnvironment({ adminUrl, redisUrl });
  const runtime = {
    ...environment.environmentVariables,
    PORT: '4100',
    PUBLIC_FEATURE_SET: 'mvp',
    CORS_ORIGIN: 'http://localhost:4100',
    JWT_SECRET: 'api-integration-secret-at-least-32-characters',
    ROOM_SECRET: 'integration-room',
    ALLOWED_USERS: 'integration-one,integration-two',
  };
  const migration = spawnSync(process.execPath, ['scripts/migrate.js', 'up'], {
    cwd: new URL('..', import.meta.url),
    encoding: 'utf8',
    env: { ...process.env, ...runtime },
  });
  if (migration.status !== 0) {
    await environment.cleanup();
    throw new Error(migration.stderr);
  }

  Object.assign(process.env, runtime);
  const [{ default: routes }, database, { createApp }, { config }] = await Promise.all([
    import('../src/routes.js'),
    import('../src/db.js'),
    import('../src/app/create-app.js'),
    import('../src/config.js'),
  ]);
  Object.assign(config, {
    DATABASE_URL: environment.databaseUrl,
    REDIS_URL: redisUrl,
    REDIS_KEY_PREFIX: environment.redisNamespace,
    UPLOADS_ROOT: environment.uploadsRoot,
  });
  const appRedis = new Redis(redisUrl, {
    maxRetriesPerRequest: 3,
    enableReadyCheck: true,
    keyPrefix: environment.redisNamespace,
  });
  const app = createApp({ config, redis: appRedis, routes });
  app.locals.io = {
    to: () => ({ emit: () => {} }),
    in: () => ({ disconnectSockets: () => {} }),
  };
  const server = createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  return {
    environment,
    async request(path, { token, method = 'GET', body } = {}) {
      const isFormData = body instanceof FormData;
      const response = await fetch(`${baseUrl}/api${path}`, {
        method,
        headers: {
          ...(token ? { authorization: `Bearer ${token}` } : {}),
          ...(body && !isFormData ? { 'content-type': 'application/json' } : {}),
        },
        ...(body ? { body: isFormData ? body : JSON.stringify(body) } : {}),
      });
      const responseBody = await response.arrayBuffer();
      const responseText = new TextDecoder().decode(responseBody);
      return {
        ok: response.ok,
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
        url: response.url,
        async text() {
          return responseText;
        },
        async json() {
          return JSON.parse(responseText);
        },
        async arrayBuffer() {
          return responseBody.slice(0);
        },
      };
    },
    async close() {
      await new Promise((resolve) => server.close(resolve));
      await database.close();
      await appRedis.quit().catch(() => appRedis.disconnect());
      await environment.cleanup();
    },
  };
}
