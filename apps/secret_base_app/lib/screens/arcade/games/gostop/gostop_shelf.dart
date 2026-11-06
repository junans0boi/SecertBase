import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'gostop_card.dart';
import 'gostop_models.dart';

const _groupOrder = ['bright', 'animal', 'ribbon', 'junk'];
const _groupLabel = {'bright': '광', 'animal': '열끗', 'ribbon': '띠', 'junk': '피'};
const _groupFlex = {'bright': 30, 'animal': 36, 'ribbon': 36, 'junk': 42};

/// 딴 패를 광·열끗·띠·피로 묶어 보여 주는 선반. 묶음마다 개수(피는 쌍피를 2장으로 센 값)를 단다.
class GostopShelf extends StatelessWidget {
  final GameTheme theme;
  final List<HCard> cards;

  /// 날아오는 중이라 아직 보이면 안 되는 패 id.
  final Set<String> hiddenIds;
  final double cardWidth;
  final String semanticsLabel;

  const GostopShelf({
    super.key,
    required this.theme,
    required this.cards,
    this.hiddenIds = const {},
    this.cardWidth = 28,
    this.semanticsLabel = '딴 패',
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label:
          '$semanticsLabel '
          '광 ${_of('bright').length}장, 열끗 ${_of('animal').length}장, '
          '띠 ${_of('ribbon').length}장, 피 ${_piTotal()}장',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.surfaceBorder.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            for (final type in _groupOrder) ...[
              Expanded(
                flex: _groupFlex[type]!,
                child: _Group(
                  theme: t,
                  type: type,
                  cards: _of(type),
                  count: type == 'junk' ? _piTotal() : _of(type).length,
                  hiddenIds: hiddenIds,
                  cardWidth: cardWidth,
                ),
              ),
              if (type != 'junk') const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  List<HCard> _of(String type) => [
    for (final c in cards)
      if (c.type == type) c,
  ];

  int _piTotal() => _of('junk').fold(0, (s, c) => s + (c.isDoubleJunk ? 2 : 1));
}

class _Group extends StatelessWidget {
  final GameTheme theme;
  final String type;
  final List<HCard> cards;
  final int count;
  final Set<String> hiddenIds;
  final double cardWidth;

  const _Group({
    required this.theme,
    required this.type,
    required this.cards,
    required this.count,
    required this.hiddenIds,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = gostopTypeColor(type);
    final h = gostopCardHeight(cardWidth);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: count > 0 ? color : color.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${_groupLabel[type]} $count',
                style: t.body(
                  size: 10.5,
                  weight: FontWeight.w900,
                  color: type == 'bright' && count > 0
                      ? const Color(0xFF3A2A00)
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: h,
          child: LayoutBuilder(
            builder: (context, box) {
              if (cards.isEmpty) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: const SizedBox.expand(),
                );
              }
              final avail = box.maxWidth - cardWidth;
              final step = cards.length <= 1
                  ? 0.0
                  : (avail / (cards.length - 1)).clamp(3.0, cardWidth * 0.62);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    Positioned(
                      left: i * step,
                      top: 0,
                      child: Opacity(
                        opacity: hiddenIds.contains(cards[i].id) ? 0 : 1,
                        child: GostopCard(
                          key: ValueKey('cap-${cards[i].id}'),
                          card: cards[i],
                          width: cardWidth,
                          badge: false,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
