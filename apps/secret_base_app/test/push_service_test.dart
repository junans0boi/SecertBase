import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/core/push/push_platform.dart';
import 'package:secret_base_app/core/push/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlatform implements PushPlatform {
  _FakePlatform({this.failInit = false});
  final bool failInit;
  int permissionRequests = 0;
  final refresh = StreamController<String>.broadcast();
  final opened = StreamController<String>.broadcast();

  @override
  String get platformName => 'android';
  @override
  Future<void> init() async {
    if (failInit) throw StateError('no firebase config');
  }

  @override
  Future<String?> getToken() async => 'tok-1';
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Stream<String> get onOpened => opened.stream;
  @override
  Future<String?> initialScreen() async => null;
}

void main() {
  late List<http.Request> requests;
  late ApiClient api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    api = ApiClient(
      baseUrl: 'http://x.test',
      tokenProvider: () => 'jwt',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  test('init failure (no Firebase config) disables push silently', () async {
    final service = PushService(platform: _FakePlatform(failInit: true));
    await service.start();
    await service.sync(api: api, loggedIn: true, paired: true);
    expect(service.enabled, isFalse);
    expect(requests, isEmpty);
  });

  test('permission is asked only after pairing, once; token registered', () async {
    final platform = _FakePlatform();
    final service = PushService(platform: platform);
    await service.start();

    await service.sync(api: api, loggedIn: true, paired: false);
    expect(platform.permissionRequests, 0);

    await service.sync(api: api, loggedIn: true, paired: true);
    await service.sync(api: api, loggedIn: true, paired: true);
    expect(platform.permissionRequests, 1);

    final posts = requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(1)); // deduped
    expect(posts.single.url.path, '/api/device-token');
    expect(jsonDecode(posts.single.body), {'token': 'tok-1', 'platform': 'android'});
  });

  test('token refresh re-registers and logout revokes', () async {
    final platform = _FakePlatform();
    final service = PushService(platform: platform);
    await service.start();
    await service.sync(api: api, loggedIn: true, paired: true);

    platform.refresh.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(requests.last.method, 'POST');
    expect(jsonDecode(requests.last.body)['token'], 'tok-2');

    await service.revoke();
    expect(requests.last.method, 'DELETE');
    expect(jsonDecode(requests.last.body), {'token': 'tok-2'});
  });

  test('notification tap sets the pending screen; payload maps to tabs', () async {
    final platform = _FakePlatform();
    await PushService(platform: platform).start();
    platform.opened.add('game_invite');
    await Future<void>.delayed(Duration.zero);
    expect(pendingPushScreen.value, 'game_invite');
    expect(tabForPushScreen('moment_detail'), 1);
    expect(tabForPushScreen('today_loop'), 0);
    expect(tabForPushScreen('game_invite'), 3);
    expect(tabForPushScreen('nope'), isNull);
    pendingPushScreen.value = null;
  });
}
