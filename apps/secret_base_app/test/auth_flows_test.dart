import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/auth_service.dart';
import 'package:secret_base_app/screens/auth/auth_parts.dart';
import 'package:secret_base_app/screens/auth/connecting_screen.dart';
import 'package:secret_base_app/screens/auth/google_signup_screen.dart';
import 'package:secret_base_app/screens/auth/login_screen.dart';
import 'package:secret_base_app/screens/auth/pairing_celebrate_screen.dart';
import 'package:secret_base_app/screens/auth/partner_screen.dart';
import 'package:secret_base_app/screens/auth/password_reset_screen.dart';
import 'package:secret_base_app/screens/auth/register_screen.dart';
import 'package:secret_base_app/screens/auth/withdraw_screen.dart';
import 'package:secret_base_app/screens/onboarding/onboarding_screen.dart';
import 'package:secret_base_app/v2/v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// path -> (status, body). Anything else answers 404.
final _routes = <String, (int, Object)>{};
final _requests = <http.Request>[];

const _user = {
  'UserId': 1,
  'UserCode': 'K7M2QX',
  'Nickname': '민지',
  'Email': 'minji@example.test',
  'AuthProvider': 'password',
};

void main() {
  setUpAll(() {
    http.runWithClient(
      () => AuthService().apiClient,
      () => MockClient((request) async {
        _requests.add(request);
        final hit = _routes[request.url.path];
        if (hit == null) return http.Response('{"ok":false}', 404);
        return http.Response(
          jsonEncode(hit.$2),
          hit.$1,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _requests.clear();
    _routes
      ..clear()
      ..['/api/auth/login'] = (200, {'token': 't', 'user': _user})
      ..['/api/user/profile/1'] = (200, {'user': _user})
      ..['/api/pairing/requests'] = (200, {'sent': [], 'received': []});
    await AuthService().logout();
  });

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  group('onboarding', () {
    testWidgets('three cards, skip works, and it is remembered', (
      tester,
    ) async {
      bigView(tester);
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onDone: () => done++)),
      );
      expect(find.textContaining('우리의 하루를'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.textContaining('같은 날, 같은 순간을'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('시작하기'), findsOneWidget);
      expect(find.text('건너뛰기'), findsOneWidget); // hidden, not removed
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(await hasSeenOnboarding(), isTrue);
    });

    testWidgets('skip on the first card', (tester) async {
      bigView(tester);
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onDone: () => done++)),
      );
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(done, 1);
    });
  });

  group('login', () {
    testWidgets(
      'terms links are always visible; wrong password shows a message',
      (tester) async {
        bigView(tester);
        _routes['/api/auth/login'] = (
          401,
          {'ok': false, 'reason': 'invalid_credentials'},
        );
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        expect(find.text('이용약관'), findsOneWidget);
        expect(find.text('개인정보처리방침'), findsOneWidget);
        expect(find.text('이메일로 가입하기'), findsOneWidget);

        await tester.tap(find.text('이메일로 로그인'));
        await tester.pumpAndSettle();
        expect(find.text('비밀번호를 잊으셨나요?'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField).at(0),
          'minji@example.test',
        );
        await tester.enterText(find.byType(TextField).at(1), 'wrongpass1');
        await tester.tap(find.widgetWithText(TextButton, '로그인'));
        await tester.pumpAndSettle();
        expect(find.text('이메일이나 비밀번호가 맞지 않아요. 다시 확인해 주세요.'), findsOneWidget);
        // password is sent as typed (no trimming)
        final login = _requests.firstWhere(
          (r) => r.url.path == '/api/auth/login',
        );
        expect(jsonDecode(login.body)['password'], 'wrongpass1');
      },
    );

    testWidgets('empty fields explain what is missing before any request', (
      tester,
    ) async {
      bigView(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.tap(find.text('이메일로 로그인'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
      expect(_requests, isEmpty);
    });
  });

  group('register', () {
    Future<void> toStepTwo(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.enterText(find.byType(TextField).at(0), '김민지');
      await tester.enterText(find.byType(TextField).at(1), '민지');
      await tester.tap(find.byType(TextField).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }

    testWidgets('step one validates the profile fields', (tester) async {
      bigView(tester);
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('이름을 입력해 주세요.'), findsOneWidget);
      expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
      expect(find.text('생일을 선택해 주세요.'), findsOneWidget);
    });

    testWidgets('submit needs a strong password and the required consents', (
      tester,
    ) async {
      bigView(tester);
      await toStepTwo(tester);
      TextButton submit() =>
          tester.widget(find.widgetWithText(TextButton, '가입하기'));
      expect(submit().onPressed, isNull);

      await tester.enterText(
        find.byType(TextField).at(0),
        'minji@example.test',
      );
      await tester.enterText(find.byType(TextField).at(1), 'abcdefgh');
      await tester.pump();
      expect(find.text('8자 이상'), findsOneWidget);
      expect(find.text('영문과 숫자 포함'), findsOneWidget);
      await tester.tap(find.text('전체 동의'));
      await tester.pump();
      expect(submit().onPressed, isNull); // consents ok, password still weak
      await tester.enterText(find.byType(TextField).at(1), 'abcdefg1');
      await tester.pump();
      expect(submit().onPressed, isNotNull);
      expect(_requests, isEmpty);
    });

    testWidgets('registers with itemised consents, then signs in', (
      tester,
    ) async {
      bigView(tester);
      _routes['/api/auth/register'] = (200, {'ok': true});
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('홈')),
          routes: {'/r': (_) => const RegisterScreen()},
          initialRoute: '/r',
        ),
      );
      // Navigator root is '/r' so popUntil(first) keeps it; just check requests.
      await tester.enterText(find.byType(TextField).at(0), '김민지');
      await tester.enterText(find.byType(TextField).at(1), '민지');
      await tester.tap(find.byType(TextField).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'minji@example.test',
      );
      await tester.enterText(find.byType(TextField).at(1), 'abcdefg1');
      for (final t in ['만 14세 이상이에요', '이용약관에 동의해요', '개인정보 수집·이용에 동의해요']) {
        await tester.tap(find.text('(필수) $t'));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(TextButton, '가입하기'));
      await tester.pumpAndSettle();
      final reg = _requests.firstWhere(
        (r) => r.url.path == '/api/auth/register',
      );
      final body = jsonDecode(reg.body) as Map;
      expect(body['consents'], {
        'age14': true,
        'terms': true,
        'privacy': true,
        'marketing': false,
      });
      expect(body['password'], 'abcdefg1');
      expect(_requests.any((r) => r.url.path == '/api/auth/login'), isTrue);
      expect(AuthService().token, 't');
    });

    testWidgets('an email that already exists offers login and reset', (
      tester,
    ) async {
      bigView(tester);
      _routes['/api/auth/register'] = (
        400,
        {'ok': false, 'reason': 'email_already_exists'},
      );
      await toStepTwo(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'minji@example.test',
      );
      await tester.enterText(find.byType(TextField).at(1), 'abcdefg1');
      await tester.tap(find.text('전체 동의'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '가입하기'));
      await tester.pumpAndSettle();
      expect(find.text('이미 가입된 이메일이에요.'), findsOneWidget);
      expect(find.text('비밀번호 재설정'), findsOneWidget);
      expect(AuthService().token, isNull);
    });
  });

  group('password reset', () {
    testWidgets('email -> code -> new password -> done', (tester) async {
      bigView(tester);
      _routes['/api/auth/password-reset/request'] = (200, {'ok': true});
      _routes['/api/auth/password-reset/verify'] = (200, {'ok': true});
      _routes['/api/auth/password-reset/confirm'] = (200, {'ok': true});
      await tester.pumpWidget(
        const MaterialApp(
          home: PasswordResetScreen(initialEmail: 'minji@example.test'),
        ),
      );
      await tester.tap(find.text('재설정 메일 보내기'));
      await tester.pumpAndSettle();
      expect(find.text('메일을 보냈어요'), findsOneWidget);
      expect(find.textContaining('메일 다시 보내기 (60초 후)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.widgetWithText(TextButton, '다음'));
      await tester.pumpAndSettle();
      expect(find.text('새 비밀번호를 만들어요'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'newpass123');
      await tester.tap(find.text('비밀번호 바꾸기'));
      await tester.pumpAndSettle();
      expect(find.text('비밀번호를 바꿨어요'), findsOneWidget);
      final confirm = _requests.last;
      expect(jsonDecode(confirm.body), {
        'email': 'minji@example.test',
        'code': '123456',
        'password': 'newpass123',
      });
      await teardown(tester); // cancels the resend timer
    });

    testWidgets('mail not configured shows a friendly retry banner', (
      tester,
    ) async {
      bigView(tester);
      _routes['/api/auth/password-reset/request'] = (
        503,
        {'ok': false, 'reason': 'mail_unavailable'},
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: PasswordResetScreen(initialEmail: 'minji@example.test'),
        ),
      );
      await tester.tap(find.text('재설정 메일 보내기'));
      await tester.pumpAndSettle();
      expect(find.text('지금은 메일을 보낼 수 없어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.textContaining('mail_unavailable'), findsNothing);
    });

    testWidgets('a wrong code explains itself and stays on the code step', (
      tester,
    ) async {
      bigView(tester);
      _routes['/api/auth/password-reset/request'] = (200, {'ok': true});
      _routes['/api/auth/password-reset/verify'] = (
        400,
        {'ok': false, 'reason': 'invalid_code'},
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: PasswordResetScreen(initialEmail: 'minji@example.test'),
        ),
      );
      await tester.tap(find.text('재설정 메일 보내기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.widgetWithText(TextButton, '다음'));
      await tester.pumpAndSettle();
      expect(find.textContaining('코드가 맞지 않아요'), findsOneWidget);
      await teardown(tester);
    });
  });

  group('partner connect', () {
    Future<void> pumpPartner(WidgetTester tester) async {
      bigView(tester);
      await AuthService().loginWithEmail('minji@example.test', 'abcdefg1');
      await tester.pumpWidget(const MaterialApp(home: PartnerScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('shows my code, invite text and personal archive entry', (
      tester,
    ) async {
      await pumpPartner(tester);
      expect(find.text('내 코드를 상대에게 보내 주세요'), findsOneWidget);
      expect(find.text('K7M2QX'), findsWidgets);
      expect(find.textContaining('민지님이 비밀기지에 초대했어요'), findsOneWidget);
      expect(find.text('개인 보관함'), findsOneWidget);
      expect(find.textContaining('user_code'), findsNothing);
      await teardown(tester);
    });

    testWidgets('unpaired users still reach logout, withdraw, support, terms', (
      tester,
    ) async {
      await pumpPartner(tester);
      await tester.tap(find.byTooltip('계정 메뉴'));
      await tester.pumpAndSettle();
      for (final label in ['고객센터', '이용약관', '개인정보처리방침', '로그아웃', '회원 탈퇴']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('연결 전'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('unknown code and connected code get different messages', (
      tester,
    ) async {
      await pumpPartner(tester);
      await tester.tap(find.text('상대에게 코드를 받았어요'));
      await tester.pumpAndSettle();
      expect(find.text('받은 코드를 입력해 주세요'), findsOneWidget);
      final send = find.widgetWithText(TextButton, '연결 요청 보내기');
      expect(tester.widget<TextButton>(send).onPressed, isNull);

      _routes['/api/pairing/requests'] = (
        404,
        {'ok': false, 'reason': 'recipient_not_found'},
      );
      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('없는 코드예요. 상대의 코드를 다시 확인해 주세요.'), findsOneWidget);
      final post = _requests.lastWhere((r) => r.method == 'POST');
      expect(jsonDecode(post.body), {'recipientCode': 'ABC123'});

      _routes['/api/pairing/requests'] = (
        409,
        {'ok': false, 'reason': 'active_couple_exists'},
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('이미 연결된 코드예요'), findsOneWidget);
      await tester.tap(find.text('코드 다시 입력하기'));
      await tester.pumpAndSettle();
      await teardown(tester);
    });

    testWidgets('a sent request shows the waiting card with cancel', (
      tester,
    ) async {
      _routes['/api/pairing/requests'] = (
        200,
        {
          'sent': [
            {'id': 7, 'status': 'pending', 'recipientNickname': '서윤'},
          ],
          'received': [],
        },
      );
      await pumpPartner(tester);
      expect(find.textContaining('서윤님의 수락을'), findsOneWidget);
      expect(find.text('요청 취소'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('a received request can be accepted or declined', (
      tester,
    ) async {
      _routes['/api/pairing/requests'] = (
        200,
        {
          'sent': [],
          'received': [
            {'id': 9, 'status': 'pending', 'senderNickname': '서윤'},
          ],
        },
      );
      await pumpPartner(tester);
      expect(find.text('서윤님이 연결을 요청했어요'), findsOneWidget);
      expect(find.text('수락하기'), findsOneWidget);
      expect(find.text('거절'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('failed request list shows a retry banner, not a crash', (
      tester,
    ) async {
      _routes['/api/pairing/requests'] = (500, {'ok': false});
      await pumpPartner(tester);
      expect(find.textContaining('연결 요청을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 불러오기'), findsOneWidget);
      await teardown(tester);
    });
  });

  group('withdraw', () {
    testWidgets('cancelling is the big button; confirm needs the phrase', (
      tester,
    ) async {
      bigView(tester);
      await AuthService().loginWithEmail('minji@example.test', 'abcdefg1');
      await tester.pumpWidget(const MaterialApp(home: WithdrawScreen()));
      expect(find.text('그대로 남을게요'), findsOneWidget);
      await tester.tap(find.text('탈퇴 계속하기'));
      await tester.pumpAndSettle();
      final withdraw = find.widgetWithText(TextButton, '탈퇴하기');
      expect(tester.widget<TextButton>(withdraw).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(0), 'abcdefg1');
      await tester.enterText(find.byType(TextField).at(1), kWithdrawPhrase);
      await tester.pump();
      expect(tester.widget<TextButton>(withdraw).onPressed, isNotNull);
      _routes['/api/user'] = (200, {'ok': true});
      await tester.tap(withdraw);
      await tester.pumpAndSettle();
      expect(find.text('탈퇴가 끝났어요'), findsOneWidget);
      expect(AuthService().token, isNull);
    });
  });

  group('connecting', () {
    testWidgets('loading, failed and offline are different screens', (
      tester,
    ) async {
      bigView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectingScreen(
            failed: false,
            onRetry: () {},
            onLogout: () {},
            probe: () async => true,
          ),
        ),
      );
      expect(find.text('비밀기지에 들어가는 중이에요'), findsOneWidget);
      expect(find.textContaining('v1.0'), findsNothing);

      var retried = 0;
      var loggedOut = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectingScreen(
            failed: true,
            onRetry: () => retried++,
            onLogout: () => loggedOut++,
            probe: () async => true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('연결하지 못했어요'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.tap(find.text('로그아웃'));
      expect((retried, loggedOut), (1, 1));

      await tester.pumpWidget(
        MaterialApp(
          home: ConnectingScreen(
            key: UniqueKey(),
            failed: true,
            onRetry: () {},
            onLogout: () {},
            probe: () async => false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('인터넷에 연결되어 있지 않아요'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
      await teardown(tester);
    });
  });

  group('consent checks', () {
    testWidgets('all-agree toggles every item; marketing is optional', (
      tester,
    ) async {
      bigView(tester);
      var v = const ConsentValue();
      await tester.pumpWidget(
        MaterialApp(
          home: V2Theme(
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, set) =>
                    ConsentChecks(value: v, onChanged: (n) => set(() => v = n)),
              ),
            ),
          ),
        ),
      );
      for (final t in ['만 14세 이상이에요', '이용약관에 동의해요', '개인정보 수집·이용에 동의해요']) {
        await tester.tap(find.text('(필수) $t'));
        await tester.pump();
      }
      expect(v.requiredOk, isTrue);
      expect(v.marketing, isFalse);
      await tester.tap(find.text('전체 동의'));
      await tester.pump();
      expect(v.all, isTrue);
      await tester.tap(find.text('전체 동의'));
      await tester.pump();
      expect(v.requiredOk, isFalse);
    });
  });

  group('google signup and celebration', () {
    testWidgets('Google first sign-in must add birthday and consents', (
      tester,
    ) async {
      bigView(tester);
      final gUser = {
        ..._user,
        'SignupRequired': true,
        'AuthProvider': 'google',
      };
      _routes['/api/auth/login'] = (200, {'token': 't', 'user': gUser});
      _routes['/api/user/profile/1'] = (200, {'user': gUser});
      _routes['/api/auth/complete-signup'] = (200, {'ok': true});
      await AuthService().loginWithEmail('x@example.test', 'abcdefg1');
      expect(AuthService().signupRequired, isTrue);
      await tester.pumpWidget(const MaterialApp(home: GoogleSignupScreen()));
      expect(find.text('Google 계정으로 가입 중이에요'), findsOneWidget);
      expect(find.text('minji@example.test'), findsOneWidget);
      TextButton start() =>
          tester.widget(find.widgetWithText(TextButton, '시작하기'));
      expect(start().onPressed, isNull);
      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 동의'));
      await tester.pump();
      expect(start().onPressed, isNotNull);
      await tester.tap(find.widgetWithText(TextButton, '시작하기'));
      await tester.pumpAndSettle();
      final req = _requests.firstWhere(
        (r) => r.url.path == '/api/auth/complete-signup',
      );
      final body = jsonDecode(req.body) as Map;
      expect(body['nickname'], '민지');
      expect(body['consents']['marketing'], isTrue);
      expect(body['birth_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    testWidgets('celebration shows the checklist and the notification sheet', (
      tester,
    ) async {
      bigView(tester);
      final paired = {..._user, 'PartnerCode': 'ZZZ999', 'PartnerName': '서윤'};
      _routes['/api/auth/login'] = (200, {'token': 't', 'user': paired});
      _routes['/api/user/profile/1'] = (200, {'user': paired});
      await AuthService().loginWithEmail('minji@example.test', 'abcdefg1');
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(home: PairingCelebrateScreen(onDone: () => done++)),
      );
      await tester.pump();
      expect(find.text('연결됐어요!'), findsOneWidget);
      expect(find.text('서윤님과 연결하기'), findsOneWidget);
      expect(find.text('처음 만난 날 정하기'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        find.text('나중에'),
        findsOneWidget,
      ); // pre-prompt sheet, before the OS
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('홈으로 가기'));
      expect(done, 1);
    });
  });

  // keep the Clipboard import used (paste chip lives in PartnerScreen).
  test('clipboard channel exists', () {
    expect(Clipboard.kTextPlain, 'text/plain');
  });
}
