import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_attempt_api.dart';

Map<String, dynamic> _attempt({int answeredCount = 0}) => {
  'id': 42,
  'assessmentCode': 'attachment',
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
}
