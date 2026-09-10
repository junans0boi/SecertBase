import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_attempt_api.dart';

void main() {
  test('assessment API parses a cute accessible comparison card', () async {
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/relationship/assessment-results/attachment/comparison',
        );
        return http.Response(
          jsonEncode({
            'ok': true,
            'status': 'ready',
            'available': true,
            'scope': 'personal',
            'metric': 'dimensionScore',
            'visualization': 'bar_or_line',
            'message': '최근 변화를 함께 살펴봐요.',
            'overall': {'previous': 50, 'current': 70, 'delta': 20},
            'dimensions': [
              {
                'key': 'reassurance',
                'title': '확인과 안심',
                'previous': 50,
                'current': 70,
                'delta': 20,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final comparison = await api.fetchComparison('attachment');
    expect(comparison.available, isTrue);
    expect(comparison.dimensions.single.delta, 20);
    expect(comparison.accessibleMessage, contains('20'));
  });
}
