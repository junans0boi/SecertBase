const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const worker = fs.readFileSync(path.join(__dirname, '../web/firebase-messaging-sw.js'), 'utf8');
const scripts = [...fs.readFileSync(path.join(__dirname, '../web/index.html'), 'utf8')
  .matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]);

function browser(runtime = {}, permission = 'granted') {
  const registered = [], sdk = [], tokenOptions = [], listeners = {};
  const registration = {scope: 'https://app.test/messaging/', active: {}};
  const messaging = {onMessage() {}, getToken: async options => {
    tokenOptions.push(options); return 'web-device-token';
  }};
  const context = {URL, Promise, JSON, encodeURIComponent,
    fetch: async () => ({ok: true, json: async () => runtime}),
    navigator: {serviceWorker: {
      addEventListener: (name, callback) => listeners[name] = callback,
      register: async (url, options) => { registered.push({url, options}); return registration; },
    }},
    Notification: {permission, requestPermission: async () => permission},
    document: {createElement: () => ({}), head: {appendChild(script) {
      sdk.push(script.src); queueMicrotask(() => script.onload());
    }}},
    firebase: {initializeApp: () => ({messaging: () => messaging})},
  };
  context.window = context;
  vm.runInNewContext(scripts[0], context);
  return {push: context.secretBasePush, registered, sdk, tokenOptions, registration, listeners};
}

test('worker configuration is generated from the same public build defines', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'secretbase-push-config-'));
  const defines = path.join(directory, 'public-test-defines.json');
  fs.writeFileSync(defines, JSON.stringify({FIREBASE_WEB_API_KEY: 'public-test-key',
    FIREBASE_WEB_APP_ID: 'web-app', FIREBASE_MESSAGING_SENDER_ID: '123',
    FIREBASE_PROJECT_ID: 'test-project', FIREBASE_WEB_VAPID_KEY: 'public-vapid'}));
  const result = spawnSync(process.execPath, [path.join(__dirname,
    '../lib/core/push/generate_worker_config.mjs'), defines, directory], {encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(directory, 'firebase-push-config.json'))), {
    firebase: {apiKey: 'public-test-key', appId: 'web-app', messagingSenderId: '123',
      projectId: 'test-project'}, vapidKey: 'public-vapid',
  });
});

test('startup cache cleanup preserves the /messaging/ registration', async () => {
  const removed = [], loaded = [];
  const context = {URL, Promise, console,
    navigator: {serviceWorker: {getRegistrations: async () => [
      {scope: 'https://app.test/messaging/', unregister: async () => removed.push('push')},
      {scope: 'https://app.test/', unregister: async () => removed.push('app')},
    ]}},
    document: {createElement: () => ({}), body: {appendChild: script => loaded.push(script.src)}},
  };
  context.window = context;
  await vm.runInNewContext(scripts[1], context);
  assert.deepEqual(removed, ['app']);
  assert.equal(loaded.length, 1);
});

test('missing config is inert without SDK downloads or worker registration', async () => {
  const page = browser();
  assert.equal(await page.push.initialize('{}', '', () => {}), false);
  assert.equal(await page.push.getToken(), null);
  assert.deepEqual(page.sdk, []);
  assert.deepEqual(page.registered, []);
});

test('runtime config registers /messaging/ and passes that exact worker to getToken', async () => {
  const page = browser({firebase: {apiKey: 'public-test-key', appId: 'web-app',
    messagingSenderId: '123', projectId: 'test-project'}, vapidKey: 'public-vapid'});
  const opened = [];
  page.listeners.message({data: {type: 'secret-base-push', target: {screen: 'moment_detail', post_id: '77'}}});
  assert.equal(await page.push.initialize('{}', '', payload => opened.push(JSON.parse(payload))), true);
  assert.equal(page.registered[0].options.scope, '/messaging/');
  assert.equal(await page.push.getToken(), 'web-device-token');
  assert.equal(page.tokenOptions[0].serviceWorkerRegistration, page.registration);
  assert.equal(page.tokenOptions[0].vapidKey, 'public-vapid');
  assert.deepEqual(opened, [{screen: 'moment_detail', post_id: '77'}]);
});

test('web token API remains gated by denied OS permission', async () => {
  const page = browser({}, 'denied');
  await page.push.initialize(JSON.stringify({apiKey: 'public-key', appId: 'web-app',
    messagingSenderId: '123', projectId: 'test-project'}), 'public-vapid', () => {});
  assert.equal(await page.push.requestPermission(), false);
  assert.equal(await page.push.getToken(), null);
  assert.deepEqual(page.tokenOptions, []);
});

test('worker click focuses an existing app and preserves the complete destination', async () => {
  const listeners = {};
  const messages = [];
  let focused = false;
  const self = {location: {origin: 'https://app.test', search: ''},
    addEventListener: (name, callback) => listeners[name] = callback,
    clients: {matchAll: async () => [{url: 'https://app.test/privacy.html',
      focus: async () => assert.fail('privacy document cannot route a push'),
      postMessage: () => assert.fail('privacy document has no app listener')}, {url: 'https://app.test/',
      focus: async () => focused = true, postMessage: value => messages.push(value)}],
      openWindow: async () => assert.fail('existing app should receive the click')}};
  vm.runInNewContext(worker, {self, URL, URLSearchParams, importScripts() {}});
  let done;
  const target = {screen: 'game_invite', game_type: 'uno', room_code: 'COUPLE'};
  listeners.notificationclick({notification: {close() {}, data: {FCM_MSG: {data: target}}},
    stopImmediatePropagation() {}, waitUntil: promise => done = promise});
  await done;
  assert.equal(focused, true);
  assert.deepEqual(JSON.parse(JSON.stringify(messages)), [{type: 'secret-base-push', target}]);
});

test('cold click opens the app with every destination field in its query', async () => {
  const listeners = {};
  let opened;
  const self = {location: {origin: 'https://app.test', search: ''},
    addEventListener: (name, callback) => listeners[name] = callback,
    clients: {matchAll: async () => [], openWindow: async url => opened = url}};
  vm.runInNewContext(worker, {self, URL, URLSearchParams, importScripts() {}});
  let done;
  listeners.notificationclick({notification: {close() {}, data:
    {screen: 'moment_draft', draft_id: 'draft / 42', post_id: '77'}},
    stopImmediatePropagation() {}, waitUntil: promise => done = promise});
  await done;
  const url = new URL(opened, 'https://app.test');
  assert.equal(url.searchParams.get('screen'), 'moment_draft');
  assert.equal(url.searchParams.get('draft_id'), 'draft / 42');
  assert.equal(url.searchParams.get('post_id'), '77');
});
