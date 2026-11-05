import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 게임 화면의 바탕 질감.
enum GameTexture { felt, paper, stage, deck, stadium, velvet }

/// 게임 2.0 테마 토큰. 게임마다 그 게임에 맞는 고급 테마를 쓰고(01-grilling Q6),
/// 공용 부품은 하드코딩 색 없이 이 토큰만 쓴다.
@immutable
class GameTheme {
  final String id;
  final GameTexture texture;
  final bool dark;

  /// 바탕 그라데이션(위→아래).
  final List<Color> backdrop;

  /// 판·패널 표면과 테두리.
  final Color surface;
  final Color surfaceBorder;

  /// 주 강조색, 그 옅은 색, 금박 테두리색.
  final Color accent;
  final Color accentSoft;
  final Color gold;

  /// 바탕 위 글자색.
  final Color ink;
  final Color subInk;

  /// 나/상대 표시색.
  final Color me;
  final Color opponent;

  /// 제목·점수용 서체.
  final TextStyle Function({double size, Color? color, FontWeight weight})
  displayFont;

  const GameTheme({
    required this.id,
    required this.texture,
    required this.dark,
    required this.backdrop,
    required this.surface,
    required this.surfaceBorder,
    required this.accent,
    required this.accentSoft,
    required this.gold,
    required this.ink,
    required this.subInk,
    required this.me,
    required this.opponent,
    required this.displayFont,
  });

  /// 본문 서체(모든 테마 공통: Noto Sans KR).
  TextStyle body({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) => GoogleFonts.notoSans(
    fontSize: size,
    color: color ?? ink,
    fontWeight: weight,
    height: height,
  );

  TextStyle display({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) => displayFont(size: size, color: color ?? ink, weight: weight);

  /// 강조 버튼 그라데이션.
  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.lerp(accent, Colors.white, 0.18)!, accent],
  );

  /// 금박 테두리 그라데이션.
  LinearGradient get goldGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(gold, Colors.white, 0.45)!,
      gold,
      Color.lerp(gold, Colors.black, 0.25)!,
      Color.lerp(gold, Colors.white, 0.3)!,
    ],
    stops: const [0, 0.38, 0.7, 1],
  );

  static TextStyle _batang({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) => GoogleFonts.gowunBatang(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.15,
  );

  static TextStyle _blackHan({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.blackHanSans(fontSize: size, color: color, height: 1.1);

  static TextStyle _doHyeon({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.doHyeon(fontSize: size, color: color, height: 1.1);

  static TextStyle _jua({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.jua(fontSize: size, color: color, height: 1.15);

  /// 블랙잭: 벨벳 라운지.
  static const lounge = GameTheme(
    id: 'lounge',
    texture: GameTexture.felt,
    dark: true,
    backdrop: [Color(0xFF0B3B33), Color(0xFF0E4A3F), Color(0xFF072823)],
    surface: Color(0xFF0F5446),
    surfaceBorder: Color(0x55E9C77B),
    accent: Color(0xFFD9A441),
    accentSoft: Color(0x33E9C77B),
    gold: Color(0xFFE2BC6A),
    ink: Color(0xFFFDF6E3),
    subInk: Color(0xCCE8DDC4),
    me: Color(0xFF8FE3C6),
    opponent: Color(0xFFF2A7B8),
    displayFont: _batang,
  );

  /// 도둑잡기: 동화책 티파티.
  static const storybook = GameTheme(
    id: 'storybook',
    texture: GameTexture.paper,
    dark: false,
    backdrop: [Color(0xFFFFF8EE), Color(0xFFFBEFE2), Color(0xFFF6E3D3)],
    surface: Color(0xFFFFFCF6),
    surfaceBorder: Color(0x66A8495B),
    accent: Color(0xFF9E3550),
    accentSoft: Color(0x1F9E3550),
    gold: Color(0xFFC79A4B),
    ink: Color(0xFF3B2430),
    subInk: Color(0xFF7D6470),
    me: Color(0xFF7E6BD6),
    opponent: Color(0xFFD0607E),
    displayFont: _batang,
  );

  /// 제로: 스포트라이트 쇼.
  static const showtime = GameTheme(
    id: 'showtime',
    texture: GameTexture.stage,
    dark: true,
    backdrop: [Color(0xFF2A0E2E), Color(0xFF3A1240), Color(0xFF16071A)],
    surface: Color(0xFF3A1A40),
    surfaceBorder: Color(0x55FFC870),
    accent: Color(0xFFFFB347),
    accentSoft: Color(0x33FFB347),
    gold: Color(0xFFF4C46A),
    ink: Color(0xFFFFF4E2),
    subInk: Color(0xCCF1DCC4),
    me: Color(0xFF7FD8FF),
    opponent: Color(0xFFFF8FB1),
    displayFont: _blackHan,
  );

  /// 해적 룰렛: 해적선 야경.
  static const pirateNight = GameTheme(
    id: 'pirate_night',
    texture: GameTexture.deck,
    dark: true,
    backdrop: [Color(0xFF0E1B33), Color(0xFF1B2A44), Color(0xFF3A2416)],
    surface: Color(0xFF4A2E1B),
    surfaceBorder: Color(0x66E0A458),
    accent: Color(0xFFF08A3C),
    accentSoft: Color(0x33F08A3C),
    gold: Color(0xFFD9A65A),
    ink: Color(0xFFFFF1DC),
    subInk: Color(0xCCEAD5B7),
    me: Color(0xFF7FE0C4),
    opponent: Color(0xFFFF9C8A),
    displayFont: _doHyeon,
  );

  /// 패널티킥: 선셋 스타디움(밝은 노을 톤).
  static const sunsetStadium = GameTheme(
    id: 'sunset_stadium',
    texture: GameTexture.stadium,
    dark: false,
    backdrop: [Color(0xFFFFB38A), Color(0xFFFFD3A5), Color(0xFF8FD18B)],
    surface: Color(0xF2FFFFFF),
    surfaceBorder: Color(0x66FF8A65),
    accent: Color(0xFFFF7A59),
    accentSoft: Color(0x26FF7A59),
    gold: Color(0xFFF2B33D),
    ink: Color(0xFF3A2A33),
    subInk: Color(0xFF6E5A63),
    me: Color(0xFF2EC4A6),
    opponent: Color(0xFFFF6F91),
    displayFont: _jua,
  );

  /// 원카드: 자정의 카드 살롱.
  static const salon = GameTheme(
    id: 'salon',
    texture: GameTexture.velvet,
    dark: true,
    backdrop: [Color(0xFF2B1240), Color(0xFF3A1A55), Color(0xFF190A27)],
    surface: Color(0xFF3B1C55),
    surfaceBorder: Color(0x55E8C27A),
    accent: Color(0xFFE8B4FF),
    accentSoft: Color(0x33E8B4FF),
    gold: Color(0xFFE8C27A),
    ink: Color(0xFFFBF3FF),
    subInk: Color(0xCCE6D6F0),
    me: Color(0xFF8FE3C6),
    opponent: Color(0xFFFFA3C4),
    displayFont: _batang,
  );

  static const all = [
    lounge,
    storybook,
    showtime,
    pirateNight,
    sunsetStadium,
    salon,
  ];
}

/// 테마별 깊이 있는 배경(그라데이션 + 질감 + 조명 + 비네트)을 한 레이어로 그린다.
class GameBackdrop extends StatelessWidget {
  final GameTheme theme;
  final Widget child;

  /// 화면 가장자리 금박 테두리. 화면 안에 자체 테두리(테이블 레일 등)가 있으면 끈다.
  final bool frame;

  const GameBackdrop({
    super.key,
    required this.theme,
    required this.child,
    this.frame = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _BackdropPainter(theme, frame: frame)),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final GameTheme theme;
  final bool frame;

  _BackdropPainter(this.theme, {this.frame = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.backdrop,
        ).createShader(rect),
    );
    switch (theme.texture) {
      case GameTexture.felt:
        _felt(canvas, size);
      case GameTexture.paper:
        _paper(canvas, size);
      case GameTexture.stage:
        _stage(canvas, size);
      case GameTexture.deck:
        _deck(canvas, size);
      case GameTexture.stadium:
        _stadium(canvas, size);
      case GameTexture.velvet:
        _velvet(canvas, size);
    }
    // 비네트: 가장자리를 살짝 눌러 시선을 가운데로.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: theme.dark ? 0.42 : 0.10),
          ],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
  }

  void _grain(Canvas canvas, Size size, Color color, int count, int seed) {
    final rnd = math.Random(seed);
    final paint = Paint()..color = color;
    for (int i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 0.9 + 0.2,
        paint,
      );
    }
  }

  void _spotlight(Canvas canvas, Size size, Offset center, double r, Color c) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [c, c.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  void _goldFrame(Canvas canvas, Size size, double inset, double alpha) {
    if (!frame) return;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = theme.gold.withValues(alpha: alpha),
    );
    canvas.drawRRect(
      r.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = theme.gold.withValues(alpha: alpha * 0.55),
    );
  }

  void _felt(Canvas canvas, Size size) {
    _spotlight(
      canvas,
      size,
      Offset(size.width / 2, size.height * 0.42),
      size.longestSide * 0.6,
      const Color(0x3346C6A0),
    );
    _grain(
      canvas,
      size,
      const Color(0x14FFFFFF),
      (size.width * size.height / 900).round(),
      7,
    );
    _goldFrame(canvas, size, 10, 0.5);
  }

  void _paper(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    const blobs = [
      Color(0x22D88FA6),
      Color(0x1F9D83FF),
      Color(0x1AE7B566),
      Color(0x18A8495B),
    ];
    for (int i = 0; i < 7; i++) {
      final c = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      _spotlight(
        canvas,
        size,
        c,
        size.shortestSide * (0.22 + rnd.nextDouble() * 0.25),
        blobs[i % blobs.length],
      );
    }
    _grain(
      canvas,
      size,
      const Color(0x0F5A3A2A),
      (size.width * size.height / 700).round(),
      11,
    );
    // 레이스 테두리: 가장자리에 반원 무늬.
    final lace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = theme.accent.withValues(alpha: 0.22);
    const step = 18.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawArc(
        Rect.fromLTWH(x, -step / 2, step, step),
        0,
        math.pi,
        false,
        lace,
      );
      canvas.drawArc(
        Rect.fromLTWH(x, size.height - step / 2, step, step),
        math.pi,
        math.pi,
        false,
        lace,
      );
    }
    _goldFrame(canvas, size, 14, 0.45);
  }

  void _stage(Canvas canvas, Size size) {
    // 양옆 커튼 주름.
    final curtainW = size.width * 0.13;
    for (final left in [true, false]) {
      final x0 = left ? 0.0 : size.width - curtainW;
      for (int i = 0; i < 5; i++) {
        final w = curtainW / 5;
        final r = Rect.fromLTWH(x0 + i * w, 0, w, size.height);
        canvas.drawRect(
          r,
          Paint()
            ..shader = LinearGradient(
              colors: const [
                Color(0xFF5A1530),
                Color(0xFF8A2346),
                Color(0xFF5A1530),
              ],
            ).createShader(r),
        );
      }
    }
    // 위에서 내려오는 원뿔 조명.
    final path = Path()
      ..moveTo(size.width * 0.44, 0)
      ..lineTo(size.width * 0.56, 0)
      ..lineTo(size.width * 0.86, size.height * 0.9)
      ..lineTo(size.width * 0.14, size.height * 0.9)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x55FFE2A8), const Color(0x00FFE2A8)],
        ).createShader(Offset.zero & size),
    );
    _spotlight(
      canvas,
      size,
      Offset(size.width / 2, size.height * 0.88),
      size.width * 0.42,
      const Color(0x40FFD58A),
    );
    _grain(
      canvas,
      size,
      const Color(0x10FFFFFF),
      (size.width * size.height / 1400).round(),
      5,
    );
  }

  void _deck(Canvas canvas, Size size) {
    // 밤하늘 별.
    final rnd = math.Random(17);
    final star = Paint()..color = const Color(0xCCFFF6D8);
    for (int i = 0; i < 46; i++) {
      canvas.drawCircle(
        Offset(
          rnd.nextDouble() * size.width,
          rnd.nextDouble() * size.height * 0.45,
        ),
        rnd.nextDouble() * 1.1 + 0.3,
        star
          ..color = Color.fromRGBO(255, 246, 216, 0.3 + rnd.nextDouble() * 0.6),
      );
    }
    // 갑판 널빤지.
    final deckTop = size.height * 0.56;
    final plankH = 26.0;
    for (double y = deckTop; y < size.height; y += plankH) {
      final r = Rect.fromLTWH(0, y, size.width, plankH - 1.5);
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF6B4226), Color(0xFF55331D)],
          ).createShader(r),
      );
      final grain = Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 0.8;
      for (int k = 0; k < 3; k++) {
        final gy = y + 6 + k * 6 + rnd.nextDouble() * 2;
        canvas.drawLine(
          Offset(0, gy),
          Offset(size.width, gy + rnd.nextDouble() * 2),
          grain,
        );
      }
    }
    // 랜턴 빛.
    _spotlight(
      canvas,
      size,
      Offset(size.width * 0.18, size.height * 0.5),
      size.width * 0.5,
      const Color(0x55FF9A3C),
    );
    _spotlight(
      canvas,
      size,
      Offset(size.width * 0.84, size.height * 0.46),
      size.width * 0.42,
      const Color(0x40FFB45C),
    );
  }

  void _stadium(Canvas canvas, Size size) {
    // 관중석 보케.
    final rnd = math.Random(23);
    const bokeh = [
      Color(0x55FFFFFF),
      Color(0x44FFE08A),
      Color(0x40FF9FB3),
      Color(0x3398E1FF),
    ];
    for (int i = 0; i < 40; i++) {
      final c = Offset(
        rnd.nextDouble() * size.width,
        size.height * (0.18 + rnd.nextDouble() * 0.2),
      );
      canvas.drawCircle(
        c,
        3 + rnd.nextDouble() * 7,
        Paint()..color = bokeh[i % bokeh.length],
      );
    }
    // 노을 해.
    _spotlight(
      canvas,
      size,
      Offset(size.width * 0.78, size.height * 0.12),
      size.width * 0.35,
      const Color(0x88FFF1C1),
    );
    // 잔디 줄무늬.
    final grassTop = size.height * 0.46;
    final stripes = 9;
    for (int i = 0; i < stripes; i++) {
      final y0 = grassTop + (size.height - grassTop) * i / stripes;
      final y1 = grassTop + (size.height - grassTop) * (i + 1) / stripes;
      canvas.drawRect(
        Rect.fromLTRB(0, y0, size.width, y1),
        Paint()
          ..color = i.isEven
              ? const Color(0xFF7CCB7A)
              : const Color(0xFF6FBF6E),
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(0, grassTop, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0x55FFD3A5), Color(0x00FFD3A5)],
        ).createShader(Rect.fromLTRB(0, grassTop, size.width, size.height)),
    );
  }

  void _velvet(Canvas canvas, Size size) {
    _spotlight(
      canvas,
      size,
      Offset(size.width / 2, size.height * 0.45),
      size.longestSide * 0.55,
      const Color(0x337B3FA8),
    );
    // 은은한 다이아몬드 무늬.
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0x12FFFFFF);
    const s = 34.0;
    for (double y = -s; y < size.height + s; y += s) {
      for (
        double x = (y / s).round().isEven ? 0 : s / 2;
        x < size.width + s;
        x += s
      ) {
        final path = Path()
          ..moveTo(x, y - s / 2)
          ..lineTo(x + s / 2, y)
          ..lineTo(x, y + s / 2)
          ..lineTo(x - s / 2, y)
          ..close();
        canvas.drawPath(path, p);
      }
    }
    _grain(
      canvas,
      size,
      const Color(0x0EFFFFFF),
      (size.width * size.height / 1100).round(),
      13,
    );
    _goldFrame(canvas, size, 10, 0.45);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.theme.id != theme.id || oldDelegate.frame != frame;
}
