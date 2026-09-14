import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/tarot_api.dart';
import 'package:secret_base_app/screens/relationship/tarot_screen.dart';

void main() {
  testWidgets('lets the user pick a face-down card before revealing it', (
    tester,
  ) async {
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TarotScreen(
          api: TarotApi(
            baseUrl: 'https://secretbase.example',
            token: 'jwt-token',
            client: MockClient((request) async {
              if (request.method == 'GET') {
                return http.Response(
                  jsonEncode({
                    'ok': true,
                    'date': '2026-09-10',
                    'catalogVersion': 'tarot-major-v1',
                    'redrawAvailable': false,
                    'personal': {
                      'scope': 'user',
                      'drawn': false,
                      'drawRequired': true,
                      'cards': [
                        {'key': 'the_fool', 'position': 1},
                      ],
                    },
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }
              picked = true;
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'date': '2026-09-10',
                  'catalogVersion': 'tarot-major-v1',
                  'redrawAvailable': false,
                  'personal': {
                    'scope': 'user',
                    'drawn': true,
                    'drawRequired': false,
                    'card': {
                      'key': 'the_fool',
                      'title': '바보',
                      'orientation': 'upright',
                      'plain': '새로운 시작을 살펴봐요.',
                      'reflection': '오늘의 첫 걸음을 적어보세요.',
                    },
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tarot_user_pick_help')), findsOneWidget);
    expect(find.byKey(const Key('tarot_user_arc_deck')), findsOneWidget);
    expect(find.byKey(const Key('tarot_user_card_strip')), findsOneWidget);
    expect(find.text('가운데 카드를 눌러 선택하세요'), findsOneWidget);
    expect(find.byKey(const Key('tarot_pick_user_the_fool')), findsOneWidget);
    expect(find.text('바보'), findsNothing);

    await tester.tap(find.byKey(const Key('tarot_pick_user_the_fool')));
    await tester.pumpAndSettle();

    expect(picked, isTrue);
    expect(find.text('바보'), findsOneWidget);
  });

  testWidgets('shows personal and couple Tarot cards without a redraw action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TarotScreen(
          api: TarotApi(
            baseUrl: 'https://secretbase.example',
            token: 'jwt-token',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'ok': true,
                  'date': '2026-09-10',
                  'catalogVersion': 'tarot-major-v1',
                  'redrawAvailable': false,
                  'personal': {
                    'scope': 'user',
                    'card': {
                      'key': 'the_star',
                      'title': '별',
                      'orientation': 'upright',
                      'plain': '작은 희망을 다시 확인해봐요.',
                      'reflection': '오늘의 회복 신호를 적어보세요.',
                    },
                  },
                  'relationship': {
                    'scope': 'couple',
                    'card': {
                      'key': 'the_sun',
                      'title': '태양',
                      'orientation': 'upright',
                      'plain': '함께 기뻐할 순간을 찾아봐요.',
                      'reflection': '서로에게 고마웠던 일을 말해보세요.',
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
    expect(find.text('나의 타로'), findsOneWidget);
    expect(find.text('별'), findsOneWidget);
    expect(find.byKey(const Key('tarot_user_result_message')), findsOneWidget);
    expect(find.byKey(const Key('tarot_user_result_question')), findsOneWidget);
    expect(find.text('우리의 관계 타로'), findsOneWidget);
    expect(find.text('태양'), findsOneWidget);
    expect(find.text('메이저 아르카나 22장 · tarot-major-v1'), findsOneWidget);
    expect(find.text('다시 뽑기'), findsNothing);
    expect(find.text('나만 보는 타로'), findsOneWidget);
    expect(find.text('우리 둘의 관계 카드'), findsOneWidget);
  });

  testWidgets('lets the user move through the full major arcana deck', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final cards = List.generate(
      22,
      (index) => {'key': 'card_$index', 'position': index + 1},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TarotScreen(
          api: TarotApi(
            baseUrl: 'https://secretbase.example',
            token: 'jwt-token',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'ok': true,
                  'date': '2026-09-10',
                  'catalogVersion': 'tarot-major-v1',
                  'redrawAvailable': false,
                  'personal': {
                    'scope': 'user',
                    'drawn': false,
                    'drawRequired': true,
                    'cards': cards,
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

    expect(find.byKey(const Key('tarot_user_arc_deck')), findsOneWidget);
    expect(find.byKey(const Key('tarot_pick_user_card_0')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('tarot_user_card_strip')),
      const Offset(-5000, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tarot_pick_user_card_21')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
