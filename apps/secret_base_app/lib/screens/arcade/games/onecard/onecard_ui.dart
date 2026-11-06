import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';

/// 원카드 쇼타임 디자인 토큰(목업 `#g-onecard`와 같은 값). 한 화면 강조색은 보라 하나,
/// 카드 4색은 로즈·허니·스카이·세이지.
class OneCardUi {
  OneCardUi._();

  static const ink = Color(0xFFF5F1FF);
  static const sub = Color(0xFFA99BCB);
  static const mut = Color(0xFF7A6BA3);
  static const line = Color(0x1AFFFFFF);
  static const bg = Color(0xFF150C2A);
  static const vio = Color(0xFF8E6CF2);
  static const vio2 = Color(0xFFB9A2FF);
  static const rose = Color(0xFFD94A72);
  static const honey = Color(0xFFE2A430);
  static const sky = Color(0xFF3F8FD9);
  static const sage = Color(0xFF3FA37C);
  static const sheet = Color(0xFF21153F);
  static const roseSoft = Color(0xFFFFB3C6);
  static const warn = Color(0xFFFF8FAB);
  static const urgent = Color(0xFFFF7A9C);
  static const meAvatar = Color(0xFF4A3A82);
  static const oppAvatar = Color(0xFF6B3F7E);
  static const offText = Color(0xFF6D5E96);

  /// 글자: Noto Sans KR. [spacing]은 em 단위(CSS letter-spacing과 같은 값).
  static TextStyle sans({
    double size = 14,
    Color color = ink,
    FontWeight weight = FontWeight.w500,
    double? height,
    double spacing = 0,
    List<FontFeature>? features,
  }) => GoogleFonts.notoSansKr(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing * size,
    fontFeatures: features,
  );

  /// 결과 헤드라인 전용 굵은 고딕.
  static TextStyle headline({double size = 54, Color color = ink}) =>
      GoogleFonts.blackHanSans(fontSize: size, color: color, height: 1.1);

  static const tabular = [FontFeature.tabularFigures()];

  static Color tint(Color c, double alpha) => c.withValues(alpha: alpha);

  /// 공용 부품(규칙 창·리액션)에 넘기는 테마.
  static final GameTheme theme = GameTheme(
    id: 'onecard',
    texture: GameTexture.stage,
    dark: true,
    backdrop: const [bg, bg, bg],
    surface: sheet,
    surfaceBorder: const Color(0x1FFFFFFF),
    accent: vio,
    accentSoft: const Color(0x338E6CF2),
    gold: vio2,
    ink: ink,
    subInk: sub,
    me: vio2,
    opponent: warn,
    displayFont: _display,
  );

  static TextStyle _display({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w800,
  }) => sans(size: size, color: color ?? ink, weight: FontWeight.w800);
}

/// 카드 색 이름(서버 값) 한 곳에서 4색 + 기호를 돌려준다.
class OneCardSuit {
  OneCardSuit._();

  static Color color(String? c) => switch (c) {
    'red' => OneCardUi.rose,
    'yellow' => OneCardUi.honey,
    'blue' => OneCardUi.sky,
    'green' => OneCardUi.sage,
    _ => OneCardUi.vio,
  };

  /// 하트·다이아·스페이드·클럽(색약 보조 기호).
  static int index(String? c) => switch (c) {
    'red' => 0,
    'yellow' => 1,
    'blue' => 2,
    'green' => 3,
    _ => 0,
  };
}

/// 하트·다이아·스페이드·클럽을 글꼴 없이 직접 그린다.
class SuitPainter extends CustomPainter {
  final int suit;
  final Color color;

  SuitPainter(this.suit, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 24);
    final p = Paint()..color = color;
    switch (suit) {
      case 0:
        canvas.drawPath(_heart(), p);
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(12, 1.5)
            ..lineTo(19, 12)
            ..lineTo(12, 22.5)
            ..lineTo(5, 12)
            ..close(),
          p,
        );
      case 2:
        canvas.save();
        canvas.translate(0, 24);
        canvas.scale(1, -1);
        canvas.translate(0, 2.2);
        canvas.scale(1, 0.84);
        canvas.drawPath(_heart(), p);
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(12, 13)
            ..lineTo(15.4, 22.5)
            ..lineTo(8.6, 22.5)
            ..close(),
          p,
        );
      default:
        canvas.drawCircle(const Offset(12, 6.6), 5.2, p);
        canvas.drawCircle(const Offset(6.2, 14), 5.2, p);
        canvas.drawCircle(const Offset(17.8, 14), 5.2, p);
        canvas.drawPath(
          Path()
            ..moveTo(12, 10)
            ..lineTo(15.6, 22.5)
            ..lineTo(8.4, 22.5)
            ..close(),
          p,
        );
    }
    canvas.restore();
  }

  Path _heart() => Path()
    ..moveTo(12, 22)
    ..cubicTo(3, 15.2, 1.2, 10.6, 1.2, 7.6)
    ..cubicTo(1.2, 4, 3.8, 1.8, 6.8, 1.8)
    ..cubicTo(9.2, 1.8, 11, 3.2, 12, 5.2)
    ..cubicTo(13, 3.2, 14.8, 1.8, 17.2, 1.8)
    ..cubicTo(20.2, 1.8, 22.8, 4, 22.8, 7.6)
    ..cubicTo(22.8, 10.6, 21, 15.2, 12, 22)
    ..close();

  @override
  bool shouldRepaint(covariant SuitPainter old) =>
      old.suit != suit || old.color != color;
}

/// 배경: 짙은 보라 무대 + 위·아래의 은은한 빛.
class OneCardBackdrop extends StatelessWidget {
  final Widget child;

  const OneCardBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OneCardUi.bg,
      child: CustomPaint(painter: _BackdropPainter(), child: child),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  void _glow(Canvas canvas, Offset c, double rx, double ry, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(rx, ry);
    final rect = Rect.fromCircle(center: Offset.zero, radius: 1);
    canvas.drawRect(
      const Rect.fromLTRB(-1, -1, 1, 1),
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _glow(
      canvas,
      Offset(size.width / 2, 0),
      size.width * 0.7,
      size.height * 0.42,
      const Color(0x4D8E6CF2),
    );
    _glow(
      canvas,
      Offset(size.width / 2, size.height),
      size.width * 0.9,
      size.height * 0.4,
      const Color(0x385E38BE),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => false;
}

/// 위에서 내려오는 한 줄기 스포트라이트.
class OneCardSpot extends StatelessWidget {
  const OneCardSpot({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(size: const Size(360, 360), painter: _SpotPainter()),
    );
  }
}

class _SpotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.41, 0)
      ..lineTo(w * 0.59, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x29CEBEFF), Color(0x00CEBEFF)],
          stops: [0, 0.85],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotPainter old) => false;
}

/// 상단 바: 뒤로, 제목 + 모드 태그, 규칙, 소리(그리고 [trailing]).
class OneCardTopBar extends StatefulWidget {
  final String tag;
  final VoidCallback? onHelp;
  final Widget? trailing;
  final VoidCallback? onBack;

  const OneCardTopBar({
    super.key,
    required this.tag,
    this.onHelp,
    this.trailing,
    this.onBack,
  });

  @override
  State<OneCardTopBar> createState() => _OneCardTopBarState();
}

class _OneCardTopBarState extends State<OneCardTopBar> {
  @override
  Widget build(BuildContext context) {
    final sfx = GameSfx.instance;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _IconBtn(
              tooltip: '게임 나가기',
              icon: const _BackGlyph(),
              onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '원카드',
                    style: OneCardUi.sans(
                      size: 17,
                      weight: FontWeight.w800,
                      spacing: -0.02,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: OneCardUi.vio2.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        widget.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OneCardUi.sans(
                          size: 12,
                          color: OneCardUi.vio2,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onHelp != null)
              _IconBtn(
                tooltip: '규칙 보기',
                icon: const _HelpGlyph(),
                onTap: widget.onHelp!,
              ),
            _IconBtn(
              tooltip: sfx.muted ? '소리 켜기' : '소리 끄기',
              icon: _SoundGlyph(muted: sfx.muted),
              onTap: () async {
                await sfx.setMuted(!sfx.muted);
                if (!sfx.muted) sfx.play(GameSound.tap);
                if (mounted) setState(() {});
              },
            ),
            ?widget.trailing,
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String tooltip;
  final Widget icon;
  final VoidCallback onTap;

  const _IconBtn({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: SizedBox(width: 22, height: 22, child: icon)),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  final CustomPainter painter;
  const _Glyph(this.painter);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(22, 22), painter: painter);
}

class _BackGlyph extends _Glyph {
  const _BackGlyph() : super(const _StrokePainter(_StrokeKind.back, 2.2));
}

class _HelpGlyph extends _Glyph {
  const _HelpGlyph() : super(const _StrokePainter(_StrokeKind.help, 2));
}

class _SoundGlyph extends _Glyph {
  _SoundGlyph({required bool muted})
    : super(_StrokePainter(_StrokeKind.sound, 2, muted: muted));
}

enum _StrokeKind { back, help, sound }

class _StrokePainter extends CustomPainter {
  final _StrokeKind kind;
  final double width;
  final bool muted;

  const _StrokePainter(this.kind, this.width, {this.muted = false});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = OneCardUi.sub;
    switch (kind) {
      case _StrokeKind.back:
        canvas.drawPath(
          Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19),
          p,
        );
      case _StrokeKind.help:
        canvas.drawCircle(const Offset(12, 12), 8.5, p);
        canvas.drawPath(
          Path()
            ..moveTo(9.8, 9.5)
            ..arcToPoint(
              const Offset(13, 11.6),
              radius: const Radius.circular(2.3),
              largeArc: true,
            )
            ..cubicTo(12.3, 12, 12, 12.4, 12, 13.2),
          p,
        );
        canvas.drawLine(const Offset(12, 16.6), const Offset(12, 16.7), p);
      case _StrokeKind.sound:
        canvas.drawPath(
          Path()
            ..moveTo(4, 9.5)
            ..lineTo(4, 14.5)
            ..lineTo(7.5, 14.5)
            ..lineTo(12, 18.5)
            ..lineTo(12, 5.5)
            ..lineTo(7.5, 9.5)
            ..close(),
          p,
        );
        if (muted) {
          canvas.drawLine(const Offset(16, 9.5), const Offset(21, 14.5), p);
          canvas.drawLine(const Offset(21, 9.5), const Offset(16, 14.5), p);
        } else {
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(15.5, 12), radius: 3),
            -math.pi / 2.6,
            math.pi / 1.3,
            false,
            p,
          );
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(16, 12), radius: 6.2),
            -math.pi / 2.9,
            math.pi / 1.45,
            false,
            p,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) =>
      old.kind != kind || old.muted != muted;
}

enum OneCardButtonStyle { primary, ghost, rose, off, sky }

/// 하단 단일 주 버튼(높이 56, 반경 16, 단색).
class OneCardMainButton extends StatelessWidget {
  final String label;
  final OneCardButtonStyle style;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;

  const OneCardMainButton({
    super.key,
    required this.label,
    this.style = OneCardButtonStyle.primary,
    this.onPressed,
    this.height = 56,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      OneCardButtonStyle.primary => (OneCardUi.vio, Colors.white, null),
      OneCardButtonStyle.sky => (OneCardUi.sky, Colors.white, null),
      OneCardButtonStyle.rose => (OneCardUi.rose, Colors.white, null),
      OneCardButtonStyle.ghost => (
        const Color(0x14FFFFFF),
        OneCardUi.ink,
        const Color(0x29FFFFFF),
      ),
      OneCardButtonStyle.off => (
        const Color(0x0DFFFFFF),
        OneCardUi.offText,
        OneCardUi.line,
      ),
    };
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: border == null ? null : Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OneCardUi.sans(
                      size: 16,
                      color: fg,
                      weight: FontWeight.w800,
                      spacing: -0.01,
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

/// 이름 첫 글자(원형 아바타 안 글자).
String oneCardInitial(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return String.fromCharCode(t.runes.first);
}

/// 천 단위 쉼표.
String oneCardMoney(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// 규칙 요약(상단 ? 버튼, 첫 입장 안내).
const kOneCardHowToLines = [
  '지금 색이나 같은 숫자·기호 카드를 내요. 먼저 손패를 비우면 승리!',
  '낼 카드가 없으면 더미에서 한 장 뽑아요. 낼 수 있으면 바로 내거나 넘겨요.',
  '건너뛰기·방향 바꾸기 카드는 한 번 더, +2·+4는 상대에게 벌칙. 고와일드에선 벌칙을 쌓아 넘길 수 있어요.',
  '◐ 색 바꾸기와 +4는 원하는 색을 골라요. "모두"는 같은 색 카드를 한꺼번에 내요.',
  '한 장 남으면 "원카드!"를 눌러요. 먼저 "잡기!"를 당하면 2장을 받아요.',
  '+4는 그 색이 있었는데 냈다면 "도전!"으로 잡을 수 있어요. 20초가 지나면 자동으로 한 장 뽑고 넘어가요.',
];

void showOneCardHowTo(BuildContext context) => showGameHowTo(
  context,
  theme: OneCardUi.theme,
  title: '원카드',
  emoji: '🃏',
  lines: kOneCardHowToLines,
);
