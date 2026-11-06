import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 게임 화면의 바탕 질감.
enum GameTexture {
  felt,
  paper,
  stage,
  deck,
  stadium,
  velvet,
  starlight,
  yutDay,
  yutNight,
  table,
  atelier,
}

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

  static TextStyle _jua({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.jua(fontSize: size, color: color, height: 1.12);

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

  /// 패널티킥: 나이트 스타디움(조명탑 아래 TV 중계 톤). id·이름은 예전 그대로 둔다.
  static const sunsetStadium = GameTheme(
    id: 'sunset_stadium',
    texture: GameTexture.stadium,
    dark: true,
    backdrop: [Color(0xFF040917), Color(0xFF0A1630), Color(0xFF061A12)],
    surface: Color(0xFF0F1A31),
    surfaceBorder: Color(0x33B8C8E6),
    accent: Color(0xFFC8F53A),
    accentSoft: Color(0x29C8F53A),
    gold: Color(0xFFDCE4F2),
    ink: Color(0xFFF3F6FC),
    subInk: Color(0xB3C3CDE0),
    me: Color(0xFF3D9BFF),
    opponent: Color(0xFFFF4D5E),
    displayFont: _blackHan,
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

  /// 텔레파시: 별빛 편지(밤하늘 남보라 + 별가루).
  static const starlight = GameTheme(
    id: 'starlight',
    texture: GameTexture.starlight,
    dark: true,
    backdrop: [Color(0xFF0C0B2E), Color(0xFF1B1950), Color(0xFF0A0A24)],
    surface: Color(0xFF1F1D57),
    surfaceBorder: Color(0x55CDBEFF),
    accent: Color(0xFFFFB6D5),
    accentSoft: Color(0x33FFB6D5),
    gold: Color(0xFFF6D98E),
    ink: Color(0xFFF6F3FF),
    subInk: Color(0xCCCFCAF2),
    me: Color(0xFF8FD6FF),
    opponent: Color(0xFFFFA9CB),
    displayFont: _batang,
  );

  /// 윷놀이 낮: 맑은 하늘과 구름, 멀리 민트빛 언덕. 주황 포인트.
  static const yutDay = GameTheme(
    id: 'yut_day',
    texture: GameTexture.yutDay,
    dark: false,
    backdrop: [Color(0xFF8FD0F5), Color(0xFFD3EEF9), Color(0xFF8FD1B1)],
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x4D6E8CB9),
    accent: Color(0xFFFF7043),
    accentSoft: Color(0x26FF7043),
    gold: Color(0xFFFFD35A),
    ink: Color(0xFF26325A),
    subInk: Color(0xFF6B7899),
    me: Color(0xFFFF7043),
    opponent: Color(0xFF3F8CFF),
    displayFont: _doHyeon,
  );

  /// 윷놀이 밤: 달빛 아래 남색 마당, 등불빛과 별. 호박색 포인트.
  static const yutNight = GameTheme(
    id: 'yut_night',
    texture: GameTexture.yutNight,
    dark: true,
    backdrop: [Color(0xFF141646), Color(0xFF22236E), Color(0xFF0F1033)],
    surface: Color(0xFF2C2F75),
    surfaceBorder: Color(0x29FFFFFF),
    accent: Color(0xFFFFB347),
    accentSoft: Color(0x26FFB347),
    gold: Color(0xFFFFC266),
    ink: Color(0xFFF3EEFF),
    subInk: Color(0xFFABA9DC),
    me: Color(0xFFFFB347),
    opponent: Color(0xFF8FA8FF),
    displayFont: _doHyeon,
  );

  /// 고스톱: 초록 펠트 판(화투 상). 깊은 초록 위에 올이 보이는 천 질감과 따뜻한 금빛 조명.
  static const felt = GameTheme(
    id: 'felt',
    texture: GameTexture.table,
    dark: true,
    backdrop: [Color(0xFF0F4A2A), Color(0xFF14602F), Color(0xFF0A3A20)],
    surface: Color(0xFF0E4025),
    surfaceBorder: Color(0x66E8C97A),
    accent: Color(0xFFE0A93B),
    accentSoft: Color(0x33E0A93B),
    gold: Color(0xFFEBC66F),
    ink: Color(0xFFFDF6E3),
    subInk: Color(0xCCDDE8CC),
    me: Color(0xFF9BE8B7),
    opponent: Color(0xFFF4A9A0),
    displayFont: _batang,
  );

  /// 그림 맞히기: 아틀리에 스케치북(리넨 벽 위에 크림 종이와 파란 테두리).
  static const atelier = GameTheme(
    id: 'atelier',
    texture: GameTexture.atelier,
    dark: false,
    backdrop: [Color(0xFFF4ECDD), Color(0xFFEBE0CB), Color(0xFFDFD1B8)],
    surface: Color(0xFFFFFAEE),
    surfaceBorder: Color(0x662B5FD6),
    accent: Color(0xFF2B5FD6),
    accentSoft: Color(0x1F2B5FD6),
    gold: Color(0xFFB98B3A),
    ink: Color(0xFF2A2B3D),
    subInk: Color(0xFF6B6A7C),
    me: Color(0xFF2B5FD6),
    opponent: Color(0xFFE2625A),
    displayFont: _jua,
  );

  static const all = [
    lounge,
    storybook,
    showtime,
    pirateNight,
    sunsetStadium,
    salon,
    starlight,
    yutDay,
    yutNight,
    felt,
    atelier,
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
      case GameTexture.starlight:
        _starlight(canvas, size);
      case GameTexture.yutDay:
        _yutDay(canvas, size);
      case GameTexture.yutNight:
        _yutNight(canvas, size);
      case GameTexture.table:
        _table(canvas, size);
      case GameTexture.atelier:
        _atelier(canvas, size);
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
    final w = size.width;
    final h = size.height;
    // 관중석: 어두운 계단식 층 + 작은 관중 불빛(휴대폰·플래시).
    final standTop = h * 0.07;
    final standBottom = h * 0.42;
    const tiers = 7;
    for (int i = 0; i < tiers; i++) {
      final y0 = standTop + (standBottom - standTop) * i / tiers;
      final y1 = standTop + (standBottom - standTop) * (i + 1) / tiers;
      canvas.drawRect(
        Rect.fromLTRB(0, y0, w, y1),
        Paint()
          ..color =
              (i.isEven ? const Color(0xFF0C1630) : const Color(0xFF0A1329))
                  .withValues(alpha: 0.85),
      );
      canvas.drawLine(
        Offset(0, y1),
        Offset(w, y1),
        Paint()
          ..strokeWidth = 0.6
          ..color = const Color(0x1AFFFFFF),
      );
    }
    final rnd = math.Random(23);
    final crowd = (w * (standBottom - standTop) / 160).round();
    for (int i = 0; i < crowd; i++) {
      final x = rnd.nextDouble() * w;
      final y = standTop + rnd.nextDouble() * (standBottom - standTop);
      final k = rnd.nextDouble();
      final Color c;
      if (k > 0.94) {
        c = const Color(0xCCFFFFFF);
      } else if (k > 0.8) {
        c = (x < w / 2 ? theme.me : theme.opponent).withValues(alpha: 0.45);
      } else {
        c = const Color(0x22C8D6F0);
      }
      canvas.drawCircle(
        Offset(x, y),
        0.6 + rnd.nextDouble() * 0.9,
        Paint()..color = c,
      );
    }
    // 지붕 그늘.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, standTop + 6),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF02050D), Color(0x0002050D)],
        ).createShader(Rect.fromLTRB(0, 0, w, standTop + 6)),
    );
    // 잔디: 어둡게 깎인 줄무늬(원근으로 아래로 갈수록 넓게).
    final grassTop = h * 0.5;
    const stripes = 10;
    for (int i = 0; i < stripes; i++) {
      double f(int k) => math.pow(k / stripes, 1.5).toDouble();
      final y0 = grassTop + (h - grassTop) * f(i);
      final y1 = grassTop + (h - grassTop) * f(i + 1);
      canvas.drawRect(
        Rect.fromLTRB(0, y0, w, y1 + 0.5),
        Paint()
          ..color = i.isEven
              ? const Color(0xFF0D3321)
              : const Color(0xFF0B2B1C),
      );
    }
    final grass = Rect.fromLTRB(0, grassTop, w, h);
    canvas.drawRect(
      grass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1630), Color(0x000A1630), Color(0x66030A08)],
          stops: [0, 0.35, 1],
        ).createShader(grass),
    );
    // 조명탑 빛 번짐 + 가로 렌즈 플레어 + 아래로 떨어지는 빛줄기.
    for (final left in [true, false]) {
      final c = Offset(left ? w * 0.06 : w * 0.94, h * 0.035);
      final beam = Path()
        ..moveTo(c.dx - 10, c.dy)
        ..lineTo(c.dx + 10, c.dy)
        ..lineTo(left ? w * 0.78 : w * 0.22, h * 0.95)
        ..lineTo(left ? w * 0.38 : w * 0.62, h * 0.95)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0x1FCFE2FF), Color(0x00CFE2FF)],
          ).createShader(Offset.zero & size),
      );
      _spotlight(canvas, size, c, w * 0.55, const Color(0x40BFD6FF));
      _spotlight(canvas, size, c, w * 0.16, const Color(0x99E8F1FF));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, 0.035);
      _spotlight(canvas, size, Offset.zero, w * 0.7, const Color(0x55D8E6FF));
      canvas.restore();
      canvas.drawCircle(c, 3.2, Paint()..color = Colors.white);
    }
    _grain(canvas, size, const Color(0x0CFFFFFF), (w * h / 1600).round(), 29);
  }

  void _table(Canvas canvas, Size size) {
    _spotlight(
      canvas,
      size,
      Offset(size.width / 2, size.height * 0.46),
      size.longestSide * 0.62,
      const Color(0x4458D68F),
    );
    // 천의 올: 가로·세로로 아주 옅은 선을 촘촘히.
    final weave = Paint()
      ..strokeWidth = 0.5
      ..color = const Color(0x0DFFFFFF);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weave);
    }
    final warp = Paint()
      ..strokeWidth = 0.5
      ..color = const Color(0x0A000000);
    for (double x = 0; x < size.width; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), warp);
    }
    _grain(
      canvas,
      size,
      const Color(0x10FFFFFF),
      (size.width * size.height / 1000).round(),
      19,
    );
    // 판 가장자리 레일: 어두운 나무 테를 안쪽으로 한 겹.
    final rail = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(26),
    );
    canvas.drawRRect(
      rail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = const Color(0xCC2A170C),
    );
    canvas.drawRRect(
      rail.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.gold.withValues(alpha: 0.45),
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

  void _starlight(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 성운: 보라·파랑·장밋빛 안개.
    _spotlight(
      canvas,
      size,
      Offset(w * 0.18, h * 0.16),
      w * 0.75,
      const Color(0x4D5B3FC4),
    );
    _spotlight(
      canvas,
      size,
      Offset(w * 0.9, h * 0.52),
      w * 0.7,
      const Color(0x3A2F67D8),
    );
    _spotlight(
      canvas,
      size,
      Offset(w * 0.45, h * 1.02),
      w * 0.8,
      const Color(0x33C0508F),
    );
    // 은하수: 대각선 띠를 따라 촘촘한 별가루.
    final rnd = math.Random(41);
    final dust = Paint();
    final band = (w * h / 260).round();
    for (int i = 0; i < band; i++) {
      final t = rnd.nextDouble();
      final spread = (rnd.nextDouble() + rnd.nextDouble() - 1) * h * 0.11;
      final x = -w * 0.1 + t * w * 1.2;
      final y = h * 0.7 - t * h * 0.55 + spread;
      dust.color = Color.fromRGBO(
        225,
        215,
        255,
        0.08 + rnd.nextDouble() * 0.22,
      );
      canvas.drawCircle(Offset(x, y), 0.3 + rnd.nextDouble() * 0.7, dust);
    }
    // 흩어진 별.
    final stars = (w * h / 1500).round();
    for (int i = 0; i < stars; i++) {
      final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final r = 0.35 + math.pow(rnd.nextDouble(), 3).toDouble() * 1.5;
      final warm = rnd.nextDouble() > 0.82;
      dust.color = (warm ? const Color(0xFFFFE9B8) : const Color(0xFFF2EEFF))
          .withValues(alpha: 0.35 + rnd.nextDouble() * 0.6);
      canvas.drawCircle(c, r, dust);
    }
    // 반짝이는 큰 별 몇 개: 십자 빛 + 번짐.
    for (int i = 0; i < 9; i++) {
      final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.92);
      final len = 4.0 + rnd.nextDouble() * 6;
      _spotlight(canvas, size, c, len * 2.4, const Color(0x55F6D98E));
      final ray = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCFFF4D6);
      canvas.drawLine(c.translate(-len, 0), c.translate(len, 0), ray);
      canvas.drawLine(c.translate(0, -len), c.translate(0, len), ray);
      canvas.drawCircle(c, 1.3, Paint()..color = Colors.white);
    }
    _goldFrame(canvas, size, 10, 0.32);
  }

  /// 윷놀이 낮: 햇살, 구름, 멀리 보이는 민트빛 언덕.
  void _yutDay(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _spotlight(
      canvas,
      size,
      Offset(w * 0.82, h * 0.05),
      math.max(w, h) * 0.5,
      const Color(0x66FFF8D8),
    );
    void cloud(double cx, double cy, double sc, double alpha) {
      final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: sc * 3.4, height: sc),
          Radius.circular(sc / 2),
        ),
        paint,
      );
      canvas.drawCircle(
        Offset(cx - sc * 0.5, cy - sc * 0.35),
        sc * 0.55,
        paint,
      );
      canvas.drawCircle(Offset(cx + sc * 0.35, cy - sc * 0.5), sc * 0.7, paint);
    }

    cloud(w * 0.2, h * 0.16, w * 0.09, 0.85);
    cloud(w * 0.78, h * 0.1, w * 0.07, 0.7);
    cloud(w * 0.52, h * 0.3, w * 0.05, 0.55);
    cloud(w * 0.9, h * 0.52, w * 0.06, 0.5);
    for (final layer in [
      (0.74, 0.1, const Color(0x669FD8C0)),
      (0.82, 0.07, const Color(0xCC8FD1B1)),
    ]) {
      final base = h * layer.$1;
      final path = Path()
        ..moveTo(0, h)
        ..lineTo(0, base);
      for (double x = 0; x <= w; x += w / 4) {
        path.quadraticBezierTo(x + w / 8, base - h * layer.$2, x + w / 4, base);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = layer.$3);
    }
  }

  /// 윷놀이 밤: 별, 달빛, 왼쪽 위 등불빛, 어두운 언덕.
  void _yutNight(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _spotlight(
      canvas,
      size,
      Offset(w * 0.82, h * 0.03),
      math.max(w, h) * 0.45,
      const Color(0x44FFE6B0),
    );
    // 등불빛.
    _spotlight(
      canvas,
      size,
      Offset(w * 0.1, h * 0.17),
      w * 0.34,
      const Color(0x55FFB347),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.1, h * 0.17),
          width: w * 0.045,
          height: w * 0.075,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFFB347),
    );
    final rnd = math.Random(8);
    for (int i = 0; i < 54; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.55),
        0.5 + rnd.nextDouble() * 1.2,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.25 + rnd.nextDouble() * 0.6,
          ),
      );
    }
    for (final layer in [
      (0.76, 0.08, const Color(0x55262770)),
      (0.84, 0.06, const Color(0xAA10113A)),
    ]) {
      final base = h * layer.$1;
      final path = Path()
        ..moveTo(0, h)
        ..lineTo(0, base);
      for (double x = 0; x <= w; x += w / 4) {
        path.quadraticBezierTo(x + w / 8, base - h * layer.$2, x + w / 4, base);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = layer.$3);
    }
  }

  void _atelier(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 위쪽 창가에서 들어오는 따뜻한 빛.
    _spotlight(
      canvas,
      size,
      Offset(w * 0.5, h * 0.1),
      math.max(w, h) * 0.7,
      const Color(0x66FFF6DC),
    );
    // 리넨 직조 무늬: 가는 가로·세로선.
    final weave = Paint()
      ..strokeWidth = 0.5
      ..color = const Color(0x0F6B5A3C);
    for (double y = 0; y < h; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(w, y), weave);
    }
    for (double x = 0; x < w; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), weave);
    }
    // 가장자리에 흩어진 연필 낙서(별·하트·물결). 판 뒤라서 아주 옅게.
    final rnd = math.Random(41);
    final doodle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = theme.accent.withValues(alpha: 0.10);
    for (int i = 0; i < 16; i++) {
      final left = i.isEven;
      final cx = left
          ? rnd.nextDouble() * w * 0.12 + 8
          : w - rnd.nextDouble() * w * 0.12 - 8;
      final cy = (i / 16) * h + rnd.nextDouble() * 24;
      final r = 6 + rnd.nextDouble() * 8;
      switch (i % 4) {
        case 0:
          final p = Path();
          for (int k = 0; k < 10; k++) {
            final a = -math.pi / 2 + k * math.pi / 5;
            final rr = k.isEven ? r : r * 0.45;
            final o = Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr);
            k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
          }
          canvas.drawPath(p..close(), doodle);
        case 1:
          final p = Path()
            ..moveTo(cx, cy + r * 0.9)
            ..cubicTo(
              cx - r * 1.6,
              cy - r * 0.2,
              cx - r * 0.5,
              cy - r * 1.1,
              cx,
              cy - r * 0.2,
            )
            ..cubicTo(
              cx + r * 0.5,
              cy - r * 1.1,
              cx + r * 1.6,
              cy - r * 0.2,
              cx,
              cy + r * 0.9,
            );
          canvas.drawPath(p, doodle);
        case 2:
          final p = Path()..moveTo(cx - r * 1.3, cy);
          for (int k = 0; k < 3; k++) {
            p.relativeQuadraticBezierTo(r * 0.4, -r * 0.8, r * 0.8, 0);
            p.relativeQuadraticBezierTo(r * 0.4, r * 0.8, r * 0.8, 0);
          }
          canvas.drawPath(p, doodle);
        default:
          canvas.drawCircle(Offset(cx, cy), r * 0.7, doodle);
          canvas.drawLine(
            Offset(cx - r, cy + r),
            Offset(cx + r, cy - r),
            doodle,
          );
      }
    }
    // 아래쪽 책상 나무결이 살짝 보이는 띠.
    final desk = Rect.fromLTRB(0, h - 14, w, h);
    canvas.drawRect(
      desk,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00B58B5A), Color(0x33B58B5A)],
        ).createShader(desk),
    );
    _grain(canvas, size, const Color(0x0C5A3A2A), (w * h / 1500).round(), 43);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.theme.id != theme.id || oldDelegate.frame != frame;
}
