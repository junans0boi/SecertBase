import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/auth_service.dart';
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
}
