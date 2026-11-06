import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:secret_base_app/core/app_info.dart';
import 'package:secret_base_app/core/support_contact.dart';
import 'package:secret_base_app/screens/settings/account_screen.dart';
import 'package:secret_base_app/screens/settings/app_info_screens.dart';
import 'package:secret_base_app/screens/settings/couple_info_screen.dart';
import 'package:secret_base_app/screens/settings/delete_account_screen.dart';
import 'package:secret_base_app/screens/settings/permission_probe.dart';
import 'package:secret_base_app/screens/settings/permissions_screen.dart';
import 'package:secret_base_app/screens/settings/profile_edit_screen.dart';
import 'package:secret_base_app/screens/settings/settings_screen.dart';
import 'package:secret_base_app/screens/settings/support_sheet.dart';

import 'more_test_support.dart';

class _FakeProbe extends PermissionProbe {
  _FakeProbe({this.notificationState = OsPermission.granted});
  final OsPermission notificationState;
  int opened = 0;

  @override
  Future<OsPermission> notification() async => notificationState;
  @override
  Future<OsPermission> location() async => OsPermission.granted;
  @override
  bool get canOpenSettings => true;
  @override
  Future<bool> openSettings() async {
    opened++;
    return true;
  }
}

void _mockPackage({String version = '2.0.0', String build = '2'}) {
  PackageInfo.setMockInitialValues(
    appName: 'Secret Base',
    packageName: 'app.secretbase',
    version: version,
    buildNumber: build,
    buildSignature: '',
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(setUpMoreServer);

  group('더보기 허브', () {
    testWidgets('connected: four zones, no tab shortcuts or debug info', (
      tester,
    ) async {
      _mockPackage();
      await signInForMore(tester, pairedUser());
      await _pump(tester, SettingsScreen(permissionProbe: _FakeProbe()));

      expect(find.text('민지 · 서윤'), findsOneWidget);
      expect(find.text('D+412'), findsOneWidget);
      for (final label in [
        '우리 이야기',
        '기념일',
        '비밀기지',
        '우리 이해',
        '상점',
        '앱 설정',
        '알림',
        '개인정보·권한',
        '도움말·정보',
        '고객센터·FAQ',
        '앱 정보·약관',
        '계정',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('500일까지 88일'), findsOneWidget);
      expect(find.text('52,300'), findsOneWidget);
      expect(find.text('2.0.0'), findsOneWidget);
      expect(find.text('개인 보관함'), findsNothing);
      for (final gone in ['MomentLoop', '비밀 지도', '함께 놀기', 'Ping', '방 코드']) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('비밀기지 개발팀'), findsNothing);
    });

    testWidgets('unpaired: pair button and 개인 보관함 are offered', (tester) async {
      await signInForMore(tester, unpairedUser());
      await _pump(tester, SettingsScreen(permissionProbe: _FakeProbe()));

      expect(find.text('아직 연결 전이에요'), findsOneWidget);
      expect(find.text('파트너 연결하기'), findsOneWidget);
      expect(find.text('개인 보관함'), findsOneWidget);
      expect(find.text('연결하면 열려요'), findsNWidgets(2));
      // 연결 전에도 계정·고객센터·약관은 열려요.
      expect(find.text('계정'), findsOneWidget);
      expect(find.text('고객센터·FAQ'), findsOneWidget);
    });

    testWidgets('push off: banner points to notification settings', (
      tester,
    ) async {
      await signInForMore(tester, pairedUser());
      await _pump(
        tester,
        SettingsScreen(
          permissionProbe: _FakeProbe(notificationState: OsPermission.denied),
        ),
      );
      expect(find.text('알림이 꺼져 있어요'), findsOneWidget);
      expect(find.text('서윤의 새 기록을 바로 받지 못해요'), findsOneWidget);
      expect(find.text('꺼짐 · 휴대폰 설정에서 켤 수 있어요'), findsOneWidget);
    });

    testWidgets('계정 row opens the account page', (tester) async {
      await signInForMore(tester, pairedUser());
      await _pump(tester, SettingsScreen(permissionProbe: _FakeProbe()));
      await tester.tap(find.text('계정'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.text('위험 구역'), findsOneWidget);
    });
  });

  group('고객센터', () {
    testWidgets('copies the email, filters FAQ, falls back without mail app', (
      tester,
    ) async {
      final copied = captureClipboard(tester);
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showSupportSheet(context, opener: (_) async => false),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(find.text(kSupportEmail), findsOneWidget);
      await tester.tap(find.text('코인'));
      await tester.pump();
      expect(find.text('코인은 어떻게 얻나요?'), findsOneWidget);
      expect(find.text('알림이 오지 않아요'), findsNothing);

      await tester.tap(find.text('복사'));
      await tester.pump();
      expect(copied(), kSupportEmail);
      expect(find.text('이메일 주소를 복사했어요.'), findsOneWidget);

      await tester.tap(find.text('메일 앱 열기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('메일 앱을 열 수 없어요'), findsOneWidget);
    });
  });

  group('앱 정보', () {
    testWidgets('developer info, homepage button, hidden diagnostics', (
      tester,
    ) async {
      final opened = <Uri>[];
      await signInForMore(tester, pairedUser());
      await _pump(
        tester,
        AppInfoScreen(
          info: const AppInfo(version: '2.0.0', buildNumber: '2'),
          onOpenLink: (u) async {
            opened.add(u);
            return true;
          },
        ),
      );
      expect(find.text('이준환 (LeeJunHwan)'), findsOneWidget);
      expect(find.text('SteadyToVivid'), findsOneWidget);
      expect(find.text('junans0boi@naver.com'), findsOneWidget);
      expect(find.text('운영자'), findsNothing);
      expect(find.textContaining('비밀기지 개발팀'), findsNothing);
      expect(find.textContaining('2026 SteadyToVivid'), findsOneWidget);

      await tester.tap(find.text('팀 홈페이지'));
      await tester.pump();
      await tester.tap(find.text('이용약관'));
      await tester.pump();
      await tester.tap(find.text('개인정보 처리방침'));
      await tester.pump();
      await tester.tap(find.text('계정 삭제 안내'));
      await tester.pump();
      expect(opened.map((u) => u.toString()), [
        'https://steady2vivid.kro.kr/',
        'https://secretbase.cloud/terms',
        'https://secretbase.cloud/privacy',
        'https://secretbase.cloud/delete-account',
      ]);

      expect(find.byType(DiagnosticsScreen), findsNothing);
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('2.0.0 (빌드 2)'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
    });

    testWidgets('changelog marks the installed version', (tester) async {
      await _pump(tester, const ChangelogScreen(currentVersion: '2.0.0'));
      expect(find.text('현재 버전'), findsOneWidget);
    });
  });

  group('개인정보·권한', () {
    testWidgets('denied permission offers 설정 열기', (tester) async {
      final probe = _FakeProbe(notificationState: OsPermission.denied);
      await _pump(tester, PermissionsScreen(probe: probe));
      expect(find.text('허용됨'), findsOneWidget);
      expect(find.text('꺼짐'), findsOneWidget);
      await tester.tap(find.text('휴대폰 설정에서 켜기'));
      await tester.pump();
      expect(probe.opened, 1);
    });
  });

  group('프로필·커플', () {
    testWidgets('profile edit saves the nickname', (tester) async {
      await signInForMore(tester, unpairedUser());
      await _pump(tester, const ProfileEditScreen());
      expect(find.text('저장하기'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '미니');
      await tester.pump();
      await tester.tap(find.text('저장하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(moreRequests, contains('PATCH /api/user/profile/1'));
      expect(moreBodies['PATCH /api/user/profile/1'], contains('미니'));
    });

    testWidgets('unlink needs a confirm and the typed phrase', (tester) async {
      await signInForMore(tester, pairedUser());
      await _pump(tester, const CoupleInfoScreen());
      expect(find.text('D+412'), findsOneWidget);
      expect(find.text('2025년 9월 21일부터 함께해요'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('서윤과 연결 해제'), 200);
      await tester.tap(find.text('서윤과 연결 해제'));
      await tester.pumpAndSettle();
      expect(find.text('서윤과의 연결을 해제할까요?'), findsOneWidget);
      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();

      expect(find.text('마지막으로 확인할게요'), findsOneWidget);
      final confirm = find.widgetWithText(TextButton, '연결 해제하기');
      expect(tester.widget<TextButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, '연결 해제');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(moreRequests, contains('DELETE /api/user/partner'));
    });
  });

  group('로그아웃·탈퇴', () {
    testWidgets('delete flow: 그만두기 is primary, phrase gates the end', (
      tester,
    ) async {
      await signInForMore(tester, pairedUser());
      await _pump(tester, DeleteAccountScreen(apiClient: plainMoreClient()));

      expect(find.text('정말 떠나시나요?'), findsOneWidget);
      expect(find.text('52,300'), findsNothing);
      final next = find.widgetWithText(TextButton, '계속 탈퇴하기');
      expect(tester.widget<TextButton>(next).onPressed, isNull);
      await tester.tap(find.text('되돌릴 수 없다는 걸 확인했어요'));
      await tester.pump();
      expect(tester.widget<TextButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      await tester.pump();

      expect(find.text('떠나는 이유를 알려 주실래요?'), findsOneWidget);
      await tester.tap(find.text('다음 단계로'));
      await tester.pump();

      expect(find.text('마지막 확인이에요'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      final delete = find.widgetWithText(TextButton, '탈퇴하기');
      expect(tester.widget<TextButton>(delete).onPressed, isNull);
    });

    testWidgets('wrong password is reported on the field', (tester) async {
      await signInForMore(tester, pairedUser());
      moreOverrides['DELETE /api/user'] = (
        401,
        {'ok': false, 'reason': 'invalid_password'},
      );
      await _pump(tester, DeleteAccountScreen(apiClient: plainMoreClient()));
      await tester.tap(find.text('되돌릴 수 없다는 걸 확인했어요'));
      await tester.pump();
      await tester.tap(find.text('계속 탈퇴하기'));
      await tester.pump();
      await tester.tap(find.text('다음 단계로'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), 'wrong-pass-1');
      await tester.enterText(find.byType(TextField).at(1), '탈퇴');
      await tester.pump();
      await tester.tap(find.text('탈퇴하기'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(moreRequests, contains('DELETE /api/user'));
      expect(find.text('비밀번호가 맞지 않아요.'), findsOneWidget);
    });

    testWidgets('Google accounts are not asked for a password', (tester) async {
      await signInForMore(tester, pairedUser(provider: 'google'));
      await _pump(tester, DeleteAccountScreen(apiClient: plainMoreClient()));
      await tester.tap(find.text('되돌릴 수 없다는 걸 확인했어요'));
      await tester.pump();
      await tester.tap(find.text('계속 탈퇴하기'));
      await tester.pump();
      await tester.tap(find.text('다음 단계로'));
      await tester.pump();
      expect(find.text('비밀번호'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
