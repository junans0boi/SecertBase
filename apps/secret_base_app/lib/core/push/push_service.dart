import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../http/api_client.dart';
import 'push_platform.dart';

/// Which HomeShell tab a notification `screen` payload opens.
/// moment_detail -> MomentLoop, today_loop -> Home (Today card), game_invite -> Arcade.
int? tabForPushScreen(String? screen) => switch (screen) {
  'moment_detail' => 1,
  'today_loop' => 0,
  'game_invite' => 3,
  _ => null,
};

/// Pending notification target; HomeShell consumes it (also covers cold start).
final ValueNotifier<String?> pendingPushScreen = ValueNotifier<String?>(null);

class PushService {
  PushService({PushPlatform? platform}) : _platformOverride = platform;

  static final PushService instance = PushService();

  final PushPlatform? _platformOverride;
  PushPlatform? _platform;
  bool _enabled = false;
  bool _started = false;
  String? _registeredToken;
  ApiClient? _api;
  (bool, bool)? _lastState;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<String>? _openedSub;

  bool get enabled => _enabled;

  static const _askedKey = 'push_permission_asked';

  /// Never throws: any init failure (e.g. no Firebase config) disables push silently.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final platform = _platformOverride ?? FirebasePushPlatform();
      await platform.init();
      _platform = platform;
      _enabled = true;
      _openedSub = platform.onOpened.listen((s) => pendingPushScreen.value = s);
      _refreshSub = platform.onTokenRefresh.listen(_register);
      final initial = await platform.initialScreen();
      if (initial != null) pendingPushScreen.value = initial;
      // Auth may have settled before init finished; replay it.
      final state = _lastState;
      if (_api != null && state != null) {
        await sync(api: _api!, loggedIn: state.$1, paired: state.$2);
      }
    } catch (error) {
      _enabled = false;
      debugPrint('[Push] disabled: $error');
    }
  }

  /// Call whenever auth state changes. [paired] gates the permission prompt:
  /// it is requested right after couple connection, never at first launch.
  Future<void> sync({
    required ApiClient api,
    required bool loggedIn,
    required bool paired,
  }) async {
    _api = api;
    _lastState = (loggedIn, paired);
    if (!_enabled || !loggedIn) return;
    try {
      if (paired && await _shouldAskPermission()) {
        await _platform!.requestPermission();
      }
      final token = await _platform!.getToken();
      if (token != null) await _register(token);
    } catch (error) {
      debugPrint('[Push] sync failed: $error');
    }
  }

  Future<bool> _shouldAskPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return false;
    await prefs.setBool(_askedKey, true);
    return true;
  }

  Future<void> _register(String token) async {
    final api = _api;
    if (api == null) return;
    if (token == _registeredToken) return;
    try {
      await api.postJson(
        '/api/device-token',
        body: {'token': token, 'platform': _platform!.platformName},
      );
      _registeredToken = token;
    } catch (error) {
      debugPrint('[Push] token registration failed: $error');
    }
  }

  /// Revoke this device's token. Call BEFORE the auth token is cleared.
  Future<void> revoke() async {
    final api = _api;
    final token = _registeredToken;
    _registeredToken = null;
    if (!_enabled || api == null || token == null) return;
    try {
      await api.deleteJson('/api/device-token', body: {'token': token});
    } catch (error) {
      debugPrint('[Push] token revoke failed: $error');
    }
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
  }
}
