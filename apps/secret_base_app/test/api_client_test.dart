import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/core/http/api_exception.dart';

void main() {
  test('decodes a successful JSON response and joins the base URI', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.test/root/api/items');
      expect(request.headers['Authorization'], 'Bearer token-123');
      return http.Response(
        jsonEncode({
          'items': [1, 2],
        }),
        200,
      );
    });
    final api = ApiClient(
      baseUrl: 'https://example.test/root/',
      tokenProvider: () => 'token-123',
      client: client,
    );

    expect(await api.getJson('/api/items'), {
      'items': [1, 2],
    });
  });

  test('maps JSON 401 and 403 responses to ApiException', () async {
    final unauthorized = ApiClient(
      baseUrl: 'https://example.test',
      tokenProvider: () => null,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'reason': 'invalid_token', 'message': 'expired'}),
          401,
        ),
      ),
    );
    final forbidden = ApiClient(
      baseUrl: 'https://example.test',
      tokenProvider: () => null,
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'code': 'couple_scope_required'}), 403),
      ),
    );

    await expectLater(
      unauthorized.getJson('api/private'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 401)
            .having((error) => error.code, 'code', 'invalid_token')
            .having((error) => error.message, 'message', 'expired'),
      ),
    );
    await expectLater(
      forbidden.getJson('api/private'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.code, 'code', 'couple_scope_required'),
      ),
    );
  });

  test(
    'maps a non-JSON server error without exposing the response body',
    () async {
      final api = ApiClient(
        baseUrl: 'https://example.test',
        tokenProvider: () => null,
        client: MockClient((_) async => http.Response('proxy exploded', 500)),
      );

      await expectLater(
        api.getJson('api/unstable'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', 500)
              .having((error) => error.code, 'code', 'server_error')
              .having(
                (error) => error.message.contains('proxy exploded'),
                'does not expose body',
                isFalse,
              ),
        ),
      );
    },
  );

  test('maps transport failures to a network ApiException', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      tokenProvider: () => null,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    await expectLater(
      api.getJson('api/offline'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', isNull)
            .having((error) => error.code, 'code', 'network_error'),
      ),
    );
  });

  test(
    'encodes JSON request bodies and does not overwrite a caller auth header',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['content-type'], contains('application/json'));
        expect(request.headers['Authorization'], 'Bearer explicit-token');
        expect(jsonDecode(request.body), {'name': 'secret'});
        return http.Response('', 204);
      });
      final api = ApiClient(
        baseUrl: 'https://example.test',
        tokenProvider: () => 'fallback-token',
        client: client,
      );

      expect(
        await api.postJson(
          'api/items',
          body: {'name': 'secret'},
          headers: {'Authorization': 'Bearer explicit-token'},
        ),
        isNull,
      );
    },
  );

  test(
    'uploads get their own, longer timeout (3 minutes by default)',
    () async {
      expect(ApiClient.defaultUploadTimeout, const Duration(seconds: 180));
      final api = ApiClient(
        baseUrl: 'https://example.test',
        tokenProvider: () => null,
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          return http.Response('{"ok":true}', 200);
        }),
      );

      expect(await api.sendMultipart('api/upload'), {'ok': true});
      await expectLater(
        api.getJson('api/slow'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
      );
    },
  );

  test('times out a hung request with an ApiException', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      tokenProvider: () => null,
      timeout: const Duration(milliseconds: 50),
      client: MockClient((_) => Completer<http.Response>().future),
    );

    await expectLater(
      api.getJson('api/hung'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', isNull)
            .having((error) => error.code, 'code', 'timeout')
            .having(
              (error) => error.message,
              'message',
              'Network request timed out',
            ),
      ),
    );
  });

  test('invokes onUnauthorized on 401 only', () async {
    var calls = 0;
    ApiClient build(int status) => ApiClient(
      baseUrl: 'https://example.test',
      tokenProvider: () => 'token',
      onUnauthorized: () => calls++,
      client: MockClient((_) async => http.Response('{}', status)),
    );

    await expectLater(
      build(500).getJson('api/x'),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      build(403).getJson('api/x'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);

    await expectLater(
      build(401).getJson('api/x'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });
}
