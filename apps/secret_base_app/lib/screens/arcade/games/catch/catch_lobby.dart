import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../lobby_kit.dart';
import '../../lobby_options.dart';

/// 그림 맞히기 대기실의 색·서체(스케치북 아틀리에: 크림 종이 + 파란 테두리 + 코랄). 게임 화면의 atelier와 같은 계열이다.
final kCatchLobbyPalette = LobbyPalette(
  dark: false,
  bg: const Color(0xFFF7F2E6),
  panel: const Color(0xFFFFFDF7),
  line: const Color(0x2E2A2B3D),
  ink: const Color(0xFF2A2B3D),
  sub: const Color(0xFF65647A),
  accent: const Color(0xFF2B5FD6),
  accentInk: Colors.white,
  me: const Color(0xFF2B5FD6),
  meInk: Colors.white,
  opp: const Color(0xFFE2625A),
  oppInk: Colors.white,
  ok: const Color(0xFF2B5FD6),
  shadow: const [
    BoxShadow(color: Color(0x142A2B3D), blurRadius: 14, offset: Offset(0, 4)),
  ],
  ui: (size, {color, weight, height, spacing = 0}) => lobbyNoto(
    size,
    color: color ?? const Color(0xFF2A2B3D),
    weight: weight,
    height: height,
    spacing: spacing,
  ),
  display: (size, {color, weight, height, spacing = 0}) =>
      GoogleFonts.gowunDodum(
        fontSize: size,
        color: color ?? const Color(0xFF2A2B3D),
        fontWeight: FontWeight.w400,
        height: height ?? 1.2,
        letterSpacing: spacing * size,
      ),
);

/// 그림 맞히기 대기실: 스프링 스케치북 위의 그림, 라운드 수 고르기(방장만), 두 사람, 규칙.
/// 로비 동작(방장이 라운드 수를 고르고 상대는 읽기만, 방장만 시작)은 [GameLobbyScreen]이
/// 그대로 맡고 이 위젯은 그리기만 한다.
class CatchLobbyView extends StatelessWidget {
  /// 로비 옵션 정의(라운드 수 6/4/8)와 지금 고른 값.
  final LobbyOptionDef roundsDef;
  final Object? roundsValue;

  final List<String> players;
  final String? host;
  final String? me;
  final Map<String, String> nicknames;
  final bool isHost;
  final bool canStart;
  final String startLabel;

  final ValueChanged<int> onRounds;
  final VoidCallback? onStart;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  const CatchLobbyView({
    super.key,
    required this.roundsDef,
    required this.roundsValue,
    required this.players,
    required this.host,
    required this.me,
    required this.nicknames,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onRounds,
    required this.onStart,
    required this.onBack,
    this.onHelp,
  });

  static const _names = {4: '짧게', 6: '보통', 8: '길게'};

  static const _rules = [
    ('시간', '한 라운드 60초, 번갈아 그려요'),
    ('점수', '맞히면 3점, 그린 사람은 2점'),
    ('힌트', '30초·15초가 남으면 글자가 하나씩 열려요'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = kCatchLobbyPalette;
    final current = roundsDef.choiceFor(roundsValue);
    final seats = LobbySeats.resolve(
      players: players,
      host: host,
      me: me,
      nicknames: nicknames,
      ready: const {},
    );
    final choices = [...roundsDef.choices]
      ..sort((a, b) => (a.value as int).compareTo(b.value as int));

    return LobbyScaffold(
      palette: p,
      backdrop: (child) => ColoredBox(color: p.bg, child: child),
      title: '그림 맞히기',
      onBack: onBack,
      onHelp: onHelp,
      body: (context, compact) => Column(
        children: [
          SizedBox(height: compact ? 8 : 18),
          _Sketchbook(compact: compact),
          SizedBox(height: compact ? 14 : 24),
          Text(
            '번갈아 그리고,\n그림으로 맞혀요',
            textAlign: TextAlign.center,
            style: p.ui(
              compact ? 22 : 26,
              weight: FontWeight.w700,
              height: 1.3,
              spacing: -0.02,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '한 사람이 제시어를 그리면 상대가 60초 안에 맞혀요.',
            textAlign: TextAlign.center,
            style: p.ui(14, color: p.sub, weight: FontWeight.w400, height: 1.5),
          ),
          SizedBox(height: compact ? 16 : 24),
          LobbySeatRow(palette: p, seats: seats),
          if (players.length < 2) ...[
            const SizedBox(height: 10),
            Text(
              '먼저 들어온 사람이 방장이 됩니다',
              textAlign: TextAlign.center,
              style: p.ui(12, color: p.sub, weight: FontWeight.w400),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: p.card(radius: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: LobbySectionHead(
                    palette: p,
                    title: roundsDef.title,
                    hint: lobbyOptionHint(isHost: isHost),
                    padding: const EdgeInsets.only(bottom: 12),
                  ),
                ),
                Row(
                  children: [
                    for (final choice in choices) ...[
                      if (choice != choices.first) const SizedBox(width: 8),
                      Expanded(
                        child: _RoundsOption(
                          choice: choice,
                          name: _names[choice.value] ?? choice.label,
                          selected: choice.value == current.value,
                          enabled: isHost,
                          onTap: () => onRounds(choice.value as int),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    current.description,
                    style: p.ui(
                      13,
                      color: p.sub,
                      weight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LobbySectionHead(palette: p, title: '규칙'),
          LobbyRuleRows(palette: p, rows: _rules),
        ],
      ),
      bottom: isHost
          ? LobbyMainButton(
              palette: p,
              label: startLabel,
              onPressed: canStart ? onStart : null,
            )
          : LobbyMainButton(palette: p, label: kLobbyGuestWaitLabel),
    );
  }
}

/// 라운드 수 한 칸: 큰 숫자 + 이름. 고른 칸은 파란 단색.
class _RoundsOption extends StatelessWidget {
  final LobbyChoice choice;
  final String name;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RoundsOption({
    required this.choice,
    required this.name,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = kCatchLobbyPalette;
    final fg = selected ? p.accentInk : p.ink;
    return LobbyTapTarget(
      label: '${choice.value}라운드, $name, ${choice.description}',
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 76,
        decoration: BoxDecoration(
          color: selected ? p.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${choice.value}',
              style: p.display(27, color: fg, height: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: p.ui(
                13,
                color: selected ? p.accentInk : p.sub,
                weight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 윗변에 스프링이 걸린 파란 테두리 스케치북과 그 위의 낙서(여행 가방).
class _Sketchbook extends StatelessWidget {
  final bool compact;

  const _Sketchbook({required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = kCatchLobbyPalette;
    final w = compact ? 168.0 : 228.0;
    final h = compact ? 112.0 : 152.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: w,
        height: h + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 8,
              height: h,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.accent, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F2A2B3D),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: CustomPaint(painter: const _SuitcasePainter()),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 0,
              height: 16,
              child: const CustomPaint(painter: _SpringPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

/// 윗변의 스프링 고리(가는 선 열네 개).
class _SpringPainter extends CustomPainter {
  const _SpringPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8A8FA8)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const n = 15;
    for (var i = 0; i < n; i++) {
      final x = size.width * (i + 0.5) / n;
      canvas.drawLine(Offset(x, 1), Offset(x, 13), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 손으로 그린 듯한 여행 가방 낙서(잉크 선 + 파란 띠, 코랄 별, 노란 동그라미).
class _SuitcasePainter extends CustomPainter {
  const _SuitcasePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const ink = Color(0xFF2A2B3D);
    const blue = Color(0xFF2B5FD6);
    const coral = Color(0xFFE2625A);
    const yellow = Color(0xFFE6B93B);
    const violet = Color(0xFF7B5FD6);
    // 120 x 110 좌표계에 그려 가운데 맞춤.
    const ux = 120.0, uy = 110.0;
    final s = (size.width / ux) < (size.height / uy)
        ? size.width / ux
        : size.height / uy;
    canvas.save();
    canvas.translate((size.width - ux * s) / 2, (size.height - uy * s) / 2);
    canvas.scale(s);

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 파란 띠 두 줄(몸통 뒤).
    canvas.drawLine(
      const Offset(44, 34),
      const Offset(44, 86),
      stroke(blue, 4),
    );
    canvas.drawLine(
      const Offset(80, 34),
      const Offset(80, 86),
      stroke(blue, 4),
    );
    // 몸통.
    final body = Path()
      ..moveTo(24, 33)
      ..quadraticBezierTo(60, 31, 97, 34)
      ..lineTo(99, 86)
      ..quadraticBezierTo(60, 89, 23, 86)
      ..close();
    canvas.drawPath(body, stroke(ink, 3));
    // 손잡이.
    final handle = Path()
      ..moveTo(47, 33)
      ..lineTo(47, 19)
      ..quadraticBezierTo(60, 14, 73, 19)
      ..lineTo(73, 33);
    canvas.drawPath(handle, stroke(ink, 3));
    // 장식.
    canvas.drawCircle(const Offset(62, 62), 6, stroke(yellow, 2.6));
    canvas.drawArc(
      const Rect.fromLTWH(26, 44, 12, 8),
      3.5,
      2.4,
      false,
      stroke(violet, 2.4),
    );
    final star = Path();
    const cx = 90.0, cy = 50.0;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 9.0 : 4.0;
      final a = -1.5708 + i * 0.62832;
      final pt = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    star.close();
    canvas.drawPath(star, stroke(coral, 2.4));
    // 바퀴.
    for (final x in const [32.0, 90.0]) {
      canvas.drawCircle(
        Offset(x, 94),
        5,
        Paint()..color = const Color(0xFFFFFDF7),
      );
      canvas.drawCircle(Offset(x, 94), 5, stroke(ink, 3));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
