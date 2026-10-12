import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';
import 'push_target.dart';
import 'push_web_stub.dart' if (dart.library.js_interop) 'push_web.dart' as web;

/// Thin seam over Firebase so [PushService] is testable and so a missing
/// Firebase config can never break the app: [init] throws, the caller catches.
abstract class PushPlatform {
  String get platformName;
  Future<void> init();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<bool> requestPermission();
  Future<bool> permissionGranted();

  /// Emits the full destination when the user taps a notification.
  Stream<PushTarget> get onOpened;

  /// Destination of the notification that cold-started the app, if any.
  Future<PushTarget?> initialTarget();
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
  final _opened = StreamController<PushTarget>.broadcast();

  @override
  String get platformName => kIsWeb ? 'web' : 'android';

  @override
  Stream<PushTarget> get onOpened => _opened.stream;

  @override
  Stream<String> get onTokenRefresh =>
      kIsWeb ? web.onTokenRefresh : FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<void> init() async {
    if (kIsWeb) {
      await web.initialize(_webOptions, _vapidKey, _opened.add);
      return;
    } else {
      await Firebase.initializeApp(); // throws without google-services.json
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final target = PushTarget.fromData(message.data);
      if (target != null) _opened.add(target);
    });
    // FCM does not draw a system notification while the app is foregrounded.
    if (!kIsWeb) FirebaseMessaging.onMessage.listen(_showForeground);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final target = PushTarget.fromData(message.data);
    if (target == null) return;
    await LocalNotificationService.instance.show(
      id: message.hashCode,
      title: n.title ?? '비밀기지 알림',
      body: n.body ?? '',
      target: target,
    );
  }

  @override
  Future<String?> getToken() =>
      kIsWeb ? web.getToken() : FirebaseMessaging.instance.getToken();

  @override
  Future<bool> permissionGranted() async {
    if (kIsWeb) return web.permissionGranted();
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return web.requestPermission();
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<PushTarget?> initialTarget() async {
    if (kIsWeb) return PushTarget.fromUri(Uri.base);
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : PushTarget.fromData(message.data);
  }
}
