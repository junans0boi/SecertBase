import { spawn } from 'node:child_process';
import { readdir } from 'node:fs/promises';
import process from 'node:process';

const required = ['TEST_DATABASE_ADMIN_URL', 'TEST_REDIS_URL'];
const missing = required.filter((name) => !process.env[name]);

if (missing.length > 0) {
  process.stderr.write(
    `Integration test environment is incomplete: ${missing.join(', ')}\n`,
  );
  process.exit(1);
}

const testFiles = (await readdir(new URL('../test', import.meta.url)))
  .filter((name) => name.endsWith('.integration.test.js'))
  .map((name) => `test/${name}`)
  .sort();

const child = spawn(
  process.execPath,
  ['--test', ...testFiles],
  {
    cwd: new URL('..', import.meta.url),
    env: process.env,
    stdio: 'inherit',
  },
);

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exitCode = code ?? 1;
});
