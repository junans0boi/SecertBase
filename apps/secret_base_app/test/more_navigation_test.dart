import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/home_shell.dart';

void main() {
  testWidgets('more details keep the shell navigation visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('내 공간'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 이모지'), findsOneWidget);
    expect(find.text('기념일 추가'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
