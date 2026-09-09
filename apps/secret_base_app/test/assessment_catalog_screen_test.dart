import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_catalog_api.dart';
import 'package:secret_base_app/screens/relationship/assessment_catalog_screen.dart';

Map<String, dynamic> _assessment({
  required String code,
  required String audience,
  required String title,
  String completionStatus = 'not_started',
  bool hasResultHistory = false,
}) => {
  'code': code,
  'audience': audience,
  'title': title,
  'description': '검사 설명',
  'version': 'v1',
  'candidateQuestionCount': 24,
  'activeQuestionCount': 12,
  'completionStatus': completionStatus,
  'hasResultHistory': hasResultHistory,
  'dimensions': [
    {'key': 'one', 'title': '차원 하나', 'order': 1},
    {'key': 'two', 'title': '차원 둘', 'order': 2},
    {'key': 'three', 'title': '차원 셋', 'order': 3},
  ],
  'questions': const [],
};

void main() {
  testWidgets('catalog groups personal and couple tests with readiness state', (
    tester,
  ) async {
    final api = AssessmentCatalogApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'assessments': [
                _assessment(
                  code: 'attachment',
                  audience: 'individual',
                  title: '애착과 안정감',
                  completionStatus: 'completed',
                  hasResultHistory: true,
                ),
                _assessment(
                  code: 'conflict_repair',
                  audience: 'couple',
                  title: '갈등과 회복 방식',
                ),
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
        home: AssessmentCatalogScreen(api: api, hasActiveCouple: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('개인 검사'), findsOneWidget);
    expect(find.text('애착과 안정감'), findsOneWidget);
    expect(find.text('커플 검사'), findsOneWidget);
    expect(find.text('갈등과 회복 방식'), findsOneWidget);
    expect(find.text('후보 24문항 · 실제 12문항'), findsNWidgets(2));
    expect(find.text('파트너 연결 후 이용할 수 있어요'), findsOneWidget);
    expect(find.text('기록 보기'), findsOneWidget);
  });

  testWidgets('keeps result history reachable while a retake is in progress', (
    tester,
  ) async {
    final api = AssessmentCatalogApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'assessments': [
                _assessment(
                  code: 'attachment',
                  audience: 'individual',
                  title: '애착과 안정감',
                  completionStatus: 'in_progress',
                  hasResultHistory: true,
                ),
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: AssessmentCatalogScreen(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.text('기록 보기'), findsOneWidget);
  });

  testWidgets(
    'keeps history reachable when the catalog omits the history flag',
    (tester) async {
      final api = AssessmentCatalogApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'assessments': [
                  _assessment(
                    code: 'attachment',
                    audience: 'individual',
                    title: '애착과 안정감',
                    completionStatus: 'completed',
                  ),
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: AssessmentCatalogScreen(api: api)),
      );
      await tester.pumpAndSettle();

      expect(find.text('기록 보기'), findsOneWidget);
    },
  );

  testWidgets('labels the action according to the assessment state', (
    tester,
  ) async {
    final api = AssessmentCatalogApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'assessments': [
                _assessment(
                  code: 'attachment',
                  audience: 'individual',
                  title: '시작할 검사',
                ),
                _assessment(
                  code: 'social_bonding',
                  audience: 'individual',
                  title: '이어갈 검사',
                  completionStatus: 'in_progress',
                ),
                _assessment(
                  code: 'emotional_regulation',
                  audience: 'individual',
                  title: '다시할 검사',
                  completionStatus: 'completed',
                ),
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: AssessmentCatalogScreen(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.text('검사 시작하기'), findsOneWidget);
    expect(find.text('검사 이어하기'), findsOneWidget);
    expect(find.text('다시 검사하기'), findsOneWidget);
  });
}
