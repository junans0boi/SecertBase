import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/main.dart';

void main() {
  testWidgets('renders lobby title', (tester) async {
    await tester.pumpWidget(const SecretBaseApp());

    expect(find.text('Secret Base · Realtime MVP'), findsOneWidget);
  });
}
