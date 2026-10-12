import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/arcade/games/marble_screen.dart';

void main() {
  test('monopoly reasons match the server marble-engine winReason values', () {
    for (final r in ['tourist_monopoly', 'double_monopoly', 'line_monopoly']) {
      expect(marbleMonopolyReasons, contains(r));
    }
  });
}
