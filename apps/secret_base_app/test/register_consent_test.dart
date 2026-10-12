import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/auth/register_screen.dart';

void main() {
  testWidgets('register button stays disabled until consent is checked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    // Step 0 -> fill profile and advance to step 1.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '홍길동');
    await tester.enterText(fields.at(1), '길동');
    await tester.tap(find.text('생년월일을 선택해주세요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('회원가입'), findsOneWidget);
    expect(find.textContaining('개인정보 처리방침'), findsOneWidget);
    FilledButton button() => tester.widget(find.byType(FilledButton));
    expect(button().onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });
}
