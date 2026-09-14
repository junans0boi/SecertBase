import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/fortune_api.dart';
import 'package:secret_base_app/screens/relationship/fortune_screen.dart';

void main() {
  testWidgets('explains the daily flow and reading basis without a text wall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipFortuneScreen(
          api: FortuneApi(
            baseUrl: 'https://secretbase.example',
            token: 'jwt-token',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'ok': true,
                  'date': '2026-09-13',
                  'contentVersion': 'v1',
                  'profileReady': true,
                  'fortunes': {
                    'personal': {
                      'id': 1,
                      'type': 'personal',
                      'date': '2026-09-13',
                      'version': 'v1',
                      'result': {
                        'title': '작은 연결이 커지는 날',
                        'summary': '짧은 안부가 마음의 온도를 올려줘요.',
                        'signals': ['혼자 정리한 뒤 말하고 싶어질 수 있어요.'],
                        'suggestion': '고마웠던 일을 한 문장으로 건네보세요.',
                        'disclaimer': '자기성찰용 콘텐츠예요.',
                      },
                    },
                    'emotional_flow': {
                      'id': 2,
                      'type': 'emotional_flow',
                      'date': '2026-09-13',
                      'version': 'v1',
                      'result': {
                        'title': '마음의 날씨',
                        'summary': '해결보다 감정의 이름을 먼저 확인해보세요.',
                        'signals': ['자극을 더하기 전에 속도를 낮춰보세요.'],
                        'suggestion': '사실과 해석을 나누어 적어보세요.',
                        'disclaimer': '자기성찰용 콘텐츠예요.',
                      },
                    },
                    'relationship': {
                      'id': 3,
                      'type': 'relationship',
                      'date': '2026-09-13',
                      'version': 'v1',
                      'result': {
                        'title': '서로의 리듬을 번역하는 날',
                        'summary': '같은 행동도 두 사람에게 다른 의미일 수 있어요.',
                        'signals': ['서로의 필요를 먼저 확인해보세요.'],
                        'suggestion': '오늘 필요한 관심의 모양을 하나씩 말해보세요.',
                        'disclaimer': '자기성찰용 콘텐츠예요.',
                      },
                    },
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

    expect(find.byKey(const Key('fortune_overview')), findsOneWidget);
    expect(find.byKey(const Key('fortune_action')), findsOneWidget);
    expect(find.byKey(const Key('fortune_emotional_flow')), findsOneWidget);
    expect(find.byKey(const Key('fortune_relationship')), findsOneWidget);
    expect(find.byKey(const Key('fortune_logic')), findsOneWidget);
    expect(find.byKey(const Key('fortune_technical')), findsOneWidget);
    expect(find.text('해석 문장 다시 받기'), findsNothing);
    expect(find.text('오늘의 전체 흐름'), findsOneWidget);
    expect(find.text('나만 보는 흐름'), findsOneWidget);
    expect(find.text('오늘의 한 줄'), findsWidgets);
    expect(find.text('조심할 흐름'), findsWidgets);
    expect(find.text('힘이 되는 행동'), findsWidgets);
    expect(find.text('감정이 올라오는 속도와 잠깐 살펴볼 신호'), findsOneWidget);
    expect(find.text('생년월일·출생 정보 + 오늘 날짜'), findsOneWidget);
  });

  testWidgets('offers a profile repair action when personal fortune is empty', (
    tester,
  ) async {
    var edited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipFortuneScreen(
          onEditProfile: () => edited = true,
          api: FortuneApi(
            baseUrl: 'https://secretbase.example',
            token: 'jwt-token',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'ok': true,
                  'date': '2026-09-14',
                  'contentVersion': 'v1',
                  'profileReady': false,
                  'fortunes': {},
                }),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('출생 프로필을 저장하면 개인 운세가 준비돼요.'), findsOneWidget);
    await tester.tap(find.text('출생 프로필 수정하기'));
    expect(edited, isTrue);
  });
}
