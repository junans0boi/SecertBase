import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/counseling_api.dart';

void main() {
  test(
    'private counseling request parses messages and does not change scope',
    () async {
      final api = CounselingApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/relationship/counseling/private/sessions/7/messages',
          );
          expect(request.headers['authorization'], 'Bearer jwt-token');
          expect(jsonDecode(request.body), {'content': '오늘 마음을 적어볼게'});
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'ok': true,
                'session': {
                  'id': 7,
                  'scope': 'private',
                  'title': '나만의 대화',
                  'status': 'active',
                },
                'messages': [
                  {
                    'id': 1,
                    'sequence': 1,
                    'role': 'user',
                    'content': '오늘 마음을 적어볼게',
                  },
                  {
                    'id': 2,
                    'sequence': 2,
                    'role': 'assistant',
                    'content': '천천히 살펴봐요.',
                    'generationStatus': 'fallback',
                  },
                ],
              }),
            ),
            201,
          );
        }),
      );

      final conversation = await api.sendMessage(
        shared: false,
        id: 7,
        content: '오늘 마음을 적어볼게',
      );

      expect(conversation.session.scope, 'private');
      expect(conversation.messages, hasLength(2));
      expect(conversation.messages.last.generationStatus, 'fallback');
    },
  );

  test('partner or server errors stay typed at the API boundary', () async {
    final api = CounselingApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response(
          '{"ok":false,"reason":"counseling_session_not_found"}',
          404,
        ),
      ),
    );

    expect(
      api.fetchSession(shared: false, id: 99),
      throwsA(
        isA<CounselingApiException>().having(
          (error) => error.reason,
          'reason',
          'counseling_session_not_found',
        ),
      ),
    );
  });
}
