import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/v2/v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contrast helper matches known WCAG values', () {
    expect(V2Contrast.ratio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(V2Contrast.ratio(Colors.white, Colors.white), closeTo(1, 0.001));
    // Order does not matter.
    expect(
      V2Contrast.ratio(V2Colors.ink, V2Colors.bg),
      V2Contrast.ratio(V2Colors.bg, V2Colors.ink),
    );
  });

  test('every registered text/background pair meets its AA minimum', () {
    final failures = <String>[];
    for (final (label, fg, bg, min) in V2Contrast.pairs) {
      final r = V2Contrast.ratio(fg, bg);
      if (r < min) failures.add('$label ${r.toStringAsFixed(2)} < $min');
    }
    expect(failures, isEmpty);
  });

  test('every tone keeps its text AA on its soft fill', () {
    for (final tone in V2Tone.values) {
      final c = V2ToneColors.of(tone);
      expect(
        V2Contrast.ratio(c.text, c.soft),
        greaterThanOrEqualTo(4.5),
        reason: tone.name,
      );
    }
  });

  test('decorative rose is never good enough for text (guard rail)', () {
    expect(V2Contrast.ratio(V2Colors.rose, V2Colors.surface), lessThan(4.5));
    expect(
      V2Contrast.ratio(Colors.white, V2Colors.rose600),
      greaterThanOrEqualTo(4.5),
    );
  });

  // testWidgets (fake async) so google_fonts' runtime fetch never resolves
  // into an out-of-test HTTP failure.
  testWidgets('V2 theme maps tokens onto Material', (tester) async {
    final light = buildV2Theme();
    expect(light.colorScheme.primary, V2Colors.rose600);
    expect(light.scaffoldBackgroundColor, V2Colors.bg);
    expect(light.textTheme.bodyMedium!.fontSize, 15);
    expect(light.textTheme.bodySmall!.fontSize, 13);
    final dark = buildV2Theme(dark: true);
    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, V2DarkColors.bg);
    expect(identical(buildV2Theme(), light), isTrue);
  });

  test('keepAll joins syllables so lines break only at spaces', () {
    expect(V2Text.keepAll('알려 드려요'), '알\u2060려 드\u2060려\u2060요');
    expect(V2Text.keepAll('').isEmpty, isTrue);
  });
}
