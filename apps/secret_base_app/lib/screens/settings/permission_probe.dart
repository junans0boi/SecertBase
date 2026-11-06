import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'permission_probe_stub.dart'
    if (dart.library.js_interop) 'permission_probe_web.dart'
    as web;

/// OS permission state as the 개인정보·권한 page shows it.
enum OsPermission {
  /// 허용됨.
  granted,

  /// 꺼짐 (거부했거나 아직 허용하지 않음).
  denied,

  /// 아직 물어보지 않았어요 — 쓰는 순간에 물어봐요.
  notAsked,

  /// 이 기기·브라우저에서는 알 수 없어요.
  unknown,
}

/// Reads OS permission states without ever prompting. Injectable for tests.
abstract class PermissionProbe {
  const PermissionProbe();

  Future<OsPermission> notification();
  Future<OsPermission> location();

  /// Whether [openSettings] can take the user to the system settings
  /// (false on the web: browsers have no such page to open).
  bool get canOpenSettings;

  /// Opens the app's system settings page. Returns false when it could not.
  Future<bool> openSettings();
}

/// Real device/browser probe. Every call is wrapped so a missing plugin or
/// an unconfigured Firebase never breaks the settings screens.
class DevicePermissionProbe extends PermissionProbe {
  const DevicePermissionProbe();

  @override
  Future<OsPermission> notification() async {
    if (kIsWeb) {
      return switch (web.webNotificationPermission()) {
        'granted' => OsPermission.granted,
        'denied' => OsPermission.denied,
        'default' => OsPermission.notAsked,
        _ => OsPermission.unknown,
      };
    }
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => OsPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => OsPermission.denied,
        AuthorizationStatus.notDetermined => OsPermission.notAsked,
      };
    } catch (_) {
      return OsPermission.unknown;
    }
  }

  @override
  Future<OsPermission> location() async {
    try {
      final permission = await Geolocator.checkPermission();
      return switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => OsPermission.granted,
        LocationPermission.deniedForever => OsPermission.denied,
        LocationPermission.denied => OsPermission.notAsked,
        LocationPermission.unableToDetermine => OsPermission.unknown,
      };
    } catch (_) {
      return OsPermission.unknown;
    }
  }

  @override
  bool get canOpenSettings => !kIsWeb;

  @override
  Future<bool> openSettings() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
