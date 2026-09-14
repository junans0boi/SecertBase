import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/secret_base/secret_base_screen.dart';

void main() {
  testWidgets('secret base empty state explains the next shared action', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'ok': true, 'milestones': []}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SecretBaseScreen(
          baseUrl: 'https://secret-base.test',
          authHeaders: const {},
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('우리 둘만 보는 공간'), findsOneWidget);
    expect(find.text('아직 쌓인 기록이 없어요'), findsOneWidget);
    expect(find.text('순간 남기러 가기'), findsOneWidget);
    expect(find.text('기지 엽서 둘러보기'), findsOneWidget);
  });
}
