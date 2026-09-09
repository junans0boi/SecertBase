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
                {
                  'id': 2,
                  'version': 'v1',
                  'createdAt': '오늘',
                  'answers': [
                    {
                      'questionKey': 'q01',
                      'prompt': '가까운 사람에게 마음을 표현할 수 있다.',
                      'order': 1,
                      'dimensionTitle': '확인과 안심',
                      'value': 4,
                      'label': '그렇다',
                      'reverseScored': false,
                    },
                  ],
                  'result': result,
                },
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

    await tester.tap(find.byKey(const Key('assessment_history_open_2')));
    await tester.pumpAndSettle();
    expect(find.text('현재 결과 상세'), findsOneWidget);
    expect(find.text('당시 선택한 답변'), findsOneWidget);
    expect(find.text('가까운 사람에게 마음을 표현할 수 있다.'), findsOneWidget);
    expect(find.textContaining('그렇다'), findsOneWidget);
  });

  testWidgets('explains when there is no completed history yet', (
    tester,
  ) async {
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'ok': true, 'history': []})),
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

    expect(find.text('아직 완료한 기록이 없어요'), findsOneWidget);
    expect(find.textContaining('검사를 완료하면 결과가 이곳에 보관돼요'), findsOneWidget);
  });
}
