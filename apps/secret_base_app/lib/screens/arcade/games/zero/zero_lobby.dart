import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../lobby_kit.dart';
import 'zero_hand.dart';

/// 제로 대기실의 색·서체(벨벳 살롱: 자두색 막 + 황동 + 로즈). 게임 화면의 스포트라이트 무대와 같은 계열이다.
final kZeroLobbyPalette = LobbyPalette(
  dark: true,
  bg: const Color(0xFF26101F),
  panel: const Color(0x0FFFEEDD),
  line: const Color(0x29F6EEDF),
  ink: const Color(0xFFF6EEDF),
  sub: const Color(0xFFB9A5B0),
  accent: const Color(0xFFD9B26F),
  accentInk: const Color(0xFF2A1520),
  me: const Color(0xFFD9B26F),
  meInk: const Color(0xFF2A1520),
  opp: const Color(0xFFE58CA5),
  oppInk: const Color(0xFF2E0F1A),
  ok: const Color(0xFFD9B26F),
  ui: (size, {color, weight, height, spacing = 0}) => lobbyNoto(
    size,
    color: color ?? const Color(0xFFF6EEDF),
    weight: weight,
    height: height,
    spacing: spacing,
  ),
  display: (size, {color, weight, height, spacing = 0}) =>
      GoogleFonts.nanumMyeongjo(
        fontSize: size,
        color: color ?? const Color(0xFFF6EEDF),
        fontWeight: FontWeight.w700,
        height: height ?? 1.2,
        letterSpacing: spacing * size,
      ),
);

/// 제로 대기실: 스포트라이트 아래 두 장갑, 규칙 세 줄, 두 사람. 옵션은 없다.
/// 로비 동작(방장만 시작)은 [GameLobbyScreen]이 그대로 맡고 이 위젯은 그리기만 한다.
class ZeroLobbyView extends StatelessWidget {
  final List<String> players;
  final String? host;
  final String? me;
  final Map<String, String> nicknames;
  final bool isHost;
  final bool canStart;
  final String startLabel;
  final VoidCallback? onStart;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  const ZeroLobbyView({
    super.key,
    required this.players,
    required this.host,
    required this.me,
    required this.nicknames,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onStart,
    required this.onBack,
    this.onHelp,
  });

  static const _steps = [
    ('손가락 0~5개를 비공개로 고르고', '내가 낼 숫자를 정해요'),
    ('두 사람 합계를 예측해요', '내 숫자 ~ 내 숫자+5 중에서 골라요'),
    ('정확히 맞히면 +2, 둘 다 빗나가면', '더 가까운 쪽이 +1이에요'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = kZeroLobbyPalette;
    final seats = LobbySeats.resolve(
      players: players,
      host: host,
      me: me,
      nicknames: nicknames,
      ready: const {},
    );
    return LobbyScaffold(
      palette: p,
      backdrop: (child) => _VelvetBackdrop(child: child),
      title: '제로',
      onBack: onBack,
      onHelp: onHelp,
      body: (context, compact) => Column(
        children: [
          SizedBox(height: compact ? 0 : 12),
          _Gloves(compact: compact),
          SizedBox(height: compact ? 6 : 10),
          Text('제로', style: p.display(compact ? 34 : 44)),
          const SizedBox(height: 6),
          Text(
            '두 손가락의 합계를 맞혀요',
            textAlign: TextAlign.center,
            style: p.ui(14, color: p.sub, weight: FontWeight.w400),
          ),
          SizedBox(height: compact ? 16 : 26),
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _Step(index: i + 1, title: _steps[i].$1, body: _steps[i].$2),
          ],
          const SizedBox(height: 10),
          Text(
            '5라운드 점수를 더해 승부 · 동점이면 서든데스',
            textAlign: TextAlign.center,
            style: p.ui(12, color: p.sub, weight: FontWeight.w400),
          ),
          const SizedBox(height: 16),
          LobbySeatRow(palette: p, seats: seats),
          if (players.length < 2) ...[
            const SizedBox(height: 10),
            Text(
              '먼저 들어온 사람이 방장이 됩니다',
              textAlign: TextAlign.center,
              style: p.ui(12, color: p.sub, weight: FontWeight.w400),
            ),
          ],
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

/// 번호 + 두 줄 규칙 카드.
class _Step extends StatelessWidget {
  final int index;
  final String title;
  final String body;

  const _Step({required this.index, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final p = kZeroLobbyPalette;
    return Semantics(
      container: true,
      label: '$index단계, $title $body',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: p.card(radius: 18),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.accent.withValues(alpha: 0.7)),
              ),
              child: Text(
                '$index',
                style: p.display(14, color: p.accent, height: 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: p.ui(
                      14,
                      color: p.ink,
                      weight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: p.ui(
                      13,
                      color: p.sub,
                      weight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 마주 보는 흰 장갑 두 짝: 펼친 손(황동 띠)과 두 손가락(로즈 띠).
class _Gloves extends StatelessWidget {
  final bool compact;

  const _Gloves({required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 84.0 : 124.0;
    final p = kZeroLobbyPalette;
    return ExcludeSemantics(
      child: SizedBox(
        height: size + 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Transform.rotate(
              angle: -0.09,
              child: ZeroHand(fingers: 5, trim: p.me, size: size),
            ),
            SizedBox(width: compact ? 22 : 36),
            Transform.rotate(
              angle: 0.09,
              child: ZeroHand(
                fingers: 2,
                trim: p.opp,
                mirrored: true,
                size: size,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 벨벳 바탕: 위에서 내려오는 은은한 스포트라이트 + 아주 옅은 마름모 직물결.
class _VelvetBackdrop extends StatelessWidget {
  final Widget child;

  const _VelvetBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _VelvetPainter())),
        child,
      ],
    );
  }
}

class _VelvetPainter extends CustomPainter {
  const _VelvetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E1428), Color(0xFF26101F), Color(0xFF1C0A16)],
        ).createShader(rect),
    );
    // 마름모 직물결.
    final lattice = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        lattice,
      );
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        lattice,
      );
    }
    // 스포트라이트.
    final center = Offset(size.width / 2, size.height * 0.22);
    final radius = math.max(size.width * 0.85, 240.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x4D8A5A70), Color(0x00402030)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
