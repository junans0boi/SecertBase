import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../widgets/hwatu/hwatu.dart';
import '../../lobby_kit.dart';

/// 고스톱 대기실의 색·서체(초록 펠트 + 황동 헤어라인 + 상아). 게임 화면의 felt와 같은 계열이다.
final kGostopLobbyPalette = LobbyPalette(
  dark: true,
  bg: const Color(0xFF1B342B),
  panel: const Color(0x0FFFFFFF),
  line: const Color(0x38C9A862),
  ink: const Color(0xFFF3ECD9),
  sub: const Color(0xFFB4C4B0),
  accent: const Color(0xFFC9A862),
  accentInk: const Color(0xFF1B2A16),
  me: const Color(0xFF2F5A47),
  meInk: const Color(0xFFC9A862),
  opp: const Color(0xFF2F5A47),
  oppInk: const Color(0xFFC9A862),
  ok: const Color(0xFFC9A862),
  ui: (size, {color, weight, height, spacing = 0}) => lobbyNoto(
    size,
    color: color ?? const Color(0xFFF3ECD9),
    weight: weight,
    height: height,
    spacing: spacing,
  ),
  display: (size, {color, weight, height, spacing = 0}) =>
      GoogleFonts.gowunBatang(
        fontSize: size,
        color: color ?? const Color(0xFFF3ECD9),
        fontWeight: FontWeight.w700,
        height: height ?? 1.2,
        letterSpacing: spacing * size,
      ),
);

String _coins(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

/// 고스톱 대기실: 펠트 위에 펼친 화투, 두 사람, 판돈(1점당) 고르기(방장만), 규칙.
/// 판돈이 걸리면 상대(비방장)는 "준비 완료"로 금액에 동의해야 한다. 로비 동작은
/// [GameLobbyScreen]이 그대로 맡고 이 위젯은 그리기만 한다.
class GostopLobbyView extends StatelessWidget {
  final List<String> players;
  final String? host;
  final String? me;
  final Map<String, String> nicknames;
  final Map<String, bool> ready;
  final int stake;
  final List<int> stakeOptions;
  final bool isHost;
  final bool canStart;
  final String startLabel;

  final ValueChanged<int> onStake;
  final ValueChanged<bool> onReady;
  final VoidCallback? onStart;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  const GostopLobbyView({
    super.key,
    required this.players,
    required this.host,
    required this.me,
    required this.nicknames,
    required this.ready,
    required this.stake,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onStake,
    required this.onReady,
    required this.onStart,
    required this.onBack,
    this.onHelp,
    this.stakeOptions = const [0, 100, 500, 1000],
  });

  static const _rules = [
    ('방식', '맞고 2인 · 내 차례는 25초'),
    ('점수', '7점부터 "고" 또는 "스톱"을 정해요'),
    ('박', '피박·광박·고박이 붙으면 ×2씩 늘어요'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = kGostopLobbyPalette;
    final needsAgree = stake > 0;
    final seats = LobbySeats.resolve(
      players: players,
      host: host,
      me: me,
      nicknames: nicknames,
      ready: ready,
      needsAgree: needsAgree,
    );
    final other = players.where((x) => x != me).firstOrNull;
    final guestReady = other != null && (ready[other] ?? false);
    final myReady = me != null && (ready[me] ?? false);

    final stakeHint = stake == 0
        ? '판돈 없이 가볍게 즐겨요.'
        : '1점에 ${_coins(stake)}코인이에요. 7점 스톱이면 ${_coins(stake * 7)}코인부터, 박이 붙으면 ×2씩 늘어요.';

    // 하단: 방장은 게임 시작, 판돈이 걸린 판의 상대는 준비 완료, 그 밖엔 기다림.
    final Widget bottom;
    if (isHost) {
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needsAgree && players.length >= 2) ...[
            Text(
              guestReady ? '상대가 준비를 마쳤어요' : '상대가 판돈에 동의하면 시작할 수 있어요',
              textAlign: TextAlign.center,
              style: p.ui(
                13,
                color: guestReady ? p.accent : p.sub,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
          ],
          LobbyMainButton(
            palette: p,
            label: startLabel,
            onPressed: canStart ? onStart : null,
          ),
        ],
      );
    } else if (needsAgree) {
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            myReady
                ? '${_coins(stake)}코인 판돈에 동의했어요. 방장이 시작하면 바로 시작돼요.'
                : '이 판에는 1점에 ${_coins(stake)}코인이 걸려 있어요. 동의하면 준비 완료를 눌러 주세요.',
            textAlign: TextAlign.center,
            style: p.ui(13, color: p.sub, weight: FontWeight.w400, height: 1.5),
          ),
          const SizedBox(height: 10),
          LobbyMainButton(
            palette: p,
            label: myReady ? '준비 완료 취소' : '준비 완료',
            style: myReady ? LobbyButtonStyle.ghost : LobbyButtonStyle.primary,
            onPressed: () => onReady(!myReady),
          ),
        ],
      );
    } else {
      bottom = LobbyMainButton(palette: p, label: kLobbyGuestWaitLabel);
    }

    return LobbyScaffold(
      palette: p,
      backdrop: (child) => _FeltBackdrop(child: child),
      title: '고스톱',
      onBack: onBack,
      onHelp: onHelp,
      body: (context, compact) => Column(
        children: [
          SizedBox(height: compact ? 0 : 10),
          _CardFan(compact: compact),
          SizedBox(height: compact ? 8 : 12),
          Text('고스톱', style: p.display(compact ? 30 : 36)),
          const SizedBox(height: 6),
          Text(
            '맞고 · 2인 · 7점부터 고 / 스톱',
            textAlign: TextAlign.center,
            style: p.ui(14, color: p.sub, weight: FontWeight.w400),
          ),
          SizedBox(height: compact ? 16 : 24),
          LobbySectionHead(palette: p, title: '참가자'),
          LobbySeatRow(palette: p, seats: seats, radius: 18),
          if (players.length < 2) ...[
            const SizedBox(height: 10),
            Text(
              '먼저 들어온 사람이 방장이 됩니다',
              textAlign: TextAlign.center,
              style: p.ui(12, color: p.sub, weight: FontWeight.w400),
            ),
          ],
          SizedBox(height: compact ? 16 : 22),
          LobbySectionHead(
            palette: p,
            title: '판돈 · 1점당',
            hint: lobbyOptionHint(isHost: isHost),
          ),
          Row(
            children: [
              for (final option in stakeOptions) ...[
                if (option != stakeOptions.first) const SizedBox(width: 8),
                Expanded(
                  child: _StakeChip(
                    amount: option,
                    selected: stake == option,
                    enabled: isHost,
                    onTap: () => onStake(option),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stakeHint,
            style: p.ui(13, color: p.sub, weight: FontWeight.w400, height: 1.5),
          ),
          const SizedBox(height: 20),
          LobbySectionHead(palette: p, title: '규칙'),
          LobbyRuleRows(palette: p, rows: _rules),
        ],
      ),
      bottom: bottom,
    );
  }
}

/// 판돈 한 칸: 동전 고리 + 금액. 고른 칸은 황동 테두리.
class _StakeChip extends StatelessWidget {
  final int amount;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _StakeChip({
    required this.amount,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = kGostopLobbyPalette;
    final free = amount == 0;
    final color = selected ? p.accent : p.ink;
    return LobbyTapTarget(
      label: free ? '판돈 없음' : '판돈 ${_coins(amount)}코인',
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.accentWash : p.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? p.accent : p.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: free
            ? Text(
                '무료',
                style: p.ui(15, color: color, weight: FontWeight.w700),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _coins(amount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p.display(17, color: color, height: 1.1),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 위쪽 화투 세 장(1월·3월·8월 광)을 부채처럼 펼친다.
class _CardFan extends StatelessWidget {
  final bool compact;

  const _CardFan({required this.compact});

  @override
  Widget build(BuildContext context) {
    final w = compact ? 56.0 : 74.0;
    final h = w * kHwatuAspect;
    final width = w * 2.1;
    Widget card(String id, double angle, Alignment at, double top) {
      return Positioned(
        top: top,
        left: at == Alignment.centerLeft ? 0 : null,
        right: at == Alignment.centerRight ? 0 : null,
        child: Transform.rotate(
          angle: angle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(hwatuCornerRadius(w)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: HwatuArt(cardId: id, width: w),
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: h + 18,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card('m1_bright', -math.pi * 0.06, Alignment.centerLeft, 12),
            card('m8_bright', math.pi * 0.06, Alignment.centerRight, 12),
            Positioned(
              top: 0,
              left: (width - w) / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(hwatuCornerRadius(w)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: HwatuArt(cardId: 'm3_bright', width: w),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 펠트 바탕: 가운데가 살짝 밝은 초록 + 올이 보이는 아주 옅은 천 결.
class _FeltBackdrop extends StatelessWidget {
  final Widget child;

  const _FeltBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _FeltPainter())),
        child,
      ],
    );
  }
}

class _FeltPainter extends CustomPainter {
  const _FeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1B342B));
    final center = Offset(size.width / 2, size.height * 0.26);
    final radius = math.max(size.width * 0.9, 260.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF2A5A44), Color(0x001B342B)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    // 천 결.
    final weave = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weave);
    }
    final vignette = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 1.1,
        colors: [Color(0x00000000), Color(0x59000000)],
        stops: [0.6, 1],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
