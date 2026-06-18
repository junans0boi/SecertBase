import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/main.dart';

void main() {
  testWidgets('renders lobby title', (tester) async {
    await tester.pumpWidget(const SecretBaseApp());

    expect(find.text('두 분만의 비밀기지'), findsOneWidget);
    expect(find.text('답변 속 진심을 먹고 자라요'), findsOneWidget);
  });
}
