import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/archive/personal_history_screen.dart';

void main() {
  testWidgets('personal history explains its private empty state', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'moments': [], 'pins': []}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: PersonalHistoryScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('나만 보는 개인 기록이에요. 필요하면 ZIP 파일로 내보낼 수 있어요.'),
      findsOneWidget,
    );
    expect(find.text('내 MomentLoop'), findsOneWidget);
    expect(find.text('보관된 기록이 없어요.'), findsOneWidget);
    expect(find.text('보관된 장소가 없어요.'), findsOneWidget);
  });

  testWidgets('personal history exposes a retry after loading failure', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );

    await tester.pumpWidget(
      MaterialApp(home: PersonalHistoryScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('개인 보관함을 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsOneWidget);
  });
}
