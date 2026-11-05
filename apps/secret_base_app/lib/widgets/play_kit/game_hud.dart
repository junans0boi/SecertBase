import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/game_sfx/game_sfx.dart';
import '../game_menu.dart';
import 'game_theme.dart';

/// 서버 마감시각을 이 기기 시계로 옮긴 것. 서버는 `deadline`과 함께 `serverNow`를 보낸다.
/// 기기 시계가 서버와 어긋나도 남은 시간이 맞게 보인다.
class GameDeadline {
  final DateTime localDeadline;
  final Duration total;

  const GameDeadline(this.localDeadline, this.total);

  /// [deadlineMs]·[serverNowMs]는 서버 epoch ms. [serverNowMs]가 없으면 기기 시계를 믿는다.
  static GameDeadline? fromServer({
    required num? deadlineMs,
    num? serverNowMs,
    required Duration total,
    DateTime? receivedAt,
  }) {
    if (deadlineMs == null) return null;
    final now = receivedAt ?? DateTime.now();
    final remaining = serverNowMs == null
        ? deadlineMs.toInt() - now.millisecondsSinceEpoch
        : deadlineMs.toInt() - serverNowMs.toInt();
    return GameDeadline(
      now.add(Duration(milliseconds: remaining.clamp(0, total.inMilliseconds))),
      total,
    );
  }

  Duration remaining([DateTime? now]) {
    final left = localDeadline.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

/// 게임 상단 바: 뒤로, 제목, (선택) 전적, 소리 켜기/끄기, 메뉴(재대결 요청 포함).
class GameTopBar extends StatelessWidget {
  final GameTheme theme;
  final String title;
  final String gameType;
  final bool canRestart;
  final bool restartWaiting;
  final VoidCallback? onRequestRestart;
  final Widget? trailing;
  final VoidCallback? onHelp;

  const GameTopBar({
    super.key,
    required this.theme,
    required this.title,
    required this.gameType,
    this.canRestart = false,
    this.restartWaiting = false,
    this.onRequestRestart,
    this.trailing,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const compact = VisualDensity(horizontal: -2, vertical: -2);
    final actions = <Widget>[
      ?trailing,
      if (onHelp != null)
        IconButton(
          tooltip: '규칙 보기',
          visualDensity: compact,
          icon: Icon(Icons.help_outline_rounded, size: 21, color: t.ink),
          onPressed: onHelp,
        ),
      _MuteButton(color: t.ink),
      GameMenuButton(
        hasRestart: canRestart,
        restartWaiting: restartWaiting,
        onRequestRestart: onRequestRestart,
        iconColor: t.ink,
      ),
    ];
    // 제목은 양옆 버튼 수와 상관없이 화면 정가운데에 둔다.
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 128),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: t.display(size: 22),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: '게임 나가기',
                icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ],
      ),
    );
  }
}

class _MuteButton extends StatefulWidget {
  final Color color;

  const _MuteButton({required this.color});

  @override
  State<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<_MuteButton> {
  @override
  Widget build(BuildContext context) {
    final sfx = GameSfx.instance;
    return IconButton(
      tooltip: sfx.muted ? '소리 켜기' : '소리 끄기',
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      icon: Icon(
        sfx.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        size: 21,
        color: widget.color,
      ),
      onPressed: () async {
        await sfx.setMuted(!sfx.muted);
        if (!sfx.muted) sfx.play(GameSound.tap);
        if (mounted) setState(() {});
      },
    );
  }
}

/// 플레이어 표시: 프로필 이모지 원형 아바타(금박 링) + 이름 + 보조 문구.
/// [active]이면 차례 빛이 돈다.
class PlayerBadge extends StatelessWidget {
  final GameTheme theme;
  final String emoji;
  final String name;
  final String? subtitle;
  final bool active;
  final bool isMe;
  final bool compact;
  final CrossAxisAlignment align;
  final Widget? extra;

  const PlayerBadge({
    super.key,
    required this.theme,
    required this.emoji,
    required this.name,
    this.subtitle,
    this.active = false,
    this.isMe = false,
    this.compact = false,
    this.align = CrossAxisAlignment.center,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final size = compact ? 40.0 : 52.0;
    final ring = isMe ? t.me : t.opponent;
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active ? t.goldGradient : null,
        color: active ? null : ring.withValues(alpha: 0.6),
        boxShadow: active
            ? [
                BoxShadow(
                  color: t.gold.withValues(alpha: 0.65),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.dark ? const Color(0xFF1C1424) : Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          emoji.isEmpty ? '🙂' : emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
    final texts = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isMe ? '$name (나)' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.body(size: compact ? 12.5 : 14, weight: FontWeight.w800),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(size: 11.5, color: t.subInk, weight: FontWeight.w600),
          ),
        ?extra,
      ],
    );
    return Semantics(
      label:
          '$name${active ? ', 차례' : ''}${subtitle != null ? ', $subtitle' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          SizedBox(width: compact ? 7 : 9),
          Flexible(child: texts),
        ],
      ),
    );
  }
}

/// 남은 시간 링. [deadline]이 없으면 비어 있다. 마지막 5초는 붉게 깜빡이고 초마다 틱 소리.
class TurnTimerRing extends StatefulWidget {
  final GameTheme theme;
  final GameDeadline? deadline;
  final double size;
  final bool tickSound;

  const TurnTimerRing({
    super.key,
    required this.theme,
    required this.deadline,
    this.size = 44,
    this.tickSound = false,
  });

  @override
  State<TurnTimerRing> createState() => _TurnTimerRingState();
}

class _TurnTimerRingState extends State<TurnTimerRing> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final d = widget.deadline;
      if (d != null && widget.tickSound) {
        final s = d.remaining().inSeconds;
        if (s != _lastSecond && s <= 5 && s >= 1) {
          GameSfx.instance.play(GameSound.tick);
        }
        _lastSecond = s;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final d = widget.deadline;
    final total = d?.total.inMilliseconds ?? 1;
    final left = d?.remaining().inMilliseconds ?? 0;
    final frac = d == null ? 0.0 : (left / math.max(1, total)).clamp(0.0, 1.0);
    final secs = (left / 1000).ceil();
    final urgent = d != null && secs <= 5;
    final color = urgent ? const Color(0xFFFF5A5F) : t.gold;
    return Semantics(
      label: d == null ? '시간 제한 없음' : '남은 시간 $secs초',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            frac: frac,
            color: color,
            track: t.ink.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Text(
              d == null ? '' : '$secs',
              style: t.body(
                size: widget.size * 0.34,
                color: urgent ? color : t.ink,
                weight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final Color color;
  final Color track;

  _RingPainter({required this.frac, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * frac,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.frac != frac || old.color != color;
}

/// 이번 방 전적 "나 2 : 1 상대 (무 1)".
class SeriesScore extends StatelessWidget {
  final GameTheme theme;
  final int myWins;
  final int opponentWins;
  final int draws;

  const SeriesScore({
    super.key,
    required this.theme,
    required this.myWins,
    required this.opponentWins,
    this.draws = 0,
  });

  /// 서버 `series`({wins:{id:n}, draws}) 맵에서 만든다.
  factory SeriesScore.fromMap(
    GameTheme theme,
    Map<String, dynamic>? series,
    String? me,
  ) {
    final wins = (series?['wins'] as Map?) ?? const {};
    int mine = 0, theirs = 0;
    wins.forEach((k, v) {
      final n = (v as num?)?.toInt() ?? 0;
      if (k == me) {
        mine = n;
      } else {
        theirs += n;
      }
    });
    return SeriesScore(
      theme: theme,
      myWins: mine,
      opponentWins: theirs,
      draws: (series?['draws'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label: '이번 방 전적 나 $myWins승, 상대 $opponentWins승, 무승부 $draws',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: t.dark ? 0.6 : 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.gold.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$myWins', style: t.display(size: 16, color: t.me)),
            Text('  :  ', style: t.body(size: 12, color: t.subInk)),
            Text(
              '$opponentWins',
              style: t.display(size: 16, color: t.opponent),
            ),
            if (draws > 0) ...[
              const SizedBox(width: 6),
              Text('무 $draws', style: t.body(size: 11, color: t.subInk)),
            ],
          ],
        ),
      ),
    );
  }
}
