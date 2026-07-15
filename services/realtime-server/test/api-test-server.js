import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import express from 'express';
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
  const [{ default: routes }, database] = await Promise.all([
    import('../src/routes.js'),
    import('../src/db.js'),
  ]);
  const app = express();
  app.locals.io = {
    to: () => ({ emit: () => {} }),
    in: () => ({ disconnectSockets: () => {} }),
  };
  app.use(express.json());
  app.use('/api', routes);
  const server = createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  return {
    environment,
    async request(path, { token, method = 'GET', body } = {}) {
      const isFormData = body instanceof FormData;
      return fetch(`${baseUrl}/api${path}`, {
        method,
        headers: {
          ...(token ? { authorization: `Bearer ${token}` } : {}),
          ...(body && !isFormData ? { 'content-type': 'application/json' } : {}),
        },
        ...(body ? { body: isFormData ? body : JSON.stringify(body) } : {}),
      });
    },
    async close() {
      await new Promise((resolve) => server.close(resolve));
      await database.close();
      await environment.cleanup();
    },
  };
}
