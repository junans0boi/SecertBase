import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tank_data.dart';

/// 위쪽 HUD: 나가기·메뉴 줄 + 양쪽 전차 정보와 가운데 바람·시간.
class TankHud extends StatelessWidget {
  final Map<String, dynamic> state;
  final int myIndex;
  final String myName;
  final String oppName;
  final int? remainingMs;
  final bool muted;
  final bool overview;
  final VoidCallback onBack;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleOverview;
  final Widget menu;

  const TankHud({
    super.key,
    required this.state,
    required this.myIndex,
    required this.myName,
    required this.oppName,
    required this.remainingMs,
    required this.muted,
    required this.overview,
    required this.onBack,
    required this.onToggleMute,
    required this.onToggleOverview,
    required this.menu,
  });

  Map<String, dynamic>? _player(int i) {
    final players = state['players'] as List?;
    if (players == null || i < 0 || i >= players.length) return null;
    final p = players[i];
    return p is Map ? Map<String, dynamic>.from(p) : null;
  }

  @override
  Widget build(BuildContext context) {
    final look = tankThemeOf(state);
    final turn = (state['turn'] as num?)?.toInt() ?? 0;
    final aiming = state['phase'] == 'aiming';
    final turnNumber = (state['turnNumber'] as num?)?.toInt() ?? 0;
    final wind = (state['wind'] as num?)?.toDouble() ?? 0;
    final suddenDeath = state['suddenDeath'] == true;
    final timeouts = (state['timeouts'] as List?) ?? const [];
    int timeoutsOf(int i) =>
        i < timeouts.length ? ((timeouts[i] as num?)?.toInt() ?? 0) : 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC0A0F1A), Color(0x660A0F1A), Color(0x000A0F1A)],
          stops: [0, 0.7, 1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _RoundIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: '게임 나가기',
                onTap: onBack,
              ),
              const SizedBox(width: 8),
              Text('탱크 대작전', style: tankDisplay(size: 17)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: TankUi.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TankUi.panelLine),
                ),
                child: Text(
                  look.name,
                  style: tankBody(size: 10, color: TankUi.sub),
                ),
              ),
              const Spacer(),
              _RoundIcon(
                icon: overview
                    ? Icons.zoom_in_map_rounded
                    : Icons.zoom_out_map_rounded,
                tooltip: overview ? '전차 따라가기' : '전장 전체 보기',
                onTap: onToggleOverview,
                active: overview,
              ),
              const SizedBox(width: 6),
              _RoundIcon(
                icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                tooltip: muted ? '소리 켜기' : '소리 끄기',
                onTap: onToggleMute,
              ),
              const SizedBox(width: 2),
              menu,
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TankPlayerCard(
                  name: myName,
                  player: _player(myIndex),
                  team: TankUi.me,
                  active: aiming && turn == myIndex,
                  alignRight: false,
                  timeouts: timeoutsOf(myIndex),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (remainingMs != null && aiming)
                      TankTimerRing(remainingMs: remainingMs!)
                    else
                      const SizedBox(height: 40),
                    const SizedBox(height: 4),
                    TankWindGauge(wind: wind),
                    const SizedBox(height: 3),
                    Text(
                      '${math.min(turnNumber + 1, kTankFinalTurn)} / $kTankFinalTurn턴',
                      style: tankBody(size: 10, color: TankUi.muted),
                    ),
                    if (suddenDeath) const _SuddenDeathBadge(),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TankPlayerCard(
                  name: oppName,
                  player: _player(1 - myIndex),
                  team: TankUi.enemy,
                  active: aiming && turn == 1 - myIndex,
                  alignRight: true,
                  timeouts: timeoutsOf(1 - myIndex),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? TankUi.gold.withValues(alpha: 0.25) : TankUi.panel,
        shape: const CircleBorder(side: BorderSide(color: TankUi.panelLine)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 17, color: TankUi.text),
          ),
        ),
      ),
    );
  }
}

class _SuddenDeathBadge extends StatelessWidget {
  const _SuddenDeathBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [TankUi.fireB, TankUi.fireA]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('서든데스', style: tankDisplay(size: 10)),
    );
  }
}

/// 전차 정보 카드: 이름·전차·HP(깎인 만큼 하얗게 늦게 줄어드는 바)·버프.
class TankPlayerCard extends StatelessWidget {
  final String name;
  final Map<String, dynamic>? player;
  final Color team;
  final bool active;
  final bool alignRight;
  final int timeouts;

  const TankPlayerCard({
    super.key,
    required this.name,
    required this.player,
    required this.team,
    required this.active,
    required this.alignRight,
    this.timeouts = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hp = (player?['hp'] as num?)?.toInt() ?? 0;
    final maxHp = math.max(1, (player?['maxHp'] as num?)?.toInt() ?? 100);
    final cls = kTankClasses[player?['tankClass']];
    final buffs = (player?['buffs'] as Map?) ?? const {};
    final cross = alignRight
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: TankUi.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? team : TankUi.panelLine,
          width: active ? 1.6 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: team.withValues(alpha: 0.45), blurRadius: 12)]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: cross,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: team, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: tankBody(
                    size: 11.5,
                    color: TankUi.text,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              if (cls != null) ...[
                const SizedBox(width: 4),
                Text(
                  cls.name,
                  style: tankBody(size: 10, color: TankUi.muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          TankHpBar(
            ratio: hp / maxHp,
            color: team,
            alignRight: alignRight,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Text(
                '$hp',
                style: tankDisplay(size: 13, color: TankUi.text),
              ),
              Text(
                ' / $maxHp',
                style: tankBody(size: 10, color: TankUi.muted),
              ),
              if (buffs['power'] == true)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 13,
                    color: Color(0xFFFF7A3D),
                  ),
                ),
              if (buffs['shield'] == true)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 13,
                    color: TankUi.cyan,
                  ),
                ),
              if (timeouts > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    '⏱$timeouts/3',
                    style: tankBody(size: 9.5, color: TankUi.danger),
                  ),
                ),
            ],
          ),
          ),
        ],
      ),
    );
  }
}

/// 깎인 만큼 하얀 잔상이 잠시 남았다가 줄어드는 HP 바.
class TankHpBar extends StatefulWidget {
  final double ratio;
  final Color color;
  final bool alignRight;
  const TankHpBar({
    super.key,
    required this.ratio,
    required this.color,
    this.alignRight = false,
  });

  @override
  State<TankHpBar> createState() => _TankHpBarState();
}

class _TankHpBarState extends State<TankHpBar> {
  late double _lag;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lag = widget.ratio.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(TankHpBar old) {
    super.didUpdateWidget(old);
    final next = widget.ratio.clamp(0.0, 1.0);
    if (next < old.ratio) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _lag = widget.ratio.clamp(0.0, 1.0));
      });
    } else {
      _lag = next;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.ratio.clamp(0.0, 1.0);
    final align = widget.alignRight
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final barColor = ratio > 0.5
        ? widget.color
        : ratio > 0.25
        ? TankUi.gold
        : TankUi.danger;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.white.withValues(alpha: 0.12)),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              alignment: align,
              widthFactor: math.max(_lag, ratio),
              child: Container(color: Colors.white.withValues(alpha: 0.85)),
            ),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: align,
              widthFactor: ratio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(barColor, Colors.white, 0.35)!,
                      barColor,
                    ],
                  ),
                ),
              ),
            ),
            // 눈금(10칸)
            Row(
              children: [
                for (int i = 0; i < 10; i++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: i == 9
                                ? Colors.transparent
                                : Colors.black.withValues(alpha: 0.35),
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
    );
  }
}

/// 바람 방향과 세기(5칸).
class TankWindGauge extends StatelessWidget {
  final double wind;
  const TankWindGauge({super.key, required this.wind});

  @override
  Widget build(BuildContext context) {
    final strength = (wind.abs() / 2).clamp(0.0, 1.0);
    final filled = (strength * 5).ceil();
    final right = wind >= 0;
    final calm = wind.abs() < 0.05;
    final color = strength > 0.6 ? TankUi.fireA : TankUi.cyan;
    Widget chevron(int i) {
      final on = !calm && i < filled;
      return Icon(
        right ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
        size: 15,
        color: on ? color : Colors.white.withValues(alpha: 0.18),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: TankUi.panel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: TankUi.panelLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            calm ? '무풍' : '바람 ${wind.abs().toStringAsFixed(1)}',
            style: tankBody(size: 9.5, color: TankUi.sub, weight: FontWeight.w700),
          ),
          SizedBox(
            height: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 5; i++)
                  SizedBox(
                    width: 13,
                    child: OverflowBox(
                      maxWidth: 20,
                      child: chevron(right ? i : 4 - i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 남은 시간 링. 5초 이하면 빨갛게 고동친다.
class TankTimerRing extends StatelessWidget {
  final int remainingMs;
  const TankTimerRing({super.key, required this.remainingMs});

  @override
  Widget build(BuildContext context) {
    final ratio = (remainingMs / kTankTurnMs).clamp(0.0, 1.0);
    final seconds = (remainingMs / 1000).ceil();
    final urgent = seconds <= 5;
    final color = urgent ? TankUi.danger : TankUi.gold;
    final pulse = urgent ? 1 + 0.08 * math.sin(remainingMs / 1000 * math.pi * 2) : 1.0;
    return Transform.scale(
      scale: pulse,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: TankUi.panel,
                shape: BoxShape.circle,
                boxShadow: urgent
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
                    : const [],
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 3.2,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text('$seconds', style: tankDisplay(size: 15, color: color)),
          ],
        ),
      ),
    );
  }
}
