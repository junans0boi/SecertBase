import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secret_base_app/core/support_contact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:secret_base_app/screens/home_shell.dart';
import 'package:secret_base_app/screens/relationship/relationship_understanding_screen.dart';
import 'package:secret_base_app/screens/secret_base/secret_base_screen.dart';
import 'package:secret_base_app/screens/settings/settings_screen.dart';

void main() {
  testWidgets('more details keep the shell navigation visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('내 공간'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 이모지'), findsOneWidget);
    expect(find.text('기념일 추가'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'more keeps every exposed row reachable through its existing route',
    (tester) async {
      final destinations = <int>[];
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(onNavigate: destinations.add)),
      );
      await tester.pump();

      for (final label in [
        '내 공간',
        'MomentLoop',
        '비밀 지도',
        '함께 놀기',
        '우리의 비밀기지',
        '관계 이해',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.bySemanticsLabel('MomentLoop: 우리의 순간을 기록하고 돌아봐요'),
        findsOneWidget,
      );

      tester.semantics.tap(
        find.semantics.byLabel('MomentLoop: 우리의 순간을 기록하고 돌아봐요'),
      );
      await tester.tap(find.text('비밀 지도'));
      await tester.tap(find.text('함께 놀기'));
      expect(destinations, [1, 2, 3]);

      await tester.tap(find.text('우리의 비밀기지'));
      await tester.pump();
      expect(find.byType(SecretBaseScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pump();

      await tester.ensureVisible(find.text('관계 이해'));
      await tester.pump();
      await tester.tap(find.text('관계 이해'));
      await tester.pump();
      expect(find.byType(RelationshipUnderstandingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'more semantic entries perform their existing navigation actions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeShell()));
      await tester.pump();
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();

      tester.semantics.tap(
        find.semantics.byLabel('MomentLoop: 우리의 순간을 기록하고 돌아봐요'),
      );
      await tester.pump();

      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('내 공간: 프로필, 연결, 기념일 관리'));
      await tester.pump();

      expect(find.text('프로필 이모지'), findsOneWidget);
    },
  );

  testWidgets('support entry shows email and copies it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('고객센터'));
    await tester.pumpAndSettle();
    expect(find.text(kSupportEmail), findsOneWidget);

    await tester.tap(find.text('복사'));
    await tester.pump();
    expect(copied, kSupportEmail);
    expect(find.text('이메일 주소를 복사했어요.'), findsOneWidget);
  });

  testWidgets('more shows app version and build at the bottom', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Secret Base',
      packageName: 'app.secretbase',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('버전 1.2.3 (빌드 45)'), findsOneWidget);
  });
}
