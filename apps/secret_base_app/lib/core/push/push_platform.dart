import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin seam over Firebase so [PushService] is testable and so a missing
/// Firebase config can never break the app: [init] throws, the caller catches.
abstract class PushPlatform {
  String get platformName;
  Future<void> init();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<bool> requestPermission();

  /// Emits the payload `screen` when the user taps a notification.
  Stream<String> get onOpened;

  /// `screen` of the notification that cold-started the app, if any.
  Future<String?> initialScreen();
}

// Web needs explicit options; supply them via --dart-define (see docs/PUSH_SETUP.md).
// Android reads google-services.json, so it needs no Dart-side options.
const _webOptions = FirebaseOptions(
  apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY'),
  appId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
  messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
  projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
);
const _vapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

class FirebasePushPlatform implements PushPlatform {
  final _opened = StreamController<String>.broadcast();
  final _local = FlutterLocalNotificationsPlugin();

  @override
  String get platformName => kIsWeb ? 'web' : 'android';

  @override
  Stream<String> get onOpened => _opened.stream;

  @override
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<void> init() async {
    if (kIsWeb) {
      if (_webOptions.apiKey.isEmpty || _vapidKey.isEmpty) {
        throw StateError('Firebase web config not provided');
      }
      await Firebase.initializeApp(options: _webOptions);
    } else {
      await Firebase.initializeApp(); // throws without google-services.json
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final screen = response.payload;
          if (screen != null && screen.isNotEmpty) _opened.add(screen);
        },
      );
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final screen = message.data['screen'];
      if (screen is String && screen.isNotEmpty) _opened.add(screen);
    });
    // FCM does not draw a system notification while the app is foregrounded.
    if (!kIsWeb) FirebaseMessaging.onMessage.listen(_showForeground);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      id: message.hashCode,
      title: n.title,
      body: n.body,
      payload: message.data['screen'] as String?,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'secret_base_default',
          '비밀기지 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken(
    vapidKey: kIsWeb ? _vapidKey : null,
  );

  @override
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> initialScreen() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    final screen = message?.data['screen'];
    return screen is String && screen.isNotEmpty ? screen : null;
  }
}
