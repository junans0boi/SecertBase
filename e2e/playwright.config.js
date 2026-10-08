import { defineConfig, devices } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const e2eDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(e2eDirectory, '..');
const backendDirectory = path.join(repositoryRoot, 'services/realtime-server');
const frontendDirectory = path.join(repositoryRoot, 'apps/secret_base_app');

const backendPort = Number(process.env.E2E_BACKEND_PORT ?? 4100);
const frontendPort = Number(process.env.E2E_FRONTEND_PORT ?? 7357);
const backendUrl = `http://127.0.0.1:${backendPort}`;
const frontendUrl = `http://127.0.0.1:${frontendPort}`;

export default defineConfig({
  testDir: path.join(e2eDirectory, 'tests'),
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  timeout: 120_000,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    ...devices['Desktop Chrome'],
    baseURL: frontendUrl,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  webServer: [
    {
      command: 'npm start',
      cwd: backendDirectory,
      url: `${backendUrl}/health`,
      timeout: 120_000,
      reuseExistingServer: true,
      env: {
        ...process.env,
        PORT: String(backendPort),
        CORS_ORIGIN: frontendUrl,
      },
    },
    {
      command: `flutter build web --release --no-web-resources-cdn --dart-define=SOCKET_URL=${backendUrl} && python3 -m http.server ${frontendPort} --bind 127.0.0.1 --directory build/web`,
      cwd: frontendDirectory,
      url: frontendUrl,
      timeout: 180_000,
      reuseExistingServer: true,
      env: process.env,
    },
  ],
});
