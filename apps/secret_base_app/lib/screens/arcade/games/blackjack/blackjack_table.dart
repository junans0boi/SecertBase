import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';

/// 벨벳 라운지 테이블: 금박 레일을 두른 에메랄드 펠트 + 위에서 내려오는 스포트라이트.
/// 가운데에 "21" 문장(紋章)과 "먼저 2승" 안내를 새긴다.
class BlackjackFelt extends StatelessWidget {
  final GameTheme theme;
  final Widget child;

  const BlackjackFelt({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FeltPainter(theme), child: child);
  }
}

class _FeltPainter extends CustomPainter {
  final GameTheme t;

  _FeltPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(4);
    // 모서리를 너무 둥글게 하면 위아래 좌석이 레일에 걸친다.
    final radius = Radius.circular(
      math.min(30, math.min(size.width, size.height) * 0.12),
    );
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 레일 그림자.
    canvas.drawRRect(
      rrect.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // 펠트.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 0.95,
          colors: [
            Color.lerp(t.surface, Colors.white, 0.10)!,
            t.surface,
            Color.lerp(t.surface, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // 펠트 결(가는 사선).
    canvas.save();
    canvas.clipRRect(rrect);
    final weave = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        weave,
      );
    }
    // 스포트라이트.
    final spot = Offset(size.width / 2, size.height * 0.38);
    final r = size.longestSide * 0.55;
    canvas.drawCircle(
      spot,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF4D6).withValues(alpha: 0.16),
            const Color(0xFFFFF4D6).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: spot, radius: r)),
    );
    // 가운데 금선 아치(배팅 라인 대신 장식).
    // 위아래 카드 줄 사이(가운데 문장 둘레)에만 그려 카드 밑을 가로지르지 않게 한다.
    final arc = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.height * 0.15,
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = t.gold.withValues(alpha: 0.30);
    canvas.drawArc(arc, math.pi * 1.08, math.pi * 0.84, false, line);
    canvas.drawArc(arc, math.pi * 0.08, math.pi * 0.84, false, line);
    canvas.restore();

    // 금박 레일(바깥 굵은 선 + 안쪽 가는 선).
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = t.goldGradient.createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = t.gold.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _FeltPainter old) => old.t != t;
}

/// 테이블 가운데 문장: "21"과 짧은 안내.
class BlackjackEmblem extends StatelessWidget {
  final GameTheme theme;
  final String caption;

  /// 차례가 진행 중이면 "21" 대신 남은 시간 링을 보여 준다.
  final Widget? timer;

  const BlackjackEmblem({
    super.key,
    required this.theme,
    required this.caption,
    this.timer,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Center(
              child:
                  timer ??
                  Text(
                    '21',
                    style: t
                        .display(
                          size: 30,
                          color: t.gold.withValues(alpha: 0.55),
                        )
                        .copyWith(letterSpacing: 2),
                  ),
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(size: 11.5, color: t.subInk.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

/// 카드가 나오는 신발(딜링 슈): 금박 테두리 나무 상자에 카드 뒷면이 비스듬히 꽂혀 있다.
class BlackjackShoe extends StatelessWidget {
  final GameTheme theme;
  final double width;

  const BlackjackShoe({super.key, required this.theme, this.width = 54});

  @override
  Widget build(BuildContext context) {
    final h = width * 1.15;
    return Semantics(
      label: '카드 덱',
      child: SizedBox(
        width: width,
        height: h,
        child: CustomPaint(painter: _ShoePainter(theme)),
      ),
    );
  }
}

class _ShoePainter extends CustomPainter {
  final GameTheme t;

  _ShoePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 꽂힌 카드 뒷면 몇 장.
    for (var i = 0; i < 4; i++) {
      final card = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          w * 0.16 + i * 1.6,
          h * 0.04 + i * 1.2,
          w * 0.62,
          h * 0.6,
        ),
        Radius.circular(w * 0.07),
      );
      canvas.drawRRect(
        card,
        Paint()
          ..color = i == 3 ? const Color(0xFF15604F) : const Color(0xFF0E4A3F),
      );
      canvas.drawRRect(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = t.gold.withValues(alpha: 0.75),
      );
    }
    // 상자.
    final body = Path()
      ..moveTo(0, h * 0.42)
      ..lineTo(w, h * 0.32)
      ..lineTo(w, h * 0.96)
      ..lineTo(0, h * 0.96)
      ..close();
    canvas.drawShadow(body, Colors.black, 6, false);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B3E22), Color(0xFF3B2012)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..shader = t.goldGradient.createShader(Offset.zero & size),
    );
    // 금박 명판.
    final plate = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.62, w * 0.56, h * 0.16),
      Radius.circular(h * 0.05),
    );
    canvas.drawRRect(
      plate,
      Paint()..shader = t.goldGradient.createShader(plate.outerRect),
    );
  }

  @override
  bool shouldRepaint(covariant _ShoePainter old) => old.t != t;
}

/// 라운드 승수 표시(먼저 [needed]승): ●○.
class RoundPips extends StatelessWidget {
  final GameTheme theme;
  final int wins;
  final int needed;
  final Color color;
  final String label;

  const RoundPips({
    super.key,
    required this.theme,
    required this.wins,
    required this.needed,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label: '$label $wins승',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < needed; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              width: 13,
              height: 13,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < wins ? color : Colors.transparent,
                border: Border.all(
                  color: i < wins ? t.gold : color.withValues(alpha: 0.7),
                  width: 1.6,
                ),
                boxShadow: i < wins
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// 점수 배지: 큰 숫자 + 작은 설명("공개 7 + ?").
class ScorePlaque extends StatelessWidget {
  final GameTheme theme;
  final String value;
  final String caption;
  final Color color;
  final bool glow;

  const ScorePlaque({
    super.key,
    required this.theme,
    required this.value,
    required this.caption,
    required this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label: '$caption $value',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        // 두 점수판의 폭을 맞춰 왼쪽 끝이 어긋나지 않게 한다.
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: glow ? t.gold : t.gold.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: t.gold.withValues(alpha: 0.5),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                caption,
                style: t.body(
                  size: 10,
                  color: t.subInk,
                  weight: FontWeight.w700,
                ),
              ),
              Text(value, style: t.display(size: 21, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
