import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/features/base_invite/invite_confirm_screen.dart';
import 'package:secret_base_app/features/base_invite/invite_link.dart';
import 'package:secret_base_app/features/base_invite/pending_invite.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('parseInviteCode', () {
    test('accepts https app links and the custom scheme', () {
      expect(
        parseInviteCode(Uri.parse('https://secretbase.cloud/i/K7M2QX')),
        'K7M2QX',
      );
      expect(
        parseInviteCode(Uri.parse('https://secretbase.cloud/i/k7m2qx/')),
        'K7M2QX',
      );
      expect(
        parseInviteCode(Uri.parse('secretbase://invite/K7M2QX')),
        'K7M2QX',
      );
    });

    test('rejects anything else', () {
      for (final raw in [
        'https://evil.example/i/K7M2QX',
        'http://secretbase.cloud/i/K7M2QX',
        'https://secretbase.cloud/i/K7M2Q',
        'https://secretbase.cloud/i/K7M2QXX',
        'https://secretbase.cloud/x/K7M2QX',
        'https://secretbase.cloud/i/K7M2Q!',
        'secretbase://other/K7M2QX',
        'secretbase://invite/',
        'otherapp://invite/K7M2QX',
      ]) {
        expect(parseInviteCode(Uri.parse(raw)), isNull, reason: raw);
      }
    });
  });

  test('share text carries the https link and never claims a connection', () {
    final text = buildInviteShareText(nickname: '민지', code: 'K7M2QX');
    expect(text, contains('https://secretbase.cloud/i/K7M2QX'));
    expect(text, contains('민지'));
  });

  group('resolveInviteRoute', () {
    test('no pending code means no invite screen', () {
      expect(
        resolveInviteRoute(
          pendingCode: null,
          loggedIn: true,
          signupRequired: false,
          paired: false,
        ),
        InviteRoute.none,
      );
    });
    test('logged-out user keeps the code and goes through login first', () {
      expect(
        resolveInviteRoute(
          pendingCode: 'K7M2QX',
          loggedIn: false,
          signupRequired: false,
          paired: false,
        ),
        InviteRoute.none,
      );
      expect(
        resolveInviteRoute(
          pendingCode: 'K7M2QX',
          loggedIn: true,
          signupRequired: true,
          paired: false,
        ),
        InviteRoute.none,
      );
    });
    test('logged-in unpaired user sees the confirmation screen', () {
      expect(
        resolveInviteRoute(
          pendingCode: 'K7M2QX',
          loggedIn: true,
          signupRequired: false,
          paired: false,
        ),
        InviteRoute.confirm,
      );
    });
    test('already paired user drops the code', () {
      expect(
        resolveInviteRoute(
          pendingCode: 'K7M2QX',
          loggedIn: true,
          signupRequired: false,
          paired: true,
        ),
        InviteRoute.discard,
      );
    });
  });

  group('PendingInvite', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps the code across restarts until cleared', () async {
      final first = PendingInvite();
      await first.handleUri(Uri.parse('secretbase://invite/K7M2QX'));
      expect(first.code, 'K7M2QX');

      final second = PendingInvite();
      await second.load();
      expect(second.code, 'K7M2QX');

      await second.clear();
      final third = PendingInvite();
      await third.load();
      expect(third.code, isNull);
    });

    test('ignores unrelated links', () async {
      final p = PendingInvite();
      await p.handleUri(Uri.parse('https://example.com/i/K7M2QX'));
      expect(p.code, isNull);
    });

    test('listens to the link stream', () async {
      final p = PendingInvite();
      final events = Stream<Uri>.fromIterable([
        Uri.parse('https://secretbase.cloud/i/ABC234'),
      ]);
      await p.start(initial: null, stream: events);
      await Future<void>.delayed(Duration.zero);
      expect(p.code, 'ABC234');
    });
  });

  group('InviteConfirmScreen', () {
    Future<void> pump(
      WidgetTester tester, {
      required Future<String?> Function(String) onSend,
      VoidCallback? onDone,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: InviteConfirmScreen(
            code: 'K7M2QX',
            onSend: onSend,
            onDone: onDone ?? () {},
          ),
        ),
      );
    }

    testWidgets('does not send anything until the user confirms', (
      tester,
    ) async {
      var sent = 0;
      await pump(
        tester,
        onSend: (_) async {
          sent++;
          return null;
        },
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('이 분에게 연결 요청을 보낼까요?'), findsOneWidget);
      expect(sent, 0);

      await tester.tap(find.text('연결 요청 보내기'));
      await tester.pumpAndSettle();
      expect(sent, 1);
    });

    testWidgets('declining sends nothing and finishes', (tester) async {
      var sent = 0;
      var done = 0;
      await pump(
        tester,
        onSend: (_) async {
          sent++;
          return null;
        },
        onDone: () => done++,
      );
      await tester.tap(find.text('보내지 않을래요'));
      await tester.pumpAndSettle();
      expect(sent, 0);
      expect(done, 1);
    });

    testWidgets('shows a readable error and keeps the screen on failure', (
      tester,
    ) async {
      var done = 0;
      await pump(
        tester,
        onSend: (_) async => 'recipient_not_found',
        onDone: () => done++,
      );
      await tester.tap(find.text('연결 요청 보내기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('없는 코드'), findsOneWidget);
      expect(done, 0);
    });
  });
}
