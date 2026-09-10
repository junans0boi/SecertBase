import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/saju_api.dart';

void main() {
  test(
    'loads the authenticated personal Saju result with both reading layers',
    () async {
      late http.Request captured;
      final api = SajuApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'ok': true,
              'status': 'ready',
              'calculationVersion': 'saju-v1-k-saju-0.1.4',
              'personal': {
                'scope': 'user',
                'mode': 'complete',
                'plain': {'title': '차분하게 중심을 잡는 날'},
                'technical': {
                  'dayPillar': {'hangul': '병오', 'hanja': '丙午'},
                },
                'inputSummary': {'calendarType': 'solar', 'birthPlace': '서울'},
                'basis': ['입춘 기준', '한국 표준시 135도'],
              },
              'relationship': null,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await api.fetch();

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/relationship/saju');
      expect(captured.headers['authorization'], 'Bearer jwt-token');
      expect(result.status, SajuStatus.ready);
      expect(result.personal?.plainTitle, '차분하게 중심을 잡는 날');
      expect(result.personal?.technical['dayPillar']['hanja'], '丙午');
    },
  );

  test(
    'posts an explicit limited-mode choice and exposes profile guidance reasons',
    () async {
      late http.Request captured;
      final api = SajuApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '{"ok":true,"status":"limited","personal":{"scope":"user","mode":"limited","limitations":["birthTimeMissing","birthPlaceMissing"]}}',
            200,
          );
        }),
      );

      final result = await api.calculate(mode: SajuMode.limited);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/relationship/saju');
      expect(jsonDecode(captured.body), {'mode': 'limited'});
      expect(result.status, SajuStatus.limited);
      expect(result.personal?.limitations, contains('birthTimeMissing'));
    },
  );

  test(
    'surfaces a missing profile reason through the public API seam',
    () async {
      final api = SajuApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient(
          (_) async => http.Response(
            '{"ok":false,"reason":"birth_profile_incomplete"}',
            422,
          ),
        ),
      );

      expect(
        () => api.fetch(),
        throwsA(
          isA<SajuApiException>().having(
            (error) => error.reason,
            'reason',
            'birth_profile_incomplete',
          ),
        ),
      );
    },
  );
}
