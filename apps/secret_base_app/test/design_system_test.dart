import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/app_theme.dart';
import 'package:secret_base_app/core/main_design.dart';

void main() {
  testWidgets('shared theme keeps navigation, input, and button states aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Column(
            children: [TextField(), FilledButton(onPressed: null, child: Text('확인'))],
          ),
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    final focusedBorder =
        theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
    final selectedLabel = theme.navigationBarTheme.labelTextStyle!.resolve({
      WidgetState.selected,
    });

    expect(theme.scaffoldBackgroundColor, kMainBg);
    expect(theme.colorScheme.primary, kMainRose);
    expect(focusedBorder.borderSide.color, kMainRose);
    expect(theme.navigationBarTheme.indicatorColor, kMainPaperSoft);
    expect(selectedLabel!.color, kMainInk);
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({}),
      const Size(44, 44),
    );
  });

  testWidgets('common design primitives render together on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: CozyPage(
          padding: EdgeInsets.all(16),
          child: MainCard(
            child: IconBadge(
              color: kMainRose,
              backgroundColor: kMainRoseSoft,
              child: Icon(Icons.favorite),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CozyPage), findsOneWidget);
    expect(find.byType(MainCard), findsOneWidget);
    expect(find.byType(IconBadge), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
