import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/auth/auth_parts.dart';
import 'package:secret_base_app/screens/auth/partner_screen.dart';
import 'package:secret_base_app/v2/v2.dart';

void main() {
  test('password and age rules match the server policy', () {
    expect(isStrongPassword('abcdefg1'), isTrue);
    expect(isStrongPassword('abcdefgh'), isFalse);
    expect(isStrongPassword('12345678'), isFalse);
    expect(isStrongPassword('a1'), isFalse);
    expect(isValidEmail('hello@example.com'), isTrue);
    expect(isValidEmail('not-an-email'), isFalse);
    final today = DateTime(2026, 11, 6);
    expect(isAtLeast14(DateTime(2012, 11, 6), today: today), isTrue);
    expect(isAtLeast14(DateTime(2012, 11, 7), today: today), isFalse);
    expect(isoDate(DateTime(2000, 3, 4)), '2000-03-04');
  });

  test('server error codes become readable Korean without internal terms', () {
    for (final code in [
      'invalid_credentials',
      'email_already_exists',
      'weak_password',
      'under_age',
      'mail_unavailable',
      'invalid_code',
      'code_expired',
      'network_error',
      'something_unknown',
    ]) {
      final message = authErrorMessage(code);
      expect(message, isNot(contains('_')), reason: code);
      expect(message, endsWith('.'), reason: code);
    }
  });

  testWidgets('partner summary distinguishes connected and waiting states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: V2Theme(
          child: Scaffold(
            body: PartnerConnectionSummary(paired: false, hasSentRequest: true),
          ),
        ),
      ),
    );
    expect(find.text('수락을 기다리는 중이에요'), findsOneWidget);
    expect(find.text('상대가 요청을 확인하면 연결돼요.'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: V2Theme(
          child: Scaffold(
            body: PartnerConnectionSummary(paired: true, partnerName: '민지'),
          ),
        ),
      ),
    );
    expect(find.text('연결됨'), findsOneWidget);
    expect(find.text('민지님과 연결되어 있어요.'), findsOneWidget);
  });
}
