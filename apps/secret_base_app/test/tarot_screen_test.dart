import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/tarot_api.dart';
import 'package:secret_base_app/screens/relationship/tarot_screen.dart';

void main() {
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
    expect(find.text('우리의 관계 타로'), findsOneWidget);
    expect(find.text('태양'), findsOneWidget);
    expect(find.text('다시 뽑기'), findsNothing);
  });
}
