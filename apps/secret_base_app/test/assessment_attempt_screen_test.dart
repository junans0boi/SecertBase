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

final _coupleAssessment = AssessmentCatalogItem(
  code: 'conflict_repair',
  audience: AssessmentAudience.couple,
  title: '갈등과 회복 방식',
  description: '설명',
  version: 'v1',
  candidateQuestionCount: 24,
  activeQuestionCount: 1,
  completionStatus: AssessmentCompletionStatus.notStarted,
  dimensions: const [
    AssessmentDimension(key: 'conflict_signal', title: '갈등 신호', order: 1),
  ],
  questions: const [
    AssessmentQuestion(
      key: 'q01',
      prompt: '갈등이 생겼을 때 서로의 신호를 알아차린다.',
      dimensionKey: 'conflict_signal',
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

  testWidgets('couple attempt screen uses the private-answer notice', (
    tester,
  ) async {
    String? requestedPath;
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'attempt': {
                ..._attemptResponse,
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

    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentAttemptScreen(
          assessment: _coupleAssessment,
          api: api,
          isCouple: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requestedPath,
      '/api/relationship/couple-assessments/conflict_repair/attempt',
    );
    expect(find.text('커플 검사 진행 중'), findsOneWidget);
    expect(find.textContaining('각자의 답변은 서로에게 공개되지 않으며'), findsOneWidget);
  });

  testWidgets('couple attempt screen shows pending state after submission', (
    tester,
  ) async {
    String? requestedSubmitPath;
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/submit')) {
          requestedSubmitPath = request.url.path;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'status': 'pending',
                'completedMemberCount': 1,
                'requiredMemberCount': 2,
                'result': null,
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final attempt = Map<String, dynamic>.from(_attemptResponse);
        if (request.method == 'PATCH') {
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
        home: AssessmentAttemptScreen(
          assessment: _coupleAssessment,
          api: api,
          isCouple: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_submit')));
    await tester.pumpAndSettle();

    expect(
      requestedSubmitPath,
      '/api/relationship/couple-assessment-attempts/42/submit',
    );
    expect(find.byKey(const Key('couple_assessment_pending')), findsOneWidget);
    expect(find.text('파트너 응답을 기다리는 중'), findsOneWidget);
  });

  testWidgets('couple attempt screen renders a ready shared result', (
    tester,
  ) async {
    final api = AssessmentAttemptApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/submit')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'status': 'ready',
                'completedMemberCount': 2,
                'requiredMemberCount': 2,
                'result': {
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
                  'relationshipPattern': '두 사람의 관계 감각이 비슷한 편이에요.',
                  'conversationPrompts': ['서로의 기대를 어떻게 확인할까요?'],
                  'disclaimer': '관계 대화용 결과예요.',
                },
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final attempt = Map<String, dynamic>.from(_attemptResponse);
        if (request.method == 'PATCH') {
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
        home: AssessmentAttemptScreen(
          assessment: _coupleAssessment,
          api: api,
          isCouple: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('couple_assessment_result_summary')),
      findsOneWidget,
    );
    expect(find.textContaining('조합 70 · 조율 90'), findsOneWidget);
    expect(find.text('대화 질문'), findsOneWidget);
    expect(find.text('서로의 기대를 어떻게 확인할까요?'), findsOneWidget);
    expect(
      find.byKey(const Key('couple_assessment_result_disclaimer')),
      findsOneWidget,
    );
  });
}
