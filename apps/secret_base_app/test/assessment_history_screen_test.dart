import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_attempt_api.dart';
import 'package:secret_base_app/screens/relationship/assessment_history_screen.dart';

void main() {
  testWidgets('history screen labels current and previous results', (
    tester,
  ) async {
    final result = {
      'assessmentCode': 'attachment',
      'version': 'v1',
      'dimensions': [],
      'overallScore': 50,
      'overallTendencyKey': 'situational_balance',
      'overallTendency': '상황에 따라 안정감과 개인 공간을 조율하는 경향이 있어요.',
      'disclaimer': '자기이해용',
    };
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'history': [
                {'id': 2, 'version': 'v1', 'createdAt': '오늘', 'result': result},
                {'id': 1, 'version': 'v1', 'createdAt': '어제', 'result': result},
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentHistoryScreen(
          title: '애착과 안정감',
          assessmentCode: 'attachment',
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('현재 결과'), findsOneWidget);
    expect(find.text('이전 결과 1'), findsOneWidget);
    expect(find.textContaining('가장 최근 결과가 현재 결과로 사용돼요'), findsOneWidget);
  });
}
