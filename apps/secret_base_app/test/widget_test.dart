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

  testWidgets('public arcade exposes restored games without UNO branding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ArcadeScreen())),
    );

    expect(find.text('윷놀이'), findsOneWidget);
    expect(find.text('폭탄 돌리기'), findsOneWidget);
    expect(find.text('가위바위보'), findsOneWidget);
    expect(find.text('원카드'), findsOneWidget);
    expect(find.text('제로'), findsOneWidget);
    // 하나빼기는 제로로 분리 — 가위바위보 설명에서 제외.
    expect(find.text('단판, 3판, 묵찌빠 세 가지 모드'), findsOneWidget);
    // 상표 노출 금지 (ADR 0001) — 사용자 노출명은 원카드만.
    expect(find.text('UNO'), findsNothing);
    // 아직 복구되지 않은 게임.
    expect(find.text('주사위'), findsNothing);
  });
}
