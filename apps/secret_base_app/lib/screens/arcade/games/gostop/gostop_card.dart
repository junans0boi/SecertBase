import 'package:flutter/material.dart';

import '../../../../ui/hwatu_card.dart';
import '../../../../widgets/hwatu/hwatu.dart';
import 'gostop_models.dart';

/// 고스톱 화면이 화투를 그리는 유일한 입구.
///
/// 벡터 화투(`lib/widgets/hwatu/`)를 그린다. 종류 배지(광·열·띠·피, 쌍피 "2")와 월 숫자는 그림이 모서리에 직접 그린다.
enum GostopCardSize {
  /// 내 손패.
  hand(52),

  /// 바닥.
  field(40),

  /// 딴 패 묶음.
  capture(26);

  final double width;
  const GostopCardSize(this.width);
}

/// 종류 배지 색.
Color gostopTypeColor(String type) => switch (type) {
  'bright' => const Color(0xFFE8B63A),
  'animal' => const Color(0xFFE2623A),
  'ribbon' => const Color(0xFF3F8FD2),
  _ => const Color(0xFF8C8C8C),
};

String gostopTypeLabel(String type) => switch (type) {
  'bright' => '광',
  'animal' => '열',
  'ribbon' => '띠',
  _ => '피',
};

double gostopCardHeight(double width) => width * kHwatuCardHeightRatio;

class GostopCard extends StatelessWidget {
  /// null이면 뒷면.
  final HCard? card;
  final double width;
  final bool faceUp;
  final bool highlighted;
  final bool dim;

  /// 종류 배지를 그릴지(너무 작은 딴 패에서는 끈다).
  final bool badge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GostopCard({
    super.key,
    required this.card,
    this.width = 40,
    this.faceUp = true,
    this.highlighted = false,
    this.dim = false,
    this.badge = true,
    this.onTap,
    this.onLongPress,
  });

  GostopCard.sized({
    Key? key,
    required HCard? card,
    required GostopCardSize size,
    bool faceUp = true,
    bool highlighted = false,
    bool dim = false,
    bool? badge,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) : this(
         key: key,
         card: card,
         width: size.width,
         faceUp: faceUp,
         highlighted: highlighted,
         dim: dim,
         badge: badge ?? size != GostopCardSize.capture,
         onTap: onTap,
         onLongPress: onLongPress,
       );

  @override
  Widget build(BuildContext context) {
    final showFace = faceUp && card != null;
    final h = gostopCardHeight(width);
    final c = card;
    Widget face = HwatuArt(
      card: showFace ? c!.toJson() : null,
      faceUp: showFace,
      width: width,
      highlighted: highlighted,
    );
    if (onTap != null || onLongPress != null) {
      face = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: face,
      );
    }
    if (dim) {
      face = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.38),
          BlendMode.srcATop,
        ),
        child: face,
      );
    }
    // 종류 배지·월 숫자·쌍피 "2"는 벡터 화투가 모서리에 직접 그린다.
    return SizedBox(width: width, height: h, child: face);
  }
}

/// 카드 모서리의 종류 배지. 쌍피는 금색 "2"가 따로 붙는다.
class TypeBadge extends StatelessWidget {
  final HCard card;
  final double width;

  const TypeBadge({super.key, required this.card, required this.width});

  @override
  Widget build(BuildContext context) {
    final d = (width * 0.36).clamp(13.0, 22.0);
    final color = gostopTypeColor(card.type);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 2),
            ],
          ),
          child: Text(
            gostopTypeLabel(card.type),
            style: TextStyle(
              color: card.isBright ? const Color(0xFF3A2A00) : Colors.white,
              fontSize: d * 0.58,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        if (card.isDoubleJunk) _DoubleMark(size: d),
      ],
    );
  }
}

class _DoubleMark extends StatelessWidget {
  final double size;

  const _DoubleMark({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size.clamp(11.0, 22.0),
    height: size.clamp(11.0, 22.0),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: kHwatuGold,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1),
    ),
    child: Text(
      '2',
      style: TextStyle(
        color: const Color(0xFF3A2A00),
        fontSize: size.clamp(11.0, 22.0) * 0.62,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}

/// 뒷면에서 앞면으로 3D로 뒤집히는 카드. [t]는 0(뒷면)…1(앞면).
class GostopFlipCard extends StatelessWidget {
  final HCard card;
  final double width;
  final double t;

  const GostopFlipCard({
    super.key,
    required this.card,
    required this.width,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final angle = t * 3.1415926;
    final showFront = t >= 0.5;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..rotateY(showFront ? angle - 3.1415926 : angle);
    return Transform(
      alignment: Alignment.center,
      transform: m,
      child: GostopCard(card: card, width: width, faceUp: showFront),
    );
  }
}
