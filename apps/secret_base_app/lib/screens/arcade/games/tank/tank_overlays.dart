import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tank_data.dart';
import 'tank_painter.dart';

// ── 턴 배너 ──────────────────────────────────────────────────────────────────

class TankBannerData {
  final int id;
  final String text;
  final String? sub;
  final Color color;
  final DateTime createdAt;
  TankBannerData(this.id, this.text, this.color, {this.sub})
    : createdAt = DateTime.now();

  /// 백그라운드 탭에서 돌아왔을 때처럼 이미 지난 알림은 다시 띄우지 않는다.
  bool get stale =>
      DateTime.now().difference(createdAt) > const Duration(milliseconds: 1500);
}

/// 화면을 가로지르며 "내 차례!" 등을 알리는 배너. [banner.id]가 바뀔 때마다 재생한다.
class TankTurnBanner extends StatefulWidget {
  final TankBannerData? banner;
  const TankTurnBanner({super.key, required this.banner});

  @override
  State<TankTurnBanner> createState() => _TankTurnBannerState();
}

class _TankTurnBannerState extends State<TankTurnBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    final b = widget.banner;
    if (b != null && !b.stale) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(TankTurnBanner old) {
    super.didUpdateWidget(old);
    final b = widget.banner;
    if (b != null && b.id != old.banner?.id && !b.stale) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.banner;
    if (b == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          // 0~0.18 들어오기, 0.18~0.8 머물기, 0.8~1 나가기
          final double slide;
          if (t < 0.18) {
            slide = -1 + Curves.easeOutCubic.transform(t / 0.18);
          } else if (t < 0.8) {
            slide = 0;
          } else {
            slide = Curves.easeInCubic.transform((t - 0.8) / 0.2);
          }
          final opacity = t < 0.1
              ? t / 0.1
              : t > 0.9
              ? (1 - t) / 0.1
              : 1.0;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: FractionalTranslation(
              translation: Offset(slide, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      b.color.withValues(alpha: 0),
                      const Color(0xE6101624),
                      const Color(0xE6101624),
                      b.color.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.2, 0.8, 1],
                  ),
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: b.color.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.text,
                      style: tankDisplay(
                        size: 30,
                        color: b.color,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: b.color.withValues(alpha: 0.6),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                    if (b.sub != null)
                      Text(
                        b.sub!,
                        style: tankBody(size: 12, color: TankUi.sub),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 짧은 알림(토스트) ────────────────────────────────────────────────────────

/// 조작부를 가리지 않도록 미니맵 아래에 잠깐 떠오르는 알림.
class TankToast extends StatefulWidget {
  final TankBannerData? toast;
  const TankToast({super.key, required this.toast});

  @override
  State<TankToast> createState() => _TankToastState();
}

class _TankToastState extends State<TankToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    final t = widget.toast;
    if (t != null && !t.stale) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(TankToast old) {
    super.didUpdateWidget(old);
    final t = widget.toast;
    if (t != null && t.id != old.toast?.id && !t.stale) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.toast;
    if (t == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final v = _ctrl.value;
          if (v <= 0 || v >= 1) return const SizedBox.shrink();
          final opacity = v < 0.1
              ? v / 0.1
              : v > 0.85
              ? (1 - v) / 0.15
              : 1.0;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - opacity) * -8),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE6101624),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.color.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    t.text,
                    textAlign: TextAlign.center,
                    style: tankBody(
                      size: 12.5,
                      color: TankUi.text,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 전차 선택 ────────────────────────────────────────────────────────────────

class TankSelectView extends StatelessWidget {
  final Map<String, dynamic> state;
  final String? preview;
  final bool locked;
  final bool oppPicked;
  final ValueChanged<String> onPreview;
  final VoidCallback onConfirm;

  const TankSelectView({
    super.key,
    required this.state,
    required this.preview,
    required this.locked,
    required this.oppPicked,
    required this.onPreview,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final look = tankThemeOf(state);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99070B14), Color(0xCC070B14), Color(0xF2070B14)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 640;
          final cardWidth = wide
              ? math.min(260.0, (c.maxWidth - 64) / 4)
              : (c.maxWidth - 42) / 2;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
                  children: [
                    Text(
                      '전차 선택',
                      textAlign: TextAlign.center,
                      style: tankDisplay(
                        size: 32,
                        letterSpacing: 3,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Chip(
                          icon: Icons.terrain_rounded,
                          text: '전장: ${look.name}',
                          color: TankUi.gold,
                        ),
                        _Chip(
                          icon: Icons.air_rounded,
                          text: look.hint,
                          color: TankUi.cyan,
                        ),
                        _Chip(
                          icon: oppPicked
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_top_rounded,
                          text: oppPicked ? '상대 준비 완료' : '상대가 고르는 중',
                          color: oppPicked ? TankUi.me : TankUi.sub,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final id in kTankClassOrder)
                          SizedBox(
                            width: cardWidth,
                            child: TankClassCard(
                              info: kTankClasses[id]!,
                              selected: preview == id,
                              locked: locked,
                              onTap: locked ? null : () => onPreview(id),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 출격 버튼은 화면 아래에 고정해 카드가 길어도 항상 보이게 한다.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: const BoxDecoration(
                  color: Color(0xF2070B14),
                  border: Border(top: BorderSide(color: TankUi.panelLine)),
                ),
                child: Center(
                  child: locked
                      ? Text(
                          oppPicked ? '곧 전투가 시작돼요!' : '출격 준비 완료! 상대를 기다리고 있어요',
                          style: tankBody(
                            size: 13,
                            color: TankUi.me,
                            weight: FontWeight.w800,
                          ),
                        )
                      : SizedBox(
                          width: 260,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: preview == null
                                  ? null
                                  : const LinearGradient(
                                      colors: [TankUi.fireA, TankUi.fireB],
                                    ),
                              color: preview == null ? TankUi.panelHi : null,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: preview == null
                                  ? const []
                                  : [
                                      BoxShadow(
                                        color: TankUi.fireB.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 16,
                                      ),
                                    ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: preview == null ? null : onConfirm,
                                child: Center(
                                  child: Text(
                                    preview == null
                                        ? '전차를 골라 주세요'
                                        : '${tankWithRo(kTankClasses[preview]?.name ?? '')} 출격!',
                                    style: tankDisplay(
                                      size: 18,
                                      color: preview == null
                                          ? TankUi.muted
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Chip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TankUi.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: tankBody(size: 11.5, color: TankUi.text)),
        ],
      ),
    );
  }
}

class TankClassCard extends StatelessWidget {
  final TankClassInfo info;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  const TankClassCard({
    super.key,
    required this.info,
    required this.selected,
    required this.locked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final special = kTankWeapons[info.special];
    final border = selected ? TankUi.me : TankUi.panelLine;
    return Semantics(
      button: true,
      selected: selected,
      label: info.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xF0142030) : TankUi.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: TankUi.me.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 64,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TankPreviewPainter(info.id, selected),
                ),
              ),
              Row(
                children: [
                  Text(info.name, style: tankDisplay(size: 19)),
                  const Spacer(),
                  if (selected)
                    Icon(
                      locked ? Icons.lock_rounded : Icons.check_circle_rounded,
                      size: 18,
                      color: TankUi.me,
                    ),
                ],
              ),
              Text(
                info.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tankBody(size: 10.5, color: TankUi.muted),
              ),
              const SizedBox(height: 6),
              _StatBar(label: '체력', value: info.hp / 130, text: '${info.hp}'),
              const SizedBox(height: 3),
              _StatBar(
                label: '기동',
                value: info.fuel / 45,
                text: '${info.fuel}',
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 13, color: TankUi.cyan),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      info.passive,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tankBody(size: 10.5, color: TankUi.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    special?.icon ?? Icons.star_rounded,
                    size: 13,
                    color: special?.color ?? TankUi.gold,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '★ ${special?.name ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tankBody(
                        size: 10.5,
                        color: TankUi.gold,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final String text;
  const _StatBar({
    required this.label,
    required this.value,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(label, style: tankBody(size: 9.5, color: TankUi.muted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(TankUi.gold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 22,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: tankDisplay(size: 10, color: TankUi.sub),
          ),
        ),
      ],
    );
  }
}

class _TankPreviewPainter extends CustomPainter {
  final String cls;
  final bool selected;
  const _TankPreviewPainter(this.cls, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final ground = size.height - 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, ground, size.width, 4),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    final u = math.min(size.width / 7.5, size.height / 3.6);
    paintTank(
      canvas,
      base: Offset(size.width / 2, ground),
      u: u,
      cls: cls,
      team: selected ? TankUi.me : const Color(0xFF8C97B0),
      angle: 30,
    );
  }

  @override
  bool shouldRepaint(_TankPreviewPainter old) =>
      old.cls != cls || old.selected != selected;
}

// ── 결과 ─────────────────────────────────────────────────────────────────────

class TankResultOverlay extends StatefulWidget {
  final bool win;
  final bool draw;
  final String reason;
  final int myWins;
  final int oppWins;
  final Map<String, dynamic>? mine;
  final Map<String, dynamic>? theirs;
  final bool restartWaiting;
  final VoidCallback onExit;
  final VoidCallback onRematch;

  const TankResultOverlay({
    super.key,
    required this.win,
    required this.draw,
    required this.reason,
    required this.myWins,
    required this.oppWins,
    required this.mine,
    required this.theirs,
    required this.restartWaiting,
    required this.onExit,
    required this.onRematch,
  });

  @override
  State<TankResultOverlay> createState() => _TankResultOverlayState();
}

class _TankResultOverlayState extends State<TankResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _stat(Map<String, dynamic>? p, String key) {
    final stats = p?['stats'] as Map?;
    return (stats?[key] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.draw
        ? TankUi.cyan
        : (widget.win ? TankUi.gold : TankUi.enemy);
    final title = widget.draw ? '무승부' : (widget.win ? '승리!' : '패배');
    final rows = <(String, int, int, String)>[
      (
        '가한 피해',
        _stat(widget.mine, 'damageDealt'),
        _stat(widget.theirs, 'damageDealt'),
        '',
      ),
      (
        '명중률',
        (widget.mine?['accuracy'] as num?)?.toInt() ?? 0,
        (widget.theirs?['accuracy'] as num?)?.toInt() ?? 0,
        '%',
      ),
      (
        '직격',
        _stat(widget.mine, 'directHits'),
        _stat(widget.theirs, 'directHits'),
        '',
      ),
      (
        '최대 한 방',
        _stat(widget.mine, 'maxHit'),
        _stat(widget.theirs, 'maxHit'),
        '',
      ),
      (
        '보급 획득',
        _stat(widget.mine, 'crates'),
        _stat(widget.theirs, 'crates'),
        '',
      ),
    ];

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final enter = Curves.easeOutBack.transform(
          (_ctrl.value * 4 / 0.6).clamp(0.0, 1.0),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black.withValues(
                alpha: 0.55 * (_ctrl.value * 8).clamp(0.0, 1.0),
              ),
            ),
            if (widget.win && !widget.draw)
              IgnorePointer(
                child: CustomPaint(painter: _ConfettiPainter(_ctrl.value)),
              ),
            Center(
              child: Opacity(
                opacity: enter.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.85 + 0.15 * enter,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          decoration: BoxDecoration(
            color: TankUi.panelSolid,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: tankDisplay(
                  size: 52,
                  color: color,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.7), blurRadius: 22),
                  ],
                ),
              ),
              if (widget.reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.reason,
                  textAlign: TextAlign.center,
                  style: tankBody(size: 13, color: TankUi.sub),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ScoreBadge(
                    label: '나',
                    value: widget.myWins,
                    color: TankUi.me,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: tankDisplay(size: 24, color: TankUi.muted),
                    ),
                  ),
                  _ScoreBadge(
                    label: '상대',
                    value: widget.oppWins,
                    color: TankUi.enemy,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final r in rows) _CompareRow(r.$1, r.$2, r.$3, r.$4),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TankUi.text,
                          side: const BorderSide(color: TankUi.panelLine),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: widget.onExit,
                        child: Text('나가기', style: tankDisplay(size: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: widget.restartWaiting
                              ? null
                              : const LinearGradient(
                                  colors: [TankUi.fireA, TankUi.fireB],
                                ),
                          color: widget.restartWaiting ? TankUi.panelHi : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: widget.restartWaiting
                                ? null
                                : widget.onRematch,
                            child: Center(
                              child: Text(
                                widget.restartWaiting ? '상대 응답 대기 중' : '재대결',
                                style: tankDisplay(size: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ScoreBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(label, style: tankBody(size: 10, color: TankUi.sub)),
          Text('$value', style: tankDisplay(size: 26, color: color)),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final int mine;
  final int theirs;
  final String unit;
  const _CompareRow(this.label, this.mine, this.theirs, this.unit);

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, mine + theirs);
    final empty = mine + theirs == 0;
    final mineBetter = mine > theirs;
    final theirsBetter = theirs > mine;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  '$mine$unit',
                  style: tankDisplay(
                    size: 15,
                    color: mineBetter ? TankUi.gold : TankUi.text,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: tankBody(size: 11, color: TankUi.muted),
                ),
              ),
              SizedBox(
                width: 54,
                child: Text(
                  '$theirs$unit',
                  textAlign: TextAlign.right,
                  style: tankDisplay(
                    size: 15,
                    color: theirsBetter ? TankUi.gold : TankUi.sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  if (empty)
                    Expanded(
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    )
                  else ...[
                    Expanded(
                      flex: math.max(1, (mine / total * 100).round()),
                      child: Container(color: TankUi.me),
                    ),
                    Expanded(
                      flex: math.max(1, (theirs / total * 100).round()),
                      child: Container(color: TankUi.enemy),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  const _ConfettiPainter(this.t);

  static const _colors = [
    Color(0xFFFFC94A),
    Color(0xFF3DDC97),
    Color(0xFF4FC3F7),
    Color(0xFFFF6F91),
    Color(0xFFB18CFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sec = t * 4;
    for (int i = 0; i < 70; i++) {
      final seed = i * 7.31;
      final rx = (math.sin(seed) * 43758.5453) % 1;
      final x0 = (rx < 0 ? rx + 1 : rx) * size.width;
      final speed = 120 + (i % 7) * 25.0;
      final y = -20 + sec * speed - (i % 5) * 40;
      if (y < -20 || y > size.height + 20) continue;
      final x = x0 + math.sin(sec * 2 + i) * 18;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(sec * (2 + i % 3) + i);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -2.5, 8, 5),
        Paint()
          ..color = _colors[i % _colors.length].withValues(
            alpha: (1 - (t - 0.7).clamp(0.0, 0.3) / 0.3),
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
