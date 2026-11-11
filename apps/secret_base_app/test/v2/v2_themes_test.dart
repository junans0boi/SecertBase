import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secret_base_app/screens/settings/theme_screen.dart';
import 'package:secret_base_app/v2/v2.dart';

void main() {
  tearDown(() => V2ThemeController.instance.debugReset());

  group('every color theme keeps text readable (WCAG AA)', () {
    for (final p in [...V2Palettes.all, V2Palettes.care]) {
      test('${p.id.name}${identical(p, V2Palettes.care) ? ' (care)' : ''}', () {
        void aa(String label, Color fg, Color bg, [double min = 4.5]) {
          final r = V2Contrast.ratio(fg, bg);
          expect(
            r,
            greaterThanOrEqualTo(min),
            reason: '$label ${r.toStringAsFixed(2)}:1',
          );
        }

        for (final (n, bg) in [
          ('bg', p.bg),
          ('surface', p.surface),
          ('soft', p.soft),
        ]) {
          aa('ink/$n', p.ink, bg);
          aa('sub/$n', p.sub, bg);
          aa('muted/$n', p.muted, bg);
        }
        aa('ink/soft2', p.ink, p.soft2);
        aa('onPrimary/primary', p.onPrimary, p.primary);
        aa('onPrimarySoft/primarySoft', p.onPrimarySoft, p.primarySoft);
        aa('errText/errSoft', p.errText, p.errSoft);
        aa('white/snack', Colors.white, p.snack);
        aa('snackAction/snack', p.snackAction, p.snack);
        aa('white/me', Colors.white, p.me);
        aa('white/partner', Colors.white, p.partner);
        for (final c in p.heroStrong.colors) {
          aa('onHeroStrong/hero', p.onHeroStrong, c);
        }
        for (final c in p.heroWash.colors) {
          aa('ink/heroWash', p.ink, c);
        }
        for (final t in V2Tone.values) {
          final tc = p.tone(t);
          aa('${t.name} text/soft', tc.text, tc.soft);
        }
        aa('control/surface', p.control, p.surface, 3);
      });
    }
  });

  testWidgets('V2Colors and V2Text follow the selected theme', (_) async {
    SharedPreferences.setMockInitialValues({});
    final c = V2ThemeController.instance;
    await c.select(V2ThemeId.night);
    expect(V2Colors.bg, V2Palettes.night.bg);
    expect(V2Colors.rose600, V2Palettes.night.primary);
    expect(V2Text.cap.color, V2Palettes.night.sub);
    expect(V2Gradients.hero, V2Palettes.night.heroStrong);
    await c.select(V2ThemeId.blossom);
    expect(V2Colors.bg, V2Palettes.blossom.bg);
    expect(V2Text.cap.color, V2Palettes.blossom.sub);
  });

  test('the choice is saved and restored on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final c = V2ThemeController.instance;
    await c.select(V2ThemeId.sage);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(V2ThemeController.prefsKey), 'sage');

    c.debugReset();
    expect(c.value, V2ThemeId.blossom);
    await c.load();
    expect(c.value, V2ThemeId.sage);
    expect(V2Palette.current, V2Palettes.sage);
  });

  test('an unknown saved value falls back to 코랄', () async {
    SharedPreferences.setMockInitialValues({
      V2ThemeController.prefsKey: 'neon',
    });
    await V2ThemeController.instance.load();
    expect(V2ThemeController.instance.value, V2ThemeId.blossom);
  });

  testWidgets('화면 테마 lists every theme and switches on tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = V2ThemeController.instance;
    await tester.pumpWidget(
      ValueListenableBuilder<V2ThemeId>(
        valueListenable: c,
        builder: (_, _, _) => MaterialApp(
          theme: buildV2Theme(palette: c.palette),
          home: const ThemeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('화면 테마'), findsOneWidget);
    expect(find.text('코랄'), findsOneWidget);
    expect(find.text('블루'), findsOneWidget);

    await tester.tap(find.text('블루'));
    await tester.pumpAndSettle();
    expect(c.value, V2ThemeId.clean);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
      V2Palettes.clean.primary,
    );

    await tester.dragUntilVisible(
      find.text('버터'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('버터'));
    await tester.pumpAndSettle();
    expect(c.value, V2ThemeId.butter);
  });

  test('dark subtrees use the care palette unless the theme is dark', () {
    expect(
      buildV2Theme(
        dark: true,
        palette: V2Palettes.paper,
      ).extension<V2Palette>(),
      V2Palettes.care,
    );
    expect(
      buildV2Theme(
        dark: true,
        palette: V2Palettes.night,
      ).extension<V2Palette>(),
      V2Palettes.night,
    );
  });
}
