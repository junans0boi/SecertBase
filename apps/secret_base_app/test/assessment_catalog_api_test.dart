import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_catalog_api.dart';

void main() {
  test('parses versioned assessment catalog and active questions', () async {
    final api = AssessmentCatalogApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/relationship/assessments');
        expect(request.headers['authorization'], 'Bearer jwt-token');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'likertScale': [
                {'value': 1, 'label': '전혀 그렇지 않다'},
              ],
              'assessments': [
                {
                  'code': 'attachment',
                  'audience': 'individual',
                  'title': '애착과 안정감',
                  'description': '설명',
                  'version': 'v1',
                  'candidateQuestionCount': 24,
                  'activeQuestionCount': 12,
                  'completionStatus': 'not_started',
                  'dimensions': [
                    {'key': 'reassurance', 'title': '확인과 안심', 'order': 1},
                  ],
                  'questions': [
                    {
                      'key': 'q01',
                      'prompt': '문항',
                      'dimensionKey': 'reassurance',
                      'reverseScored': true,
                      'order': 1,
                      'likertScale': [
                        {'value': 1, 'label': '전혀 그렇지 않다'},
                      ],
                    },
                  ],
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final assessments = await api.fetch();

    expect(assessments, hasLength(1));
    expect(assessments.single.version, 'v1');
    expect(assessments.single.candidateQuestionCount, 24);
    expect(assessments.single.activeQuestionCount, 12);
    expect(assessments.single.questions.single.reverseScored, isTrue);
  });

  test('exposes server and network failures through the public API', () async {
    final serverApi = AssessmentCatalogApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async =>
            http.Response('{"ok":false,"reason":"internal_error"}', 500),
      ),
    );
    expect(
      serverApi.fetch(),
      throwsA(
        isA<AssessmentCatalogApiException>().having(
          (error) => error.reason,
          'reason',
          'internal_error',
        ),
      ),
    );

    final networkApi = AssessmentCatalogApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(
      networkApi.fetch(),
      throwsA(
        isA<AssessmentCatalogApiException>().having(
          (error) => error.reason,
          'reason',
          'network_error',
        ),
      ),
    );
  });
}
