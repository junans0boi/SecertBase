import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/auth/auth_layout.dart';
import 'package:secret_base_app/screens/auth/partner_screen.dart';

void main() {
  test('auth email validation returns readable field errors', () {
    expect(validateAuthEmail(null), '이메일을 입력해주세요.');
    expect(validateAuthEmail('not-an-email'), '이메일 주소를 확인해주세요.');
    expect(validateAuthEmail('hello@example.com'), isNull);
  });

  testWidgets(
    'auth page keeps its CTA below the keyboard and exposes loading state',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 320)),
          child: MaterialApp(
            home: AuthPage(
              header: const Text('header'),
              content: const Text('content'),
              footer: const AuthButton(
                label: '로그인',
                loading: true,
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.fromLTRB(24, 12, 24, 340),
        ),
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(24, 12, 24, 340));
      expect(find.bySemanticsLabel('로그인, 처리 중'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('partner summary distinguishes connected and waiting states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerConnectionSummary(paired: false, hasSentRequest: true),
      ),
    );
    expect(find.text('수락을 기다리는 중이에요'), findsOneWidget);
    expect(find.text('상대방이 요청을 확인하면 연결돼요.'), findsOneWidget);
    expect(find.text('ABC123'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerConnectionSummary(paired: true, partnerName: '민지'),
      ),
    );
    expect(find.text('연결됨'), findsOneWidget);
    expect(find.text('민지와 연결되어 있어요.'), findsOneWidget);
  });
}
