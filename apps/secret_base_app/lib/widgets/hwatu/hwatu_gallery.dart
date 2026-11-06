import 'package:flutter/widgets.dart';

import 'hwatu_art.dart';
import 'hwatu_deck.dart';
import 'hwatu_kit.dart';

/// 검토용 갤러리: 열두 달을 한 줄씩(4장) 늘어놓고 맨 끝에 뒷면을 둔다.
class HwatuGallery extends StatelessWidget {
  const HwatuGallery({
    super.key,
    this.cardWidth = 56,
    this.months = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    this.showBack = true,
    this.background = const Color(0xFF1F4D36),
  });

  final double cardWidth;
  final List<int> months;
  final bool showBack;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final gap = (cardWidth * 0.12).clamp(3.0, 10.0);
    final rows = <Widget>[
      for (final m in months)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final spec in kHwatuDeck.where((c) => c.month == m))
              Padding(
                padding: EdgeInsets.all(gap / 2),
                child: HwatuArt(cardId: spec.id, width: cardWidth),
              ),
          ],
        ),
      if (showBack)
        Padding(
          padding: EdgeInsets.all(gap / 2),
          child: HwatuArt.back(width: cardWidth),
        ),
    ];
    return ColoredBox(
      color: background,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ),
      ),
    );
  }

  /// 갤러리 전체 크기(테스트 화면 크기를 정할 때).
  Size get preferredSize {
    final gap = (cardWidth * 0.12).clamp(3.0, 10.0);
    final cell = Size(cardWidth + gap, cardWidth * kHwatuAspect + gap);
    final rowCount = months.length + (showBack ? 1 : 0);
    return Size(cell.width * 4 + gap * 2, cell.height * rowCount + gap * 2);
  }
}
