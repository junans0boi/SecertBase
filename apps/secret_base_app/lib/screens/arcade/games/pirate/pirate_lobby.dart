import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../lobby_kit.dart';
import '../../lobby_options.dart';
import 'pirate_barrel.dart';
import 'pirate_controller.dart';

/// 해적 룰렛 대기실의 색·서체(밤바다: 짙은 남색 + 호박색 + 청록). 게임 화면의 pirateNight와 같은 계열이다.
final kPirateLobbyPalette = LobbyPalette(
  dark: true,
  bg: const Color(0xFF0A1426),
  panel: const Color(0x0FFFFFFF),
  line: const Color(0x26FFFFFF),
  ink: const Color(0xFFF4ECDD),
  sub: const Color(0xFF9CA8BA),
  accent: const Color(0xFFF0A24E),
  accentInk: const Color(0xFF1F1204),
  me: const Color(0xFFF0A24E),
  meInk: const Color(0xFF1F1204),
  opp: const Color(0xFF5FC4BE),
  oppInk: const Color(0xFF06201E),
  ok: const Color(0xFFF0A24E),
  ui: (size, {color, weight, height, spacing = 0}) => lobbyNoto(
    size,
    color: color ?? const Color(0xFFF4ECDD),
    weight: weight,
    height: height,
    spacing: spacing,
  ),
  display: (size, {color, weight, height, spacing = 0}) => GoogleFonts.doHyeon(
    fontSize: size,
    color: color ?? const Color(0xFFF4ECDD),
    height: height ?? 1.15,
    letterSpacing: spacing * size,
  ),
);

/// 해적 룰렛 대기실: 밤바다 위의 통, 구멍 수 고르기(방장만), 두 사람, 규칙.
/// 로비 동작(방장이 구멍 수를 고르고 상대는 읽기만, 방장만 시작)은 [GameLobbyScreen]이
/// 그대로 맡고 이 위젯은 그리기만 한다.
class PirateLobbyView extends StatelessWidget {
  /// 로비 옵션 정의(구멍 수 6/8/12)와 지금 고른 값.
  final LobbyOptionDef holesDef;
  final Object? holesValue;

  final List<String> players;
  final String? host;
  final String? me;
  final Map<String, String> nicknames;
  final bool isHost;
  final bool canStart;
  final String startLabel;

  final ValueChanged<int> onHoles;
  final VoidCallback? onStart;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  const PirateLobbyView({
    super.key,
    required this.holesDef,
    required this.holesValue,
    required this.players,
    required this.host,
    required this.me,
    required this.nicknames,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onHoles,
    required this.onStart,
    required this.onBack,
    this.onHelp,
  });

  static const _names = {6: '짧게', 8: '보통', 12: '길게'};

  static const _rules = [
    ('차례', '번갈아 한 구멍씩 칼을 꽂아요 · 20초'),
    ('패배', '폭탄 구멍을 찌른 사람이 져요'),
    ('벌칙', '이긴 사람이 벌칙을 정해요'),
  ];

  static int riskPct(int holes) => (100 / holes).round();

  @override
  Widget build(BuildContext context) {
    final p = kPirateLobbyPalette;
    final current = holesDef.choiceFor(holesValue).value as int;
    final seats = LobbySeats.resolve(
      players: players,
      host: host,
      me: me,
      nicknames: nicknames,
      ready: const {},
    );
    final choices = [...holesDef.choices]
      ..sort((a, b) => (a.value as int).compareTo(b.value as int));

    return LobbyScaffold(
      palette: p,
      backdrop: (child) => _NightBackdrop(child: child),
      title: '해적 룰렛',
      onBack: onBack,
      onHelp: onHelp,
      body: (context, compact) => Column(
        children: [
          SizedBox(height: compact ? 0 : 8),
          _Hero(holes: current, compact: compact),
          SizedBox(height: compact ? 10 : 14),
          Text(
            isHost ? '${holesDef.title}를 골라요' : '방장이 ${holesDef.title}를 골랐어요',
            textAlign: TextAlign.center,
            style: p.display(compact ? 22 : 25),
          ),
          const SizedBox(height: 4),
          Text(
            isHost ? '고르면 상대 화면에도 바로 보여요' : '방장만 바꿀 수 있어요',
            textAlign: TextAlign.center,
            style: p.ui(13, color: p.sub, weight: FontWeight.w400),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final choice in choices) ...[
                  if (choice != choices.first) const SizedBox(width: 10),
                  Expanded(
                    child: _HolesOption(
                      holes: choice.value as int,
                      fallbackLabel: choice.label,
                      selected: choice.value == current,
                      enabled: isHost,
                      onTap: () => onHoles(choice.value as int),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          LobbySeatRow(palette: p, seats: seats),
          if (players.length < 2) ...[
            const SizedBox(height: 10),
            Text(
              '먼저 들어온 사람이 방장이 됩니다',
              textAlign: TextAlign.center,
              style: p.ui(12, color: p.sub, weight: FontWeight.w400),
            ),
          ],
          const SizedBox(height: 22),
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

/// 구멍 수 한 장: 구멍 점 그림 + 큰 숫자 + 이름 + 첫 폭탄 확률.
class _HolesOption extends StatelessWidget {
  final int holes;
  final String fallbackLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _HolesOption({
    required this.holes,
    required this.fallbackLabel,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = kPirateLobbyPalette;
    final name = PirateLobbyView._names[holes] ?? fallbackLabel;
    final risk = PirateLobbyView.riskPct(holes);
    final rows = BarrelGeometry(1, holes).rows;
    final dot = selected ? p.accent : p.sub.withValues(alpha: 0.7);
    return LobbyTapTarget(
      label: '$holes구멍, $name, 첫 폭탄 확률 $risk%',
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(minHeight: 148),
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        decoration: BoxDecoration(
          color: selected ? p.accentWash : p.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? p.accent : p.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var r = 0; r < rows.length; r++)
              Padding(
                padding: EdgeInsets.only(top: r == 0 ? 0 : 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < rows[r]; i++)
                      Container(
                        width: 9,
                        height: 9,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dot,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text('$holes', style: p.display(32)),
            Text(
              name,
              style: p.ui(
                13,
                color: p.ink,
                weight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '첫 폭탄 확률 $risk%',
              textAlign: TextAlign.center,
              style: p.ui(
                12,
                color: selected ? p.accent : p.sub,
                weight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위쪽 무대: 달과 별 아래, 지금 고른 구멍 수대로 그린 통.
class _Hero extends StatelessWidget {
  final int holes;
  final bool compact;

  const _Hero({required this.holes, required this.compact});

  @override
  Widget build(BuildContext context) {
    final width = compact ? 108.0 : 150.0;
    final geo = BarrelGeometry(width, holes);
    return ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: geo.totalHeight + 6,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: compact ? 6 : 14,
              top: compact ? 6 : 18,
              child: CustomPaint(
                size: Size.square(compact ? 44 : 58),
                painter: const _MoonPainter(),
              ),
            ),
            RepaintBoundary(
              child: SizedBox(
                width: geo.width,
                height: geo.totalHeight,
                child: CustomPaint(
                  painter: BarrelPainter(
                    geo: geo,
                    picked: const {},
                    bombSlot: null,
                    mood: pirateMoodFor(PirateLobbyView.riskPct(holes)),
                    dropSlot: null,
                    dropT: null,
                    wobble: 0,
                    tremble: 0,
                    pulse: 0,
                    highlightFree: false,
                    explodeT: null,
                    pirateGone: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x33F4ECDD), Color(0x00F4ECDD)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final moon = Rect.fromCircle(center: c, radius: r * 0.52);
    canvas.saveLayer(moon.inflate(4), Paint());
    canvas.drawCircle(c, r * 0.52, Paint()..color = const Color(0xFFF4ECDD));
    canvas.drawCircle(
      c.translate(r * 0.26, -r * 0.14),
      r * 0.46,
      Paint()
        ..color = const Color(0xFF0A1426)
        ..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 밤바다 바탕: 위쪽이 살짝 밝은 남색 + 작은 별.
class _NightBackdrop extends StatelessWidget {
  final Widget child;

  const _NightBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _NightPainter())),
        child,
      ],
    );
  }
}

class _NightPainter extends CustomPainter {
  const _NightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13233F), Color(0xFF0A1426), Color(0xFF08101E)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    final rnd = math.Random(11);
    final paint = Paint();
    final count = (size.width * size.height / 9000).clamp(18, 60).round();
    for (var i = 0; i < count; i++) {
      final y = rnd.nextDouble() * size.height * 0.5;
      paint.color = const Color(
        0xFFF4ECDD,
      ).withValues(alpha: 0.12 + rnd.nextDouble() * 0.3);
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, y),
        0.5 + rnd.nextDouble() * 1.1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
