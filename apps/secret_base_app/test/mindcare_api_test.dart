import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/mindcare_api.dart';

void main() {
  test(
    'mindcare API parses private guided session and posts a choice',
    () async {
      final api = MindcareApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/relationship/mindcare/sessions/7/messages',
          );
          expect(request.headers['authorization'], 'Bearer jwt-token');
          expect(jsonDecode(request.body), {'choiceKey': 'anxious'});
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'session': {
                  'id': 7,
                  'status': 'active',
                  'currentState': 'emotion_detail',
                  'userResponseCount': 1,
                  'ownerOnly': true,
                },
                'messages': [
                  {
                    'id': 1,
                    'sequence': 1,
                    'role': 'assistant',
                    'content': '어떤 감정이 가까우세요?',
                  },
                  {
                    'id': 2,
                    'sequence': 2,
                    'role': 'user',
                    'content': '불안해요',
                    'choiceKey': 'anxious',
                  },
                  {
                    'id': 3,
                    'sequence': 3,
                    'role': 'assistant',
                    'content': '몸과 생각을 조금 더 살펴볼게요.',
                  },
                ],
                'choices': const [],
                'nextQuestion': {
                  'key': 'emotion_detail',
                  'text': '몸과 생각에서 느껴지는 점을 적어주실래요?',
                  'allowFreeText': true,
                },
                'state': {'emotion': 'anxious'},
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final conversation = await api.sendMessage(id: 7, choiceKey: 'anxious');
      expect(conversation.session.currentState, 'emotion_detail');
      expect(conversation.session.ownerOnly, isTrue);
      expect(conversation.messages, hasLength(3));
      expect(conversation.nextQuestion!.allowFreeText, isTrue);
    },
  );

  test('mindcare safety response remains typed at the API boundary', () async {
    final api = MindcareApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/api/relationship/mindcare/sessions/7/safety',
        );
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
              'messages': [],
              'choices': [],
              'nextQuestion': {
                'key': 'emotion',
                'text': '어떤 감정이 가까우세요?',
                'allowFreeText': false,
              },
              'state': {},
              'safety': {'status': 'confirmed_safe'},
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final conversation = await api.confirmSafety(id: 7, safeNow: true);
    expect(conversation.safetyStatus, 'confirmed_safe');
    expect(conversation.session.status, 'active');
  });
}
