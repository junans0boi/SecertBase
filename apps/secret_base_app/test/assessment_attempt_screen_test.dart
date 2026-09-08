import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_attempt_api.dart';
import 'package:secret_base_app/core/assessment_catalog_api.dart';
import 'package:secret_base_app/screens/relationship/assessment_attempt_screen.dart';

const _attemptResponse = {
  'id': 42,
  'assessmentCode': 'attachment',
  'version': 'v1',
  'status': 'in_progress',
  'startedAt': '2026-09-08T10:00:00.000Z',
  'updatedAt': '2026-09-08T10:01:00.000Z',
  'progress': {
    'answeredCount': 0,
    'totalCount': 1,
    'percentage': 0,
    'lastSavedAt': null,
  },
  'answers': <Map<String, dynamic>>[],
};

final _assessment = AssessmentCatalogItem(
  code: 'attachment',
  audience: AssessmentAudience.individual,
  title: '애착과 안정감',
  description: '설명',
  version: 'v1',
  candidateQuestionCount: 24,
  activeQuestionCount: 1,
  completionStatus: AssessmentCompletionStatus.notStarted,
  dimensions: const [
    AssessmentDimension(key: 'reassurance', title: '확인과 안심', order: 1),
  ],
  questions: const [
    AssessmentQuestion(
      key: 'q01',
      prompt: '상대의 답장이 늦으면 걱정된다.',
      dimensionKey: 'reassurance',
      reverseScored: false,
      order: 1,
      likertScale: [
        LikertOption(value: 1, label: '전혀 그렇지 않다'),
        LikertOption(value: 2, label: '그렇지 않다'),
        LikertOption(value: 3, label: '보통이다'),
        LikertOption(value: 4, label: '그렇다'),
        LikertOption(value: 5, label: '매우 그렇다'),
      ],
    ),
  ],
);

void main() {
  testWidgets('attempt screen resumes progress and saves a selected answer', (
    tester,
  ) async {
    var answerSaved = false;
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/submit')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'result': {
                  'assessmentCode': 'attachment',
                  'version': 'v1',
                  'dimensions': [
                    {
                      'key': 'reassurance',
                      'title': '확인과 안심',
                      'score': 80,
                      'mean': 4.2,
                      'answerCount': 1,
                    },
                  ],
                  'overallScore': 80,
                  'overallTendencyKey': 'situational_balance',
                  'overallTendency': '상황에 따라 안정감과 개인 공간을 조율하는 경향이 있어요.',
                  'disclaimer': '이 결과는 자기이해를 위한 참고 정보예요.',
                },
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final attempt = Map<String, dynamic>.from(_attemptResponse);
        if (request.method == 'PATCH') {
          answerSaved = true;
          attempt['progress'] = {
            'answeredCount': 1,
            'totalCount': 1,
            'percentage': 100,
            'lastSavedAt': '2026-09-08T10:02:00.000Z',
          };
          attempt['answers'] = [
            {
              'questionKey': 'q01',
              'value': 5,
              'savedAt': '2026-09-08T10:02:00.000Z',
            },
          ];
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({'ok': true, 'attempt': attempt})),
          request.method == 'POST' ? 201 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentAttemptScreen(assessment: _assessment, api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0/1 문항 저장됨'), findsOneWidget);
    expect(find.text('상대의 답장이 늦으면 걱정된다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.pumpAndSettle();

    expect(answerSaved, isTrue);
    expect(find.text('1/1 문항 저장됨'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assessment_submit')));
    await tester.pumpAndSettle();

    expect(find.text('검사 결과'), findsOneWidget);
    expect(
      find.byKey(const Key('assessment_result_disclaimer')),
      findsOneWidget,
    );
  });
}
