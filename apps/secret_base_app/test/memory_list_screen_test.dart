import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/home/memory_list_screen.dart';

Widget _app() => const MaterialApp(
  home: MemoryListScreen(
    baseUrl: 'https://secretbase.example',
    authHeaders: {},
  ),
);

void main() {
  testWidgets('HTML error page becomes the error state, retry clears it', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('<html>502</html>', 200);
      return http.Response('{"ok":true,"posts":[]}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('네트워크 연결을 확인해주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('네트워크 연결을 확인해주세요.'), findsNothing);
      expect(find.text('아직 되짚어볼 기억이 없어요'), findsOneWidget);
    }, () => client);
  });

  testWidgets('non-2xx status shows the error state', (tester) async {
    final client = MockClient((_) async => http.Response('{"ok":true}', 500));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('기억을 불러오지 못했어요.'), findsOneWidget);
    }, () => client);
  });
}
