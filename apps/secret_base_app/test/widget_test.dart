import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/main.dart';

void main() {
  testWidgets('renders lobby title', (tester) async {
    await tester.pumpWidget(const SecretBaseApp());

    expect(find.text('비밀기지'), findsOneWidget);
    expect(find.text('우리 둘만의 공간 💕'), findsOneWidget);
  });
}
