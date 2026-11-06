import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'onecard_models.dart';
import 'onecard_ui.dart';

/// 카드 크기 비율(가로:세로 = 1:1.46).
const double kOneCardAspect = 1.46;

/// 카드 그림자 모음(목업 box-shadow와 같은 값).
class OneCardShadows {
  OneCardShadows._();

  static const rest = [
    BoxShadow(
      color: Color(0x73000000),
      offset: Offset(0, 6),
      blurRadius: 12,
      spreadRadius: -4,
    ),
  ];
  static const lift = [
    BoxShadow(
      color: Color(0x99000000),
      offset: Offset(0, 14),
      blurRadius: 22,
      spreadRadius: -6,
    ),
    BoxShadow(color: Color(0xE6FFFFFF), spreadRadius: 2),
  ];
  static const row = [
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 3),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];
  static const mini = [
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -3,
    ),
  ];
  static const fan = [
    BoxShadow(color: Color(0x59000000), offset: Offset(0, 2), blurRadius: 6),
  ];
}

/// 원카드 앞면(목업 카드): 솔리드 한 색 + 헤어라인 안쪽선 + 큰 숫자 + 모서리 표시.
/// 색마다 작은 기호(하트·다이아·스페이드·클럽)를 붙여 색만으로 구분하지 않게 한다. 기호는 직접 그린다.
class OneCardFace extends StatelessWidget {
  final OneCard card;
  final double width;

  /// 버린 더미 위 와일드: 고른 색으로 테두리가 물든다(Q53).
  final String? tintColor;
  final bool dimmed;
  final List<BoxShadow> shadows;

  const OneCardFace({
    super.key,
    required this.card,
    this.width = 60,
    this.tintColor,
    this.dimmed = false,
    this.shadows = OneCardShadows.rest,
  });

  static const _even = TextHeightBehavior(
    leadingDistribution: TextLeadingDistribution.even,
  );

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w * kOneCardAspect;
    final wild = card.color == null;
    final honey = card.color == 'yellow';
    final bg = wild ? const Color(0xFF1A1030) : OneCardSuit.color(card.color);
    final fg = honey ? const Color(0xFF2E1C00) : Colors.white;
    final tint = wild && tintColor != null
        ? OneCardSuit.color(tintColor)
        : null;
    final hairline =
        tint ??
        (honey
            ? const Color(0x472E1C00)
            : (wild ? const Color(0x47FFFFFF) : const Color(0x52FFFFFF)));
    final big = card.value == 'draw2' ? w * 0.42 : w * 0.58;
    final isIcon = const {
      'skip',
      'reverse',
      'discard_all',
    }.contains(card.value);
    final isNumber = card.isNumber;
    final text = card.value == 'draw2' ? '+2' : card.value;

    Widget center;
    if (wild) {
      center = SizedBox.square(
        dimension: big * 0.62,
        child: const CustomPaint(painter: _QuadPainter()),
      );
    } else {
      final Widget glyph = isIcon
          ? SizedBox.square(
              dimension: big * 0.46,
              child: CustomPaint(painter: _IconPainter(card.value, fg)),
            )
          : Text(
              text,
              maxLines: 1,
              style: OneCardUi.sans(
                size: big,
                color: fg,
                weight: FontWeight.w800,
                height: 1,
                spacing: -0.04,
              ),
              textHeightBehavior: _even,
            );
      final ellipse = Transform.rotate(
        angle: 24 * math.pi / 180,
        child: Container(
          width: 0.78 * big,
          height: 1.25 * big,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.elliptical(0.39 * big, 0.625 * big),
            ),
            color: Colors.white.withValues(alpha: honey ? 0.28 : 0.14),
          ),
        ),
      );
      // 목업처럼 숫자 글자는 타원 "아래"(타원이 살짝 덮음), 아이콘은 타원 "위"에 그린다.
      center = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: isIcon ? [ellipse, glyph] : [glyph, ellipse],
      );
    }

    final f = w * 0.22;
    Widget index() {
      Widget content;
      if (wild) {
        content = card.value == 'wild_draw4'
            ? Text(
                '+4',
                style: OneCardUi.sans(
                  size: f,
                  color: fg,
                  weight: FontWeight.w800,
                  height: 1,
                  spacing: -0.04,
                ),
                textHeightBehavior: _even,
              )
            : const SizedBox.shrink();
      } else if (isIcon) {
        content = SizedBox.square(
          dimension: f,
          child: CustomPaint(painter: _IconPainter(card.value, fg)),
        );
      } else {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              maxLines: 1,
              style: OneCardUi.sans(
                size: f,
                color: fg,
                weight: FontWeight.w800,
                height: 1,
                spacing: -0.04,
              ),
              textHeightBehavior: _even,
            ),
            if (isNumber) ...[
              SizedBox(height: f * 0.14),
              SizedBox.square(
                dimension: f * 0.78,
                child: CustomPaint(
                  painter: SuitPainter(OneCardSuit.index(card.color), fg),
                ),
              ),
            ],
          ],
        );
      }
      return SizedBox(
        width: f * 1.1,
        child: Center(child: content),
      );
    }

    return Semantics(
      label: card.label,
      child: SizedBox(
        width: w,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(w * 0.13),
            boxShadow: [
              ...shadows,
              if (tint != null)
                BoxShadow(
                  color: tint.withValues(alpha: 0.5),
                  blurRadius: w * 0.22,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.13),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.all(w * 0.05),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(w * 0.09),
                      border: Border.all(
                        color: hairline,
                        width: tint != null ? 1.6 : 1,
                      ),
                    ),
                  ),
                ),
                Center(child: center),
                Positioned(left: f * 0.12, top: f * 0.15, child: index()),
                Positioned(
                  right: f * 0.12,
                  bottom: f * 0.15,
                  child: Transform.rotate(angle: math.pi, child: index()),
                ),
                if (dimmed) const ColoredBox(color: Color(0x94150C2A)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 건너뛰기 · 방향 바꾸기 · 모두 내기 아이콘(24 격자 선화).
class _IconPainter extends CustomPainter {
  final String kind;
  final Color color;

  _IconPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    switch (kind) {
      case 'skip':
        p.strokeWidth = 2.6;
        canvas.drawCircle(const Offset(12, 12), 8.2, p);
        canvas.drawLine(const Offset(6.4, 17.6), const Offset(17.6, 6.4), p);
      case 'reverse':
        p.strokeWidth = 2.6;
        canvas.drawPath(
          Path()
            ..moveTo(4, 8)
            ..lineTo(18, 8)
            ..moveTo(14, 4)
            ..lineTo(18, 8)
            ..lineTo(14, 12)
            ..moveTo(20, 16)
            ..lineTo(6, 16)
            ..moveTo(10, 12)
            ..lineTo(6, 16)
            ..lineTo(10, 20),
          p,
        );
      default:
        p.strokeWidth = 2.2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 6, 11, 14),
            const Radius.circular(2.4),
          ),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 3.2)
            ..lineTo(18.2, 3.2)
            ..arcToPoint(
              const Offset(20.5, 5.5),
              radius: const Radius.circular(2.3),
            )
            ..lineTo(20.5, 16),
          p,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.kind != kind || old.color != color;
}

/// 색 바꾸기 카드의 4색 바퀴(부채꼴 넷).
class _QuadPainter extends CustomPainter {
  const _QuadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.4;
    final rect = Rect.fromCircle(center: c, radius: r);
    void slice(double start, Color color) =>
        canvas.drawArc(rect, start, math.pi / 2, true, Paint()..color = color);
    slice(-math.pi / 2, OneCardUi.honey);
    slice(0, OneCardUi.sky);
    slice(math.pi / 2, OneCardUi.sage);
    slice(math.pi, OneCardUi.rose);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter old) => false;
}

/// 카드 뒷면. 기본은 보라 격자 + 가운데 마름모, 상점 아이템(원카드 카드 뒷면)은 색·그림으로 바뀐다.
class OneCardBack extends StatelessWidget {
  final double width;
  final String skin;
  final List<BoxShadow> shadows;

  const OneCardBack({
    super.key,
    this.width = 60,
    this.skin = 'base',
    this.shadows = OneCardShadows.rest,
  });

  /// 스킨 id → (그라데이션, 아이콘). 상점 아이템 아이콘에서 고른다([skinFromItem]).
  static const skins = <String, (List<Color>, String)>{
    'cherry_blossom': ([Color(0xFFFFB7D5), Color(0xFFFF6F9F)], '🌸'),
    'space': ([Color(0xFF1A1A3E), Color(0xFF0D0D24)], '🌌'),
    'heart': ([Color(0xFFFF4444), Color(0xFFCC0000)], '❤️'),
    'gold': ([Color(0xFFFFD700), Color(0xFFB8860B)], '✨'),
    'rainbow': ([Color(0xFFFF6B6B), Color(0xFF6B6BFF)], '🌈'),
    'couple_card': ([Color(0xFFFF8FAB), Color(0xFFB983FF)], '💑'),
    'fog': ([Color(0xFFD0D8E4), Color(0xFF8FA3B1)], '🌫️'),
    'sunset': ([Color(0xFFFF7F50), Color(0xFFFF4500)], '🌅'),
    'water': ([Color(0xFF00B4DB), Color(0xFF0083B0)], '💧'),
    'night': ([Color(0xFF1A1A2E), Color(0xFF16213E)], '🌙'),
    'autumn': ([Color(0xFFE65C00), Color(0xFFF9D423)], '🍁'),
    'aurora': ([Color(0xFF0F2027), Color(0xFF203A43)], '🌌'),
    'firefly': ([Color(0xFF0D1B2A), Color(0xFF1B4332)], '✨'),
    'stardust': ([Color(0xFF1C1C3C), Color(0xFF2D2D5E)], '⭐'),
    'fireworks': ([Color(0xFF0D0D0D), Color(0xFF1A0033)], '🎆'),
    'eternity': ([Color(0xFF1A0038), Color(0xFF2D0057)], '♾️'),
    'fate': ([Color(0xFF7B0000), Color(0xFFB8860B)], '🎴'),
  };

  /// 장착 아이템(`equippedItems[user].onecard_cardback`의 icon·grade) → 스킨 id.
  static String skinFromItem(Map<String, dynamic>? item) {
    if (item == null) return 'base';
    final icon = item['icon'] as String? ?? '';
    final grade = item['grade'] as String? ?? 'B';
    return switch (icon) {
      '🌫️' => 'fog',
      '🌅' || '🌇' => 'sunset',
      '💧' || '💦' => 'water',
      '🌙' => 'night',
      '🍁' => 'autumn',
      '🌌' => 'aurora',
      '✨' => 'firefly',
      '⭐' => 'stardust',
      '🎆' => 'fireworks',
      '♾️' => 'eternity',
      '🎴' => 'fate',
      '💑' => 'couple_card',
      '🌸' || '🌺' => 'cherry_blossom',
      '❤️' || '💕' => 'heart',
      '🌈' => 'rainbow',
      _ => switch (grade) {
        'SSS' => 'rainbow',
        'SS' => 'eternity',
        'S' => 'aurora',
        'A' => 'stardust',
        _ => 'base',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w * kOneCardAspect;
    final entry = skins[skin];
    const base = Color(0xFF3A2470);
    return Semantics(
      label: '뒷면 카드',
      child: SizedBox(
        width: w,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(w * 0.13),
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (entry != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: entry.$1,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(w * 0.05),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(w * 0.09),
                      border: Border.all(color: const Color(0x66B9A2FF)),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(w * 0.1),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(w * 0.06),
                    child: CustomPaint(
                      painter: _HatchPainter(period: w * 0.12),
                      child: Center(
                        child: entry != null
                            ? Text(
                                entry.$2,
                                style: TextStyle(fontSize: w * 0.3),
                              )
                            : Transform.rotate(
                                angle: math.pi / 4,
                                child: Container(
                                  width: w * 0.34,
                                  height: w * 0.34,
                                  decoration: BoxDecoration(
                                    color: base,
                                    border: Border.all(
                                      color: const Color(0xB3B9A2FF),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 뒷면 격자: 45도와 -45도의 가는 선을 [period] 간격으로.
class _HatchPainter extends CustomPainter {
  final double period;

  _HatchPainter({required this.period});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x29B9A2FF)
      ..strokeWidth = 1;
    final len = size.width + size.height;
    final step = math.max(2.0, period);
    const k = 0.7071;
    for (var t = 0.0; t < len; t += step) {
      final b = Offset(k * t, size.height - k * t);
      canvas.drawLine(
        b + const Offset(-k, -k) * len,
        b + const Offset(k, k) * len,
        p,
      );
      final b2 = Offset(size.width - k * t, size.height - k * t);
      canvas.drawLine(
        b2 + const Offset(k, -k) * len,
        b2 + const Offset(-k, k) * len,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter old) => old.period != period;
}

/// 항상 보이는 "지금 색" 칩(Q53): 색 점 + 이름.
class CurrentColorChip extends StatelessWidget {
  final String? color;
  final bool declared;

  const CurrentColorChip({
    super.key,
    required this.color,
    this.declared = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = OneCardSuit.color(color);
    final name = OneCardColors.name(color);
    return Semantics(
      label: '지금 색 $name${declared ? ', 색 바꾸기로 정해짐' : ''}',
      child: Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: OneCardUi.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              width: 14,
              height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c),
            ),
            const SizedBox(width: 8),
            Text('지금 색', style: OneCardUi.sans(size: 12, color: OneCardUi.sub)),
            const SizedBox(width: 8),
            Text(
              name.isEmpty ? '-' : name,
              style: OneCardUi.sans(size: 13, weight: FontWeight.w700),
            ),
            if (declared) ...[
              const SizedBox(width: 2),
              Text(
                '바뀜',
                style: OneCardUi.sans(
                  size: 12,
                  color: OneCardUi.vio2,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
