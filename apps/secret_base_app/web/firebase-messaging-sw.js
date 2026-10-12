// Install the click handler BEFORE Firebase, which otherwise consumes clicks.
self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();
  const data = event.notification.data || {};
  const payload = data.FCM_MSG?.data || data;
  const target = {};
  for (const key of ['screen', 'post_id', 'game_type', 'room_code', 'draft_id']) {
    if (payload[key] != null) target[key] = String(payload[key]);
  }
  event.waitUntil((async () => {
    const clients = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    const app = clients.find(client => {
      const url = new URL(client.url);
      return url.origin === self.location.origin && ['/', '/index.html'].includes(url.pathname);
    });
    if (app) {
      app.postMessage({type: 'secret-base-push', target});
      await app.focus();
    } else {
      const url = new URL('/', self.location.origin);
      for (const [key, value] of Object.entries(target)) url.searchParams.set(key, value);
      await self.clients.openWindow(url.href);
    }
  })());
});

// The page registers /messaging/ with the public build/runtime Firebase config.
// No source edits, placeholder credentials, or Firebase activity when missing.
let firebaseConfig;
try {
  firebaseConfig = JSON.parse(new URLSearchParams(self.location.search).get('config') || 'null');
} catch (_) { firebaseConfig = null; }
if (firebaseConfig && ['apiKey', 'appId', 'messagingSenderId', 'projectId']
    .every(key => typeof firebaseConfig[key] === 'string' && firebaseConfig[key].length > 0)) {
  importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');
  firebase.initializeApp(firebaseConfig);
  firebase.messaging().onBackgroundMessage(payload => {
    // Firebase displays notification payloads. Only data-only messages need this.
    if (payload.notification || !payload.data?.title) return;
    return self.registration.showNotification(payload.data.title, {
      body: payload.data.body || '', data: payload.data,
    });
  });
}
