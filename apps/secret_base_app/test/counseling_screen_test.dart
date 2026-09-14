import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/counseling_api.dart';
import 'package:secret_base_app/screens/relationship/counseling_screen.dart';

Map<String, dynamic> _conversation({required String scope}) => {
  'ok': true,
  'session': {
    'id': 12,
    'scope': scope,
    'title': scope == 'private' ? '나의 상담' : '우리의 상담',
    'status': 'active',
    'messageCount': 1,
  },
  'messages': [
    {'id': 1, 'sequence': 1, 'role': 'assistant', 'content': '천천히 이야기해도 괜찮아요.'},
  ],
};

void main() {
  testWidgets('private counseling explains the boundary and shareable hint', (
    tester,
  ) async {
    final api = CounselingApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'ok': true, 'sessions': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(_conversation(scope: 'private')),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: RelationshipCounselingScreen(api: api, shared: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('상담 시작하기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('counseling_scope_card')), findsOneWidget);
    expect(find.text('프라이빗 상담'), findsOneWidget);
    expect(find.text('커플 상담에 공유할 힌트'), findsOneWidget);
    expect(find.text('천천히 이야기해도 괜찮아요.'), findsOneWidget);
  });

  testWidgets('shared counseling does not expose the private sharing control', (
    tester,
  ) async {
    final api = CounselingApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'ok': true, 'sessions': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(_conversation(scope: 'couple')),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: RelationshipCounselingScreen(api: api, shared: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('상담 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('커플 상담'), findsOneWidget);
    expect(find.text('커플 상담에 공유할 힌트'), findsNothing);
    expect(find.textContaining('개인 상담 원문은 이 공간으로 이동하지 않아요.'), findsOneWidget);
  });
}
