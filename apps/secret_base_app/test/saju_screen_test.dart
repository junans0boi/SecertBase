import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/saju_api.dart';
import 'package:secret_base_app/screens/relationship/saju_screen.dart';

void main() {
  testWidgets(
    'shows plain reading first and reveals technical terms on demand',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SajuScreen(
            api: SajuApi(
              baseUrl: 'https://secretbase.example',
              token: 'jwt-token',
              client: MockClient(
                (_) async => http.Response(
                  jsonEncode({
                    'ok': true,
                    'status': 'ready',
                    'calculationVersion': 'saju-v1-k-saju-0.1.4',
                    'personal': {
                      'scope': 'user',
                      'mode': 'complete',
                      'plain': {
                        'title': '차분하게 중심을 잡는 날',
                        'summary': '오늘은 나를 천천히 살펴봐요.',
                      },
                      'technical': {
                        'chart': {
                          'day': {'hanja': '丙午', 'korean': '병오'},
                        },
                      },
                      'basis': ['k-saju 0.1.4'],
                    },
                    'relationship': null,
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('차분하게 중심을 잡는 날'), findsOneWidget);
      expect(find.text('丙午'), findsNothing);
      await tester.tap(find.byKey(const Key('saju_technical_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('丙午'), findsOneWidget);
    },
  );

  testWidgets(
    'asks before showing a limited reading when optional profile data is missing',
    (tester) async {
      var posted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SajuScreen(
            api: SajuApi(
              baseUrl: 'https://secretbase.example',
              token: 'jwt-token',
              client: MockClient((request) async {
                if (request.method == 'GET') {
                  return http.Response(
                    '{"ok":false,"reason":"saju_limited_confirmation_required",'
                    '"missingFields":["birthTimeMissing","birthPlaceMissing"]}',
                    409,
                  );
                }
                posted = true;
                return http.Response(
                  '{"ok":true,"status":"limited","personal":{"mode":"limited",'
                  '"limitations":["birthTimeMissing","birthPlaceMissing"],'
                  '"plain":{"title":"기본 명식부터 살펴봐요"}}}',
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('출생 시각과 출생지가 없어 기본 명식으로 볼까요?'), findsOneWidget);
      expect(find.text('출생정보 수정하기'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saju_limited_confirm')));
      await tester.pumpAndSettle();
      expect(posted, isTrue);
      expect(find.text('기본 명식부터 살펴봐요'), findsOneWidget);
    },
  );

  testWidgets('shows the couple Saju pattern cards without a score', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SajuScreen(
          api: SajuApi(
            baseUrl: 'https://secretbase.example',
            token: 'jwt-token',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'ok': true,
                  'status': 'ready',
                  'calculationVersion': 'saju-v1-k-saju-0.1.4',
                  'personal': {
                    'scope': 'user',
                    'mode': 'complete',
                    'plain': {'title': '내 흐름'},
                    'basis': ['k-saju 0.1.4'],
                  },
                  'relationship': {
                    'scope': 'couple',
                    'status': 'ready',
                    'patterns': [
                      {
                        'key': 'day_master_relation',
                        'title': '서로의 속도를 알아가는 사이',
                        'summary': '대화를 도와요.',
                      },
                    ],
                    'conversationQuestions': ['오늘 서로에게 필요한 것은?'],
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('우리의 관계 사주'), findsOneWidget);
    expect(find.text('서로의 속도를 알아가는 사이'), findsOneWidget);
    expect(find.textContaining('점수:'), findsNothing);
  });
}
