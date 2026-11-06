import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/widgets/hwatu/hwatu.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  group('덱 정체성', () {
    test('48장이며 종류·띠·쌍피 수가 엔진과 같다', () {
      expect(kHwatuDeck, hasLength(48));
      expect({for (final c in kHwatuDeck) c.id}, hasLength(48));
      int count(bool Function(HwatuCardSpec) f) => kHwatuDeck.where(f).length;
      expect(count((c) => c.type == HwatuType.bright), 5);
      expect(count((c) => c.type == HwatuType.animal), 9);
      expect(count((c) => c.type == HwatuType.ribbon), 10);
      expect(count((c) => c.type == HwatuType.junk), 24);
      expect(count((c) => c.ribbon == HwatuRibbon.hong), 3);
      expect(count((c) => c.ribbon == HwatuRibbon.cheong), 3);
      expect(count((c) => c.ribbon == HwatuRibbon.cho), 4);
      expect(count((c) => c.isDouble), 2);
      expect(count((c) => c.isRain), 1);
      for (var m = 1; m <= 12; m++) {
        expect(count((c) => c.month == m), 4, reason: '$m월');
      }
    });

    test('엔진 카드 맵을 정체성으로 바꾼다', () {
      final s = hwatuSpecFromCard({
        'id': 'm12_junk_d',
        'month': 12,
        'type': 'junk',
        'subtype': 'double',
      });
      expect(s?.isDouble, isTrue);
      expect(s?.label, '12월 비 쌍피');
      // 호환 id: m1_animal은 홍단 띠.
      expect(hwatuSpecById('m1_animal')?.ribbon, HwatuRibbon.hong);
      expect(hwatuSpecById('m7_animal_2')?.ribbon, HwatuRibbon.cho);
      expect(hwatuSpecFromCard(null), isNull);
      expect(hwatuSpecFromCard({'id': 'back'}), isNull);
    });
  });

  group('렌더', () {
    for (final width in [30.0, 56.0, 120.0]) {
      testWidgets('48장 + 뒷면이 ${width.toInt()}px 폭에서 예외 없이 그려진다', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final c in kHwatuDeck)
                    HwatuArt(card: {'id': c.id}, width: width),
                  HwatuArt(card: null, width: width),
                  HwatuArt(cardId: 'm3_bright', width: width, faceUp: false),
                  HwatuArt(
                    cardId: 'm8_bright',
                    width: width,
                    highlighted: true,
                  ),
                  HwatuArt(cardId: 'm9_animal', width: width, dimmed: true),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(HwatuArt), findsNWidgets(52));
        final size = tester.getSize(find.byType(HwatuArt).first);
        expect(size.width, width);
        expect(size.height, closeTo(width * kHwatuAspect, 0.001));
      });
    }

    testWidgets('갤러리가 열두 달과 뒷면을 그린다', (tester) async {
      await tester.pumpWidget(_host(const HwatuGallery(cardWidth: 40)));
      expect(tester.takeException(), isNull);
      expect(find.byType(HwatuArt), findsNWidgets(49));
    });

    testWidgets('위젯 의미 라벨이 월·종류를 알려준다', (tester) async {
      await tester.pumpWidget(
        _host(const HwatuArt(cardId: 'm3_bright', width: 56)),
      );
      expect(find.bySemanticsLabel('3월 벚꽃 광'), findsOneWidget);
    });
  });
}
