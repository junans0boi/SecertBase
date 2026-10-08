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
}
