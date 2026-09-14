import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/archive/moment_loop_screen.dart';

void main() {
  testWidgets('empty MomentLoop explains the week and offers one clear CTA', (
    tester,
  ) async {
    final api = MockClient((request) async {
      expect(request.url.path, '/api/setlog');
      return http.Response(
        jsonEncode({'ok': true, 'posts': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MomentLoopScreen(
          client: api,
          baseUrl: 'https://secretbase.example',
          userId: 7,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MomentLoop'), findsOneWidget);
    expect(find.text('이번 주의 순간'), findsOneWidget);
    expect(find.text('이번 주 첫 순간을 남겨보세요'), findsOneWidget);
    expect(find.text('사진·짧은 영상·한 문장 중 하나면 충분해요.'), findsOneWidget);
    expect(find.byKey(const Key('moment_empty_create')), findsOneWidget);
    expect(find.byTooltip('순간 남기기'), findsOneWidget);
  });
}
