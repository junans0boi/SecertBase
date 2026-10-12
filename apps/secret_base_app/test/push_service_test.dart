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
  _FakePlatform({this.failInit = false, this.allowPermission = true});
  final bool failInit;
  final bool allowPermission;
  int permissionRequests = 0;
  bool granted = false;
  PushTarget? initial;
  Completer<String?>? tokenResult;
  bool openDuringInit = false;
  int tokenRequests = 0;
  final refresh = StreamController<String>.broadcast();
  final opened = StreamController<PushTarget>.broadcast();

  @override
  String get platformName => 'android';
  @override
  Future<void> init() async {
    if (failInit) throw StateError('no firebase config');
    if (openDuringInit) {
      opened.add(const PushTarget(screen: 'moment_detail', postId: 91));
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<String?> getToken() async {
    tokenRequests++;
    return tokenResult == null ? 'tok-1' : await tokenResult!.future;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted = allowPermission;
  }

  @override
  Stream<PushTarget> get onOpened => opened.stream;
  @override
  Future<PushTarget?> initialTarget() async => initial;
  @override
  Future<bool> permissionGranted() async => granted;
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

  test(
    'logout waits for in-flight registration, revokes it, ignores refresh',
    () async {
      final registering = Completer<void>();
      final release = Completer<void>();
      api = ApiClient(
        baseUrl: 'http://x.test',
        tokenProvider: () => 'jwt',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            registering.complete();
            await release.future;
          }
          return http.Response('{"ok":true}', 200);
        }),
      );
      final platform = _FakePlatform();
      final service = PushService(platform: platform);
      await service.start();
      final sync = service.sync(api: api, loggedIn: true, paired: true);
      await registering.future;
      final logout = service.revoke();
      release.complete();
      await Future.wait([sync, logout]);
      expect(requests.map((r) => r.method), ['POST', 'DELETE']);
      platform.refresh.add('after-logout');
      await Future<void>.delayed(Duration.zero);
      expect(requests.map((r) => r.method), ['POST', 'DELETE']);
      await service.dispose();
    },
  );

  test('init failure (no Firebase config) disables push silently', () async {
    final service = PushService(platform: _FakePlatform(failInit: true));
    await service.start();
    await service.sync(api: api, loggedIn: true, paired: true);
    expect(service.enabled, isFalse);
    expect(requests, isEmpty);
  });

  test('tap arriving during platform startup is retained', () async {
    pendingPushTarget.value = null;
    final service = PushService(
      platform: _FakePlatform()..openDuringInit = true,
    );
    await service.start();
    expect(pendingPushTarget.value?.postId, 91);
    await service.dispose();
  });

  test(
    'permission is asked only after pairing, once; token registered',
    () async {
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
      expect(jsonDecode(posts.single.body), {
        'token': 'tok-1',
        'platform': 'android',
      });
    },
  );

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

  test('denied permission never requests or registers a token', () async {
    final platform = _FakePlatform(allowPermission: false);
    final service = PushService(platform: platform);
    await service.start();
    await service.sync(api: api, loggedIn: true, paired: true);
    platform.refresh.add('denied-token');
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty);
    expect(platform.tokenRequests, 0);
    await service.dispose();
  });

  test('late token retrieval after logout cannot register', () async {
    final platform = _FakePlatform()
      ..granted = true
      ..tokenResult = Completer<String?>();
    final service = PushService(platform: platform);
    await service.start();
    final sync = service.sync(api: api, loggedIn: true, paired: true);
    while (platform.tokenRequests == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    final logout = service.revoke();
    platform.tokenResult!.complete('late-token');
    await Future.wait([sync, logout]);
    expect(requests, isEmpty);
    await service.dispose();
  });

  test(
    'cold-start notification retains post and draft destination fields',
    () async {
      final platform = _FakePlatform()
        ..initial = const PushTarget(
          screen: 'moment_detail',
          postId: 77,
          draftId: 'draft / 42',
        );
      final service = PushService(platform: platform);
      await service.start();
      expect(pendingPushTarget.value?.postId, 77);
      expect(pendingPushTarget.value?.draftId, 'draft / 42');
      final uri = Uri.parse(
        'https://app.test/?screen=game_invite&game_type=uno&room_code=ROOM&post_id=77&draft_id=draft%20%2F%2042',
      );
      final target = PushTarget.fromUri(uri)!;
      expect(target.toData(), {
        'screen': 'game_invite',
        'game_type': 'uno',
        'room_code': 'ROOM',
        'post_id': 77,
        'draft_id': 'draft / 42',
      });
      await service.dispose();
    },
  );

  test(
    'failed revoke cannot suppress registration for the next identity',
    () async {
      api = ApiClient(
        baseUrl: 'http://x.test',
        tokenProvider: () => 'jwt',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"ok":true}',
            request.method == 'DELETE' ? 503 : 200,
          );
        }),
      );
      final service = PushService(platform: _FakePlatform());
      await service.start();
      await service.sync(
        api: api,
        loggedIn: true,
        paired: true,
        identity: 'alice',
      );
      await service.revoke();
      await service.sync(
        api: api,
        loggedIn: true,
        paired: true,
        identity: 'bob',
      );
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(2),
      );
      await service.dispose();
    },
  );

  test(
    'same device upserts again for each login identity and app start',
    () async {
      final platform = _FakePlatform();
      final service = PushService(platform: platform);
      await service.start();
      await service.sync(
        api: api,
        loggedIn: true,
        paired: true,
        identity: 'alice',
      );
      await service.sync(
        api: api,
        loggedIn: true,
        paired: true,
        identity: 'alice',
      );
      await service.revoke();
      await service.sync(
        api: api,
        loggedIn: true,
        paired: true,
        identity: 'bob',
      );
      expect(requests.map((r) => r.method), ['POST', 'DELETE', 'POST']);
      await service.dispose();
      final restarted = PushService(platform: _FakePlatform()..granted = true);
      await restarted.start();
      await restarted.sync(
        api: api,
        loggedIn: true,
        paired: true,
        identity: 'bob',
      );
      expect(requests.last.method, 'POST');
      await restarted.dispose();
    },
  );

  test(
    'notification tap sets the pending screen; payload maps to tabs',
    () async {
      final platform = _FakePlatform();
      await PushService(platform: platform).start();
      platform.opened.add(
        const PushTarget(
          screen: 'game_invite',
          gameType: 'uno',
          roomCode: 'ROOM',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(pendingPushTarget.value?.gameType, 'uno');
      expect(pendingPushTarget.value?.roomCode, 'ROOM');
      pendingPushTarget.value = null;
    },
  );
}
