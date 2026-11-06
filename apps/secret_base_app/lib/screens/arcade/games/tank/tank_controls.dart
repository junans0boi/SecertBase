import 'dart:async';

import 'package:flutter/material.dart';

import 'tank_data.dart';

/// 아래쪽 조작부: 무기 선택, 각도·파워 미세 조정, 이동·연료, 발사.
class TankControls extends StatelessWidget {
  final Map<String, dynamic> ammo;
  final String weapon;
  final String? special;
  final bool enabled;
  final double angle;
  final double power;
  final double fuel;
  final double maxFuel;
  final String statusText;
  final bool showKeyHints;
  final ValueChanged<String> onWeapon;
  final ValueChanged<double> onAngle;
  final ValueChanged<double> onPower;
  final ValueChanged<int> onMove;
  final VoidCallback onFire;

  const TankControls({
    super.key,
    required this.ammo,
    required this.weapon,
    required this.special,
    required this.enabled,
    required this.angle,
    required this.power,
    required this.fuel,
    required this.maxFuel,
    required this.statusText,
    required this.showKeyHints,
    required this.onWeapon,
    required this.onAngle,
    required this.onPower,
    required this.onMove,
    required this.onFire,
  });

  static bool hasAmmo(dynamic raw) => raw is num && raw > 0;

  static String ammoLabel(dynamic raw) {
    if (raw is! num) return '0';
    return raw >= 900 ? '∞' : '${raw.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final weapons = tankWeaponList(ammo, special);
    final info = kTankWeapons[weapon];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000A0F1A), Color(0xD90A0F1A), Color(0xF20A0F1A)],
          stops: [0, 0.22, 1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: weapons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final w = weapons[i];
                    final usable = enabled && hasAmmo(ammo[w]);
                    return TankWeaponTile(
                      id: w,
                      index: i,
                      count: ammoLabel(ammo[w]),
                      selected: weapon == w,
                      special: special == w,
                      enabled: usable,
                      onTap: usable ? () => onWeapon(w) : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                enabled
                    ? (info == null ? '' : '${info.name} · ${info.desc}')
                    : statusText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tankBody(
                  size: 11,
                  color: enabled ? TankUi.sub : TankUi.gold,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TankStepper(
                                label: '각도',
                                value: '${angle.round()}°',
                                fraction: angle / 180,
                                enabled: enabled,
                                onStep: onAngle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TankStepper(
                                label: '파워',
                                value: '${power.round()}',
                                fraction: power / 100,
                                enabled: enabled,
                                onStep: onPower,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _MovePad(
                          fuel: fuel,
                          maxFuel: maxFuel,
                          enabled: enabled,
                          onMove: onMove,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TankFireButton(enabled: enabled, onFire: onFire),
                ],
              ),
              if (showKeyHints) ...[
                const SizedBox(height: 6),
                Text(
                  '← → 각도 · ↑ ↓ 파워 · A D 이동 · 1~9 무기 · Space 발사 · 전장을 끌어서 조준',
                  textAlign: TextAlign.center,
                  style: tankBody(size: 10, color: TankUi.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TankWeaponTile extends StatelessWidget {
  final String id;
  final int index;
  final String count;
  final bool selected;
  final bool special;
  final bool enabled;
  final VoidCallback? onTap;

  const TankWeaponTile({
    super.key,
    required this.id,
    required this.index,
    required this.count,
    required this.selected,
    required this.special,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = kTankWeapons[id];
    final color = info?.color ?? TankUi.gold;
    return Semantics(
      button: true,
      selected: selected,
      label: info?.name ?? id,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled || selected ? 1 : 0.4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 64,
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.22) : TankUi.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? color
                    : (special
                          ? TankUi.gold.withValues(alpha: 0.6)
                          : TankUi.panelLine),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(info?.icon ?? Icons.circle, size: 18, color: color),
                      const SizedBox(height: 2),
                      Text(
                        info?.name ?? id,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: tankBody(
                          size: 10,
                          color: TankUi.text,
                          weight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 3,
                  child: Text(
                    count,
                    style: tankDisplay(
                      size: 10,
                      color: count == '0' ? TankUi.danger : TankUi.sub,
                    ),
                  ),
                ),
                if (special)
                  const Positioned(
                    left: 4,
                    top: 3,
                    child: Icon(
                      Icons.star_rounded,
                      size: 11,
                      color: TankUi.gold,
                    ),
                  ),
                if (index < 9)
                  Positioned(
                    left: 4,
                    bottom: 2,
                    child: Text(
                      '${index + 1}',
                      style: tankBody(size: 8, color: TankUi.muted),
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

/// [−] 값 [+] 조정기. 누르고 있으면 빠르게 반복된다.
class TankStepper extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final bool enabled;
  final ValueChanged<double> onStep;

  const TankStepper({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.enabled,
    required this.onStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: TankUi.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TankUi.panelLine),
      ),
      child: Row(
        children: [
          TankRepeatButton(
            icon: Icons.remove_rounded,
            tooltip: '$label 줄이기',
            onStep: enabled ? () => onStep(-1) : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: tankBody(size: 9, color: TankUi.muted, height: 1),
                ),
                Text(value, style: tankDisplay(size: 17)),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(TankUi.gold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TankRepeatButton(
            icon: Icons.add_rounded,
            tooltip: '$label 늘리기',
            onStep: enabled ? () => onStep(1) : null,
          ),
        ],
      ),
    );
  }
}

class _MovePad extends StatelessWidget {
  final double fuel;
  final double maxFuel;
  final bool enabled;
  final ValueChanged<int> onMove;
  const _MovePad({
    required this.fuel,
    required this.maxFuel,
    required this.enabled,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxFuel <= 0 ? 0.0 : (fuel / maxFuel).clamp(0.0, 1.0);
    final canMove = enabled && fuel > 0;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: TankUi.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TankUi.panelLine),
      ),
      child: Row(
        children: [
          TankRepeatButton(
            icon: Icons.keyboard_double_arrow_left_rounded,
            tooltip: '왼쪽으로 이동',
            interval: const Duration(milliseconds: 280),
            onStep: canMove ? () => onMove(-2) : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_gas_station_rounded,
                      size: 12,
                      color: TankUi.cyan,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '연료 ${fuel.floor()}/${maxFuel.round()}',
                      style: tankBody(size: 10, color: TankUi.sub, height: 1.1),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        ratio > 0.25 ? TankUi.cyan : TankUi.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TankRepeatButton(
            icon: Icons.keyboard_double_arrow_right_rounded,
            tooltip: '오른쪽으로 이동',
            interval: const Duration(milliseconds: 280),
            onStep: canMove ? () => onMove(2) : null,
          ),
        ],
      ),
    );
  }
}

/// 누르고 있으면 반복 실행되는 버튼.
class TankRepeatButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onStep;
  final Duration interval;

  const TankRepeatButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onStep,
    this.interval = const Duration(milliseconds: 70),
  });

  @override
  State<TankRepeatButton> createState() => _TankRepeatButtonState();
}

class _TankRepeatButtonState extends State<TankRepeatButton> {
  Timer? _delay;
  Timer? _repeat;
  bool _down = false;

  void _start() {
    final step = widget.onStep;
    if (step == null) return;
    step();
    setState(() => _down = true);
    _delay = Timer(const Duration(milliseconds: 350), () {
      _repeat = Timer.periodic(widget.interval, (_) {
        final s = widget.onStep;
        if (s == null) {
          _stop();
        } else {
          s();
        }
      });
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
    if (mounted && _down) setState(() => _down = false);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onStep != null;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _start(),
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _down
                ? TankUi.gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: enabled ? 0.08 : 0.03),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: enabled ? TankUi.text : TankUi.muted,
          ),
        ),
      ),
    );
  }
}

/// 큰 원형 발사 버튼. 쏠 수 있을 때 은은하게 고동친다.
class TankFireButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onFire;
  const TankFireButton({
    super.key,
    required this.enabled,
    required this.onFire,
  });

  @override
  State<TankFireButton> createState() => _TankFireButtonState();
}

class _TankFireButtonState extends State<TankFireButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(TankFireButton old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.enabled && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '발사',
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onFire();
              }
            : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = enabled ? 0.35 + _pulse.value * 0.35 : 0.0;
            return AnimatedScale(
              duration: const Duration(milliseconds: 90),
              scale: _pressed ? 0.92 : 1,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: enabled
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [TankUi.fireA, TankUi.fireB],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF3A4256), Color(0xFF2A3042)],
                        ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: enabled ? 0.55 : 0.15,
                    ),
                    width: 2,
                  ),
                  boxShadow: [
                    if (enabled)
                      BoxShadow(
                        color: TankUi.fireB.withValues(alpha: glow),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                enabled
                    ? Icons.rocket_launch_rounded
                    : Icons.hourglass_top_rounded,
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.5),
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                enabled ? '발사!' : '대기',
                style: tankDisplay(
                  size: 14,
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
