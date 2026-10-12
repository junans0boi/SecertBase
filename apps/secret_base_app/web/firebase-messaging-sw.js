// Web push service worker. The Firebase JS SDK registers this file under its own
// scope (/firebase-cloud-messaging-push-scope), separate from the app scope, so
// index.html's cache-clearing cleanup must skip it (see index.html).
//
// TODO(human): replace the placeholders below with the Firebase web app config
// (same values as the FIREBASE_WEB_* dart-defines). See docs/PUSH_SETUP.md.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: '__FIREBASE_WEB_API_KEY__',
  appId: '__FIREBASE_WEB_APP_ID__',
  messagingSenderId: '__FIREBASE_MESSAGING_SENDER_ID__',
  projectId: '__FIREBASE_PROJECT_ID__',
};

// Stay inert until configured.
if (!firebaseConfig.apiKey.startsWith('__')) {
  firebase.initializeApp(firebaseConfig);
  // Messages with a `notification` block are displayed by the SDK automatically.
  firebase.messaging();
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(self.clients.openWindow('/'));
});
