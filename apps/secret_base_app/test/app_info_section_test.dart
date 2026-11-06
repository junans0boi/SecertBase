import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:secret_base_app/core/app_changelog.dart';
import 'package:secret_base_app/core/app_info.dart';
import 'package:secret_base_app/screens/settings/app_info_screens.dart';
import 'package:secret_base_app/screens/settings/settings_screen.dart';

void _mockPackage({String version = '2.0.0', String build = '2'}) {
  PackageInfo.setMockInitialValues(
    appName: 'Secret Base',
    packageName: 'app.secretbase',
    version: version,
    buildNumber: build,
    buildSignature: '',
  );
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SettingsScreen())),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('앱 정보'), 200);
}

void main() {
  group('Settings > 앱 정보', () {
    testWidgets('shows the version and build read from PackageInfo', (
      tester,
    ) async {
      _mockPackage(version: '3.4.5', build: '67');
      await _openSettings(tester);

      expect(find.text('앱 정보'), findsOneWidget);
      expect(find.text('앱 버전'), findsOneWidget);
      expect(find.text('v3.4.5 (빌드 67)'), findsOneWidget);
      expect(find.text('업데이트 내역'), findsOneWidget);
      expect(find.text('개발자 정보'), findsOneWidget);
    });

    testWidgets('tapping the version row copies it for support', (
      tester,
    ) async {
      _mockPackage();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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
      await _openSettings(tester);

      await tester.tap(find.text('앱 버전'));
      await tester.pump();

      expect(copied, '비밀기지 v2.0.0 (빌드 2)');
      expect(find.text('버전 정보를 복사했어요.'), findsOneWidget);
    });

    testWidgets('업데이트 내역 row opens the changelog marking the current one', (
      tester,
    ) async {
      _mockPackage(version: kChangelog.first.version);
      await _openSettings(tester);

      await tester.tap(find.text('업데이트 내역'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangelogScreen), findsOneWidget);
      expect(find.text('v${kChangelog.first.version}'), findsOneWidget);
      expect(find.text(kChangelog.first.title), findsOneWidget);
      expect(find.text('현재 버전'), findsOneWidget);
    });

    testWidgets('개발자 정보 row opens the developer page', (tester) async {
      _mockPackage();
      await _openSettings(tester);

      await tester.tap(find.text('개발자 정보'));
      await tester.pumpAndSettle();

      expect(find.byType(DeveloperInfoScreen), findsOneWidget);
      expect(find.text('비밀기지 / Secret Base'), findsOneWidget);
      expect(find.text('v2.0.0 (빌드 2)'), findsOneWidget);
    });

    testWidgets('semantic taps navigate exactly like touch taps', (
      tester,
    ) async {
      _mockPackage();
      final handle = tester.ensureSemantics();
      await _openSettings(tester);

      tester.semantics.tap(find.semantics.byLabel('업데이트 내역: 새로 바뀐 점을 확인해요'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangelogScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      tester.semantics.tap(
        find.semantics.byLabel('개발자 정보: 만든 사람, 문의, 약관과 라이선스'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperInfoScreen), findsOneWidget);
      handle.dispose();
    });
  });

  group('DeveloperInfoScreen', () {
    Future<List<Uri>> pump(
      WidgetTester tester, {
      String supportEmail = '',
      String legalOperatorName = '',
      String websiteUrl = '',
    }) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DeveloperInfoScreen(
            info: const AppInfo(version: '2.0.0', buildNumber: '2'),
            onOpenLink: (uri) async => opened.add(uri),
            supportEmail: supportEmail,
            legalOperatorName: legalOperatorName,
            websiteUrl: websiteUrl,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('lists app, developer, team, legal links and copyright', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('비밀기지 / Secret Base'), findsOneWidget);
      expect(find.text(AppInfoConstants.developerName), findsOneWidget);
      expect(find.text(AppInfoConstants.teamName), findsOneWidget);
      expect(find.text('개인정보 처리방침'), findsOneWidget);
      expect(find.text('이용약관'), findsOneWidget);
      expect(find.text('회원 탈퇴 안내'), findsOneWidget);
      expect(find.text('오픈소스 라이선스'), findsOneWidget);
      expect(find.text(AppInfoConstants.copyrightLine), findsOneWidget);
      expect(AppInfoConstants.copyrightLine, contains('2026'));
    });

    testWidgets('hides rows whose value is empty instead of inventing one', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('문의'), findsNothing);
      expect(find.text('운영자'), findsNothing);
      expect(find.text('팀 홈페이지'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('shows contact, operator and website once they are filled', (
      tester,
    ) async {
      final opened = await pump(
        tester,
        supportEmail: 'help@example.test',
        legalOperatorName: 'Example Inc.',
        websiteUrl: 'https://example.test/',
      );

      expect(find.text('help@example.test'), findsOneWidget);
      expect(find.text('Example Inc.'), findsOneWidget);

      await tester.tap(find.text('문의'));
      await tester.tap(find.text('팀 홈페이지'));
      expect(opened, [
        Uri(scheme: 'mailto', path: 'help@example.test'),
        Uri.parse('https://example.test/'),
      ]);
    });

    testWidgets('legal rows open the privacy, terms and deletion pages', (
      tester,
    ) async {
      final opened = await pump(tester);

      await tester.tap(find.text('개인정보 처리방침'));
      await tester.tap(find.text('이용약관'));
      await tester.tap(find.text('회원 탈퇴 안내'));

      expect(opened, [
        Uri.parse(AppInfoConstants.privacyUrl),
        Uri.parse(AppInfoConstants.termsUrl),
        Uri.parse(AppInfoConstants.deleteAccountUrl),
      ]);
    });

    testWidgets('오픈소스 라이선스 opens Flutter license page', (tester) async {
      await pump(tester);

      await tester.tap(find.text('오픈소스 라이선스'));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
