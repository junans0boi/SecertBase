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

  momentDateTests();
  todayMomentFlagTests();
}

void todayMomentFlagTests() {
  Future<List<Map<String, String>>> saveWith(
    WidgetTester tester, {
    required bool checkToday,
  }) async {
    final posted = <Map<String, String>>[];
    final api = MockClient((request) async {
      if (request.method == 'POST') {
        final body = String.fromCharCodes(request.bodyBytes);
        final fields = <String, String>{};
        for (final key in ['taken_at', 'today_moment']) {
          final m = RegExp('name="$key"\\r\\n\\r\\n([^\\r]*)').firstMatch(body);
          if (m != null) fields[key] = m.group(1)!;
        }
        posted.add(fields);
        return http.Response(
          jsonEncode({
            'ok': true,
            'post': {'id': 1, 'user_id': 7, 'media_type': 'text'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'ok': true, 'posts': [], 'pins': []}),
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
    await tester.tap(find.byKey(const Key('moment_empty_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'today');
    if (checkToday) {
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('공유'));
    await tester.pumpAndSettle();
    return posted;
  }

  testWidgets('saving without the toggle does not send today_moment', (
    tester,
  ) async {
    final posted = await saveWith(tester, checkToday: false);
    expect(posted, hasLength(1));
    expect(posted.single.containsKey('today_moment'), isFalse);
  });

  testWidgets('saving with the toggle sends today_moment=true', (tester) async {
    final posted = await saveWith(tester, checkToday: true);
    expect(posted, hasLength(1));
    expect(posted.single['today_moment'], 'true');
  });
}

void momentDateTests() {
  testWidgets('create page uploads with the chosen shooting date, not today', (
    tester,
  ) async {
    final posted = <Map<String, String>>[];
    final api = MockClient((request) async {
      if (request.method == 'POST') {
        final body = request.bodyBytes.isEmpty
            ? ''
            : String.fromCharCodes(request.bodyBytes);
        final fields = <String, String>{};
        for (final key in ['taken_at', 'captured_at', 'today_moment']) {
          final m = RegExp('name="$key"\\r\\n\\r\\n([^\\r]*)').firstMatch(body);
          if (m != null) fields[key] = m.group(1)!;
        }
        posted.add(fields);
        return http.Response(
          jsonEncode({
            'ok': true,
            'post': {
              'id': 1,
              'user_id': 7,
              'media_type': 'text',
              'caption': 'old day',
              'taken_at': fields['taken_at'],
              'captured_at': fields['captured_at'],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'ok': true, 'posts': [], 'pins': []}),
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

    await tester.tap(find.byKey(const Key('moment_empty_create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moment_date_tile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('moment_date_tile')));
    await tester.pumpAndSettle();

    // Pick the 1st of the current month in the date picker, which is a past day
    // unless today is the 1st.
    final now = DateTime.now();
    final pastDay = now.day == 1 ? 2 : 1;
    await tester.tap(find.text('$pastDay').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'old day');
    await tester.tap(find.text('공유'));
    await tester.pumpAndSettle();

    expect(posted, hasLength(1));
    final expected =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${pastDay.toString().padLeft(2, '0')}';
    expect(posted.single['taken_at'], expected);
    expect(posted.single['captured_at'], startsWith(expected));
  });
}
