import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/relationship/widgets/tarot_card_art.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('22 major arcana in order with unique keys', () {
    expect(kTarotCards.length, 22);
    expect(kTarotCards.map((c) => c.key).toSet().length, 22);
    for (var i = 0; i < kTarotCards.length; i++) {
      final card = kTarotCards[i];
      expect(card.number, i);
      expect(card.name, isNotEmpty);
      expect(card.keywords.length, inInclusiveRange(2, 3));
      expect(tarotCardInfo(card.key), same(card));
    }
    expect(tarotCardInfo('the_star')!.name, '별');
    expect(tarotCardInfo('death')!.name, '끝과 시작');
    expect(tarotCardInfo('nope'), isNull);
  });

  testWidgets('every face and the back paint at small and large sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final card in kTarotCards) ...[
              TarotCardFace(cardKey: card.key),
              TarotCardFace(cardKey: card.key, width: 36),
            ],
            const TarotCardFace(cardKey: 'the_sun', width: 220),
            const TarotCardFace(
              cardKey: 'wheel_of_fortune',
              title: '아주 긴 사용자 지정 제목이 들어간 카드',
            ),
            const TarotCardBack(),
            const TarotCardBack(width: 36),
            const TarotCardBack(width: 220),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(TarotCardFace), findsNWidgets(46));
    expect(
      tester.getSize(find.byType(TarotCardBack).first),
      const Size(120, 200),
    );
  });

  testWidgets('unknown key renders a generic card', (tester) async {
    await tester.pumpWidget(
      _host(const TarotCardFace(cardKey: 'mystery', title: '오늘의 카드')),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TarotCardFace), findsOneWidget);
  });

  testWidgets('semantics labels carry the Korean name', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            TarotCardFace(cardKey: 'the_star'),
            TarotCardFace(cardKey: 'the_devil', title: '나만의 제목'),
            TarotCardBack(),
            TarotCardBack(excludeSemantics: true),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('XVII 별 카드'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('나만의 제목')), findsOneWidget);
    expect(find.bySemanticsLabel('뒤집힌 타로 카드'), findsOneWidget);
    handle.dispose();
  });
}
