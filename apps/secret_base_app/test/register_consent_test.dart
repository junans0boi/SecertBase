import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/auth_service.dart';
import 'package:secret_base_app/screens/auth/register_screen.dart';
import 'package:secret_base_app/screens/settings/settings_screen.dart';

void main() {
  final requests = <http.Request>[];
  final launched = <String>[];
  setUpAll(() {
    http.runWithClient(
      () => AuthService().apiClient,
      () => MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );
  });
  setUp(() {
    requests.clear();
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
              return true;
            }
            return true;
          },
        );
  });

  Future<void> accountStep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('로그인 화면')),
        initialRoute: '/register',
        routes: {'/register': (_) => const RegisterScreen()},
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '홍길동');
    await tester.enterText(find.byType(TextField).at(1), '길동');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(InkWell, Icons.calendar_today_outlined),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'consent@example.test',
    );
    await tester.enterText(find.byType(TextField).at(1), 'example-password');
  }

  testWidgets('keyboard done cannot register without consent', (tester) async {
    await accountStep(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('개인정보 처리방침과 이용약관에 동의해주세요.'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
  });

  for (final keyboard in [false, true]) {
    testWidgets(
      'consented ${keyboard ? 'keyboard' : 'button'} registers once',
      (tester) async {
        await accountStep(tester);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        if (keyboard) {
          await tester.tap(find.byType(TextField).at(1));
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          await tester.tap(find.text('회원가입'));
        }
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/api/auth/register');
        expect(requests.single.body, contains('consent@example.test'));
        expect(find.text('로그인 화면'), findsOneWidget);
      },
    );
  }

  testWidgets('revoking consent also blocks keyboard done', (tester) async {
    await accountStep(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(TextField).at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
  });

  testWidgets('consent links open canonical legal pages', (tester) async {
    await accountStep(tester);
    await tester.tap(find.text('개인정보 처리방침'));
    await tester.pump();
    await tester.tap(find.text('이용약관'));
    await tester.pump();
    expect(launched, [
      'https://secretbase.cloud/privacy',
      'https://secretbase.cloud/terms',
    ]);
  });

  testWidgets('my space opens all three canonical legal links', (tester) async {
    tester.view.physicalSize = const Size(1200, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MySpaceScreen())),
    );
    await tester.pump();
    for (final label in ['개인정보 처리방침', '이용약관', '계정 삭제 안내']) {
      expect(find.text(label), findsOneWidget);
      await tester.scrollUntilVisible(find.text(label), 400);
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(launched, [
      'https://secretbase.cloud/privacy',
      'https://secretbase.cloud/terms',
      'https://secretbase.cloud/delete-account',
    ]);
  });

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
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(InkWell, Icons.calendar_today_outlined),
    );
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
