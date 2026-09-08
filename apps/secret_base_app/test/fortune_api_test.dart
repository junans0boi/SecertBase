import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/fortune_api.dart';

void main() {
  test(
    'fetches persisted fortune content through the public REST seam',
    () async {
      final api = FortuneApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/relationship/fortune/today');
          expect(request.headers['authorization'], 'Bearer jwt-token');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'date': '2026-09-08',
                'contentVersion': 'v1',
                'profileReady': true,
                'fortunes': {
                  'personal': {
                    'id': 1,
                    'type': 'personal',
                    'date': '2026-09-08',
                    'version': 'v1',
                    'status': 'fallback',
                    'result': {
                      'title': '작은 연결이 커지는 날',
                      'summary': '요약',
                      'signals': ['신호'],
                      'suggestion': '제안',
                      'generatedText': '고정 안내',
                      'disclaimer': '비임상',
                    },
                  },
                },
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final today = await api.fetchToday();

      expect(today.date, '2026-09-08');
      expect(today.personal?.title, '작은 연결이 커지는 날');
      expect(today.personal?.status, 'fallback');
    },
  );

  test(
    'regeneration uses an explicit POST and preserves the requested type',
    () async {
      final api = FortuneApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/relationship/fortune/today/regenerate',
          );
          expect(jsonDecode(request.body), {'type': 'relationship'});
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'date': '2026-09-08',
                'contentVersion': 'v1',
                'profileReady': true,
                'fortunes': {
                  'relationship': {
                    'id': 2,
                    'type': 'relationship',
                    'date': '2026-09-08',
                    'version': 'v1',
                    'status': 'fallback',
                    'result': {'title': '리듬', 'summary': '요약'},
                  },
                },
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final today = await api.regenerate(type: 'relationship');

      expect(today.relationship?.type, 'relationship');
    },
  );
}
