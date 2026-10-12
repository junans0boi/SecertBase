import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../http/api_client.dart';
import 'push_platform.dart';
import 'push_target.dart';
export 'push_target.dart';

class _TokenSession {
  _TokenSession(this.api, this.credential);
  final ApiClient api;
  final String? credential;
  final registered = <String>{};
  final attempted = <String>{};
}

class PushService {
  PushService({PushPlatform? platform}) : _platformOverride = platform;
  static final instance = PushService();
  final PushPlatform? _platformOverride;
  PushPlatform? _platform;
  bool _enabled = false;
  Future<void>? _starting;
  Future<void> _tail = Future.value();
  int _generation = 0;
  Object? _identity;
  ApiClient? _api;
  String? _authToken;
  bool _paired = false;
  _TokenSession? _session;
  final _retired = <_TokenSession>[];
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<PushTarget>? _openedSub;
  bool get enabled => _enabled;
  static const _askedKey = 'push_permission_asked';

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _tail.then((_) => operation()).catchError((Object _) {
      debugPrint('[Push] operation unavailable');
    });
    _tail = next;
    return next;
  }

  Future<void> start() => _starting ??= _start();
  Future<void> _start() async {
    final route = PushTarget.fromUri(Uri.base);
    if (route != null) pendingPushTarget.value = route;
    try {
      final platform = _platformOverride ?? FirebasePushPlatform();
      _platform = platform;
      _openedSub = platform.onOpened.listen(
        (target) => pendingPushTarget.value = target,
      );
      await platform.init();
      _enabled = true;
      _refreshSub = platform.onTokenRefresh.listen((token) {
        final generation = _generation;
        unawaited(
          _enqueue(() async {
            if (!_current(generation) || !await platform.permissionGranted()) {
              return;
            }
            if (_current(generation)) await _register(token, generation);
          }),
        );
      });
      final initial = await platform.initialTarget();
      if (initial != null) pendingPushTarget.value = initial;
      if (_api != null && _identity != null) {
        await sync(
          api: _api!,
          loggedIn: true,
          paired: _paired,
          identity: _identity,
          authToken: _authToken,
        );
      }
    } catch (_) {
      _enabled = false;
      debugPrint('[Push] configuration unavailable');
    }
  }

  bool _current(int generation) =>
      _enabled && _identity != null && generation == _generation;

  Future<void> sync({
    required ApiClient api,
    required bool loggedIn,
    required bool paired,
    Object? identity,
    String? authToken,
  }) {
    if (!loggedIn) return revoke();
    final nextIdentity = identity ?? api;
    if (_identity != nextIdentity || _authToken != authToken) {
      if (_session != null) _retired.add(_session!);
      _generation++;
      _session = _TokenSession(api, authToken);
      unawaited(_enqueue(_revokeRetired));
      _identity = nextIdentity;
    }
    _api = api;
    _authToken = authToken;
    _paired = paired;
    final generation = _generation;
    return _enqueue(() async {
      if (!_current(generation)) return;
      var permitted = await _platform!.permissionGranted();
      if (!permitted && paired) {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(_askedKey) ?? false) && _current(generation)) {
          await prefs.setBool(_askedKey, true);
          permitted = await _platform!.requestPermission();
        }
      }
      if (!permitted || !_current(generation)) return;
      final token = await _platform!.getToken();
      if (token != null && _current(generation)) {
        await _register(token, generation);
      }
    });
  }

  Map<String, String>? _headers(String? token) =>
      token == null ? null : {'Authorization': 'Bearer $token'};

  Future<void> _register(String token, int generation) async {
    if (!_current(generation)) return;
    final session = _session!;
    if (session.registered.contains(token)) return;
    session.attempted.add(token);
    await session.api.postJson(
      '/api/device-token',
      body: {'token': token, 'platform': _platform!.platformName},
      headers: _headers(session.credential),
    );
    // A late response is retained so the queued logout can revoke it.
    session.registered.add(token);
  }

  Future<void> _revokeRetired() async {
    for (final session in _retired.toList()) {
      for (final token in session.attempted.toList()) {
        try {
          await session.api.deleteJson(
            '/api/device-token',
            body: {'token': token},
            headers: _headers(session.credential),
          );
          session.attempted.remove(token);
        } catch (_) {
          debugPrint('[Push] revoke unavailable; retry on next session sync');
        }
      }
      if (session.attempted.isEmpty) _retired.remove(session);
    }
  }

  /// Fence refresh immediately, then finish registrations before DELETE.
  Future<void> revoke() {
    if (_session != null) _retired.add(_session!);
    _session = null;
    _generation++;
    _identity = null;
    _api = null;
    _authToken = null;
    pendingPushTarget.value = null;
    return _enqueue(_revokeRetired);
  }

  Future<void> dispose() async {
    await revoke();
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
  }
}
