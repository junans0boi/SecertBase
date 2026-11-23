import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/app_locale.dart';

void main() {
  testWidgets('date and time pickers are Korean by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kAppLocale,
        supportedLocales: kAppSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        home: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 11, 24),
                  firstDate: DateTime(2026),
                  lastDate: DateTime(2027),
                ),
                child: const Text('date'),
              ),
              TextButton(
                onPressed: () => showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 15, minute: 20),
                ),
                child: const Text('time'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('date'));
    await tester.pumpAndSettle();
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('time'));
    await tester.pumpAndSettle();
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });
}
