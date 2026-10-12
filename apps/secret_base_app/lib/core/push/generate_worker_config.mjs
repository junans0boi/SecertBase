// Generate a public Firebase web config into an existing Flutter build.
// Firebase Admin service-account credentials NEVER belong in this file.
import {readFile, writeFile, stat} from 'node:fs/promises';
import path from 'node:path';
const [definesFile, buildDirectory] = process.argv.slice(2);
if (!buildDirectory) throw new Error('Usage: node generate_worker_config.mjs <defines.json> <build/web>');
if (!(await stat(buildDirectory)).isDirectory()) throw new Error('Build directory required');
const defines = JSON.parse(await readFile(definesFile, 'utf8'));
const keys = {
  apiKey: 'FIREBASE_WEB_API_KEY', appId: 'FIREBASE_WEB_APP_ID',
  messagingSenderId: 'FIREBASE_MESSAGING_SENDER_ID', projectId: 'FIREBASE_PROJECT_ID',
};
const firebase = Object.fromEntries(Object.entries(keys).map(([key, name]) => [key, defines[name]]));
const vapidKey = defines.FIREBASE_WEB_VAPID_KEY;
if (Object.values(firebase).some(value => typeof value !== 'string' || !value) || !vapidKey) {
  throw new Error('All five Firebase web build defines are required');
}
await writeFile(path.join(buildDirectory, 'firebase-push-config.json'),
  JSON.stringify({firebase, vapidKey}) + '\n', {mode: 0o644});
console.log('Generated public Firebase worker config.');
