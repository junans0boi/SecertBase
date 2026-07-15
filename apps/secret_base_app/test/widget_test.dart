import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/main.dart';
import 'package:secret_base_app/screens/arcade/arcade_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('renders the email login entry', (tester) async {
    await tester.pumpWidget(const SecretBaseApp());

    expect(find.text('비밀기지 로그인'), findsOneWidget);
    expect(find.text('계정이 없으신가요? 회원가입'), findsOneWidget);
  });

  testWidgets('public arcade exposes only MVP games', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ArcadeScreen())),
    );

    expect(find.text('윷놀이'), findsOneWidget);
    expect(find.text('폭탄 돌리기'), findsOneWidget);
    expect(find.text('가위바위보'), findsOneWidget);
    expect(find.text('UNO'), findsNothing);
    expect(find.text('주사위'), findsNothing);
  });
}
