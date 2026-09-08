import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_attempt_api.dart';

Map<String, dynamic> _attempt({int answeredCount = 0}) => {
  'id': 42,
  'assessmentCode': 'attachment',
  'audience': 'individual',
  'coupleId': null,
  'version': 'v1',
  'status': 'in_progress',
  'startedAt': '2026-09-08T10:00:00.000Z',
  'updatedAt': '2026-09-08T10:01:00.000Z',
  'progress': {
    'answeredCount': answeredCount,
    'totalCount': 12,
    'percentage': answeredCount * 100 ~/ 12,
    'lastSavedAt': '2026-09-08T10:01:00.000Z',
  },
  'answers': [
    if (answeredCount > 0)
      {'questionKey': 'q01', 'value': 5, 'savedAt': '2026-09-08T10:01:00.000Z'},
  ],
};

void main() {
  test('starts, saves, and parses a personal assessment attempt', () async {
    final requests = <http.Request>[];
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        requests.add(request);
        final answeredCount = request.method == 'PATCH' ? 1 : 0;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'attempt': _attempt(answeredCount: answeredCount),
            }),
          ),
          request.method == 'POST' ? 201 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final started = await api.startOrResume('attachment');
    final saved = await api.saveAnswer(started.id, 'q01', 5);

    expect(requests[0].method, 'POST');
    expect(
      requests[0].url.path,
      '/api/relationship/assessments/attachment/attempt',
    );
    expect(requests[1].method, 'PATCH');
    expect(jsonDecode(requests[1].body), {'value': 5});
    expect(started.progress.answeredCount, 0);
    expect(saved.answerByQuestion, {'q01': 5});
  });

  test('starts a couple attempt through the couple-scoped endpoint', () async {
    final requests = <http.Request>[];
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'attempt': {
                ..._attempt(),
                'assessmentCode': 'conflict_repair',
                'audience': 'couple',
                'coupleId': 73,
              },
            }),
          ),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final attempt = await api.startCoupleOrResume('conflict_repair');

    expect(requests.single.method, 'POST');
    expect(
      requests.single.url.path,
      '/api/relationship/couple-assessments/conflict_repair/attempt',
    );
    expect(attempt.audience, 'couple');
    expect(attempt.coupleId, 73);
  });

  test('parses pending and ready couple result states', () async {
    final requests = <http.Request>[];
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        requests.add(request);
        final ready = request.url.path.contains('submit');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'status': ready ? 'ready' : 'pending',
              'completedMemberCount': ready ? 2 : 1,
              'requiredMemberCount': 2,
              'result': ready
                  ? {
                      'assessmentCode': 'conflict_repair',
                      'version': 'v1',
                      'dimensions': [
                        {
                          'key': 'safety',
                          'title': '대화 안전감',
                          'pairScore': 70,
                          'alignmentScore': 90,
                        },
                      ],
                      'overallScore': 70,
                      'overallAlignmentScore': 90,
                      'relationshipPatternKey': 'shared_rhythm',
                      'relationshipPattern': '비슷한 리듬',
                      'conversationPrompts': ['함께하는 시간과 개인 시간을 어떻게 조율할까요?'],
                      'disclaimer': '관계 대화용',
                    }
                  : null,
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final pending = await api.fetchCoupleResult('conflict_repair');
    final ready = await api.submitCouple(42);

    expect(requests[0].url.path, contains('/couple-assessment-results/'));
    expect(pending.status, 'pending');
    expect(pending.result, isNull);
    expect(ready.status, 'ready');
    expect(ready.result?.dimensions.single.alignmentScore, 90);
    expect(ready.result?.conversationPrompts.single, contains('조율'));
  });

  test('maps server and network errors to public reasons', () async {
    final serverApi = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async =>
            http.Response('{"ok":false,"reason":"attempt_not_found"}', 404),
      ),
    );
    expect(
      serverApi.startOrResume('attachment'),
      throwsA(
        isA<AssessmentAttemptApiException>().having(
          (error) => error.reason,
          'reason',
          'attempt_not_found',
        ),
      ),
    );

    final networkApi = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(
      networkApi.startOrResume('attachment'),
      throwsA(
        isA<AssessmentAttemptApiException>().having(
          (error) => error.reason,
          'reason',
          'network_error',
        ),
      ),
    );
  });

  test('submits an attempt and reads the current private result', () async {
    final result = {
      'assessmentCode': 'attachment',
      'version': 'v1',
      'dimensions': [
        {
          'key': 'reassurance',
          'title': '확인과 안심',
          'score': 60,
          'mean': 3.4,
          'answerCount': 4,
        },
      ],
      'overallScore': 60,
      'overallTendencyKey': 'situational_balance',
      'overallTendency': '상황에 따라 안정감과 개인 공간을 조율하는 경향이 있어요.',
      'disclaimer': '자기이해용 결과예요.',
    };
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'ok': true, 'result': result})),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final submitted = await api.submit(42);
    final current = await api.fetchCurrentResult('attachment');

    expect(submitted.overallScore, 60);
    expect(current?.dimensions.single.title, '확인과 안심');
    expect(current?.disclaimer, '자기이해용 결과예요.');
  });

  test('reads completed result history without exposing answers', () async {
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'history': [
                {
                  'id': 7,
                  'version': 'v1',
                  'createdAt': '2026-09-08T10:00:00.000Z',
                  'result': {
                    'assessmentCode': 'attachment',
                    'version': 'v1',
                    'dimensions': [],
                    'overallScore': 50,
                    'overallTendencyKey': 'situational_balance',
                    'overallTendency': '경향',
                    'disclaimer': '자기이해용',
                  },
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final history = await api.fetchHistory('attachment');

    expect(history.single.id, 7);
    expect(history.single.result.overallScore, 50);
  });

  test('keeps social bonding dimensions in the shared result model', () async {
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'result': {
                'assessmentCode': 'social_bonding',
                'version': 'v1',
                'dimensions': [
                  {
                    'key': 'depth',
                    'title': '관계의 깊이',
                    'score': 70,
                    'mean': 3.8,
                    'answerCount': 4,
                  },
                ],
                'overallScore': 60,
                'overallTendencyKey': 'developing_connections',
                'overallTendency': '관계의 깊이를 넓혀가는 경향이 있어요.',
                'disclaimer': '자기이해용',
              },
            }),
          ),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    final result = await api.submit(99);

    expect(result.assessmentCode, 'social_bonding');
    expect(result.dimensions.single.key, 'depth');
  });

  test(
    'keeps emotional regulation dimensions in the shared result model',
    () async {
      final api = AssessmentAttemptApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'result': {
                  'assessmentCode': 'emotional_regulation',
                  'version': 'v1',
                  'dimensions': [
                    {
                      'key': 'internal',
                      'title': '내부 처리',
                      'score': 70,
                      'mean': 3.8,
                      'answerCount': 4,
                    },
                  ],
                  'overallScore': 60,
                  'overallTendencyKey': 'mixed_regulation',
                  'overallTendency': '감정을 섞어 조절하는 경향이 있어요.',
                  'disclaimer': '자기이해용',
                },
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final result = await api.submit(100);

      expect(result.assessmentCode, 'emotional_regulation');
      expect(result.dimensions.single.key, 'internal');
    },
  );

  test(
    'keeps relationship deficiency language in the shared result model',
    () async {
      final api = AssessmentAttemptApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'result': {
                  'assessmentCode': 'relationship_deficiency',
                  'version': 'v1',
                  'dimensions': [
                    {
                      'key': 'self_awareness',
                      'title': '자기 인식',
                      'score': 65,
                      'mean': 3.6,
                      'answerCount': 4,
                    },
                  ],
                  'overallScore': 60,
                  'overallTendencyKey': 'needs_in_context',
                  'overallTendency': '관계 안팎의 필요와 자원을 상황에 맞게 살펴보는 경향이 있어요.',
                  'disclaimer': '자기이해용',
                },
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final result = await api.submit(101);

      expect(result.assessmentCode, 'relationship_deficiency');
      expect(result.overallTendency, contains('살펴보는'));
    },
  );
}
