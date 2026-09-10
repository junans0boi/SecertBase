import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/mindcare_api.dart';
import 'package:secret_base_app/screens/relationship/mindcare_screen.dart';

void main() {
  testWidgets('mindcare screen shows warm bubbles and quick choices', (
    tester,
  ) async {
    final api = MindcareApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'ok': true, 'sessions': []})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'session': {
                'id': 7,
                'status': 'active',
                'currentState': 'emotion',
                'userResponseCount': 0,
                'ownerOnly': true,
              },
              'messages': [
                {
                  'id': 1,
                  'sequence': 1,
                  'role': 'assistant',
                  'content': '지금 마음을 안전한 속도로 살펴볼게요.',
                },
              ],
              'choices': [
                {'key': 'anxious', 'label': '불안해요'},
                {'key': 'sad', 'label': '슬퍼요'},
              ],
              'nextQuestion': {
                'key': 'emotion',
                'text': '어떤 감정이 가까우세요?',
                'allowFreeText': false,
              },
              'state': {},
            }),
          ),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: MindcareScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('마음관리'), findsOneWidget);
    expect(find.text('지금 마음을 안전한 속도로 살펴볼게요.'), findsOneWidget);
    expect(find.text('불안해요'), findsOneWidget);
    expect(find.textContaining('파트너와 자동으로 공유되지 않아요.'), findsOneWidget);
  });
}
