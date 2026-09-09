import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen>
    with SingleTickerProviderStateMixin {
  final _socket = SocketService();
  late AnimationController _rollCtrl;
  late Animation<double> _rollAnimation;
  bool _rolling = false;
  int _rollingFace = 1;

  @override
  void initState() {
    super.initState();
    _rollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _rollAnimation = CurvedAnimation(
      parent: _rollCtrl,
      curve: Curves.easeOutCubic,
    );
    _rollCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _rolling = false);
      }
    });
    _rollCtrl.value = 1.0;
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _rollCtrl.dispose();
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    // Keep the cube animation running until its landing frame. The socket
    // result can arrive before that frame and should only update the target
    // face, not cut the animation short.
    setState(() {});
  }

  void _roll() {
    if (_rolling) return;
    setState(() {
      _rolling = true;
      _rollingFace = Random().nextInt(6) + 1;
    });
    _rollCtrl.forward(from: 0);
    _socket.rollDice();
  }

  @override
  Widget build(BuildContext context) {
    final result = _socket.lastDice;
    return GameScaffold(
      title: '🎲 주사위',
      actions: [const GameMenuButton()],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDice(result),
          const SizedBox(height: 40),
          if (result != null) _ResultBadge(label: '결과', value: '$result'),
          const SizedBox(height: 48),
          _buildRollButton(),
        ],
      ),
    );
  }

  Widget _buildDice(int? value) {
    return AnimatedBuilder(
      animation: _rollAnimation,
      builder: (context, child) {
        // The cube is rebuilt from the controller's progress on every frame.
        final progress = _rollAnimation.value;
        final face = _rolling ? _rollingFace : (value ?? _rollingFace);
        final xRotation = (pi * 5.0) * (1.0 - progress) - 0.16;
        final yRotation = (pi * 6.0) * (1.0 - progress) + 0.24;
        final bounce = progress > 0.86
            ? 1.0 + sin(((progress - 0.86) / 0.14) * pi) * 0.045
            : 1.0;

        return Transform.scale(
          scale: bounce,
          child: _PerspectiveDice(
            face: face,
            xRotation: xRotation,
            yRotation: yRotation,
            size: 164,
          ),
        );
      },
    );
  }

  Widget _buildRollButton() {
    return _PrimaryButton(
      onPressed: _rolling ? null : _roll,
      label: _rolling ? '굴리는 중...' : '굴리기',
      icon: Icons.casino_outlined,
    );
  }
}

/// Stack으로 여섯 면을 배치하고 Matrix4로 큐브 전체를 회전시키는 주사위.
///
/// 실제 3D 모델 대신 평면 여섯 장에 원근감을 적용한다. 이 방식은 Flutter
/// 기본 위젯만으로 동작하고, 결과 면을 마지막에 정확히 노출하기 쉽다.
class _PerspectiveDice extends StatelessWidget {
  final int face;
  final double xRotation;
  final double yRotation;
  final double size;

  const _PerspectiveDice({
    required this.face,
    required this.xRotation,
    required this.yRotation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final values = _cubeFaceValues(face.clamp(1, 6).toInt());
    return Transform(
      key: const ValueKey('dice_3d_cube'),
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateX(xRotation)
        ..rotateY(yRotation),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _side(value: values.front),
            _side(value: values.back, yRotation: pi),
            _side(value: values.right, yRotation: pi / 2),
            _side(value: values.left, yRotation: -pi / 2),
            _side(value: values.top, xRotation: -pi / 2),
            _side(value: values.bottom, xRotation: pi / 2),
          ],
        ),
      ),
    );
  }

  Widget _side({
    required int value,
    double xRotation = 0,
    double yRotation = 0,
  }) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateX(xRotation)
        ..rotateY(yRotation)
        ..translateByDouble(0.0, 0.0, -size / 2, 1.0),
      child: _DieFace(value: value, size: size),
    );
  }

  _CubeFaceValues _cubeFaceValues(int front) {
    final opposite = 7 - front;
    final remaining = <int>[
      for (var value = 1; value <= 6; value++)
        if (value != front && value != opposite) value,
    ];
    final right = remaining[0];
    final top = remaining[1];
    return _CubeFaceValues(
      front: front,
      back: opposite,
      right: right,
      left: 7 - right,
      top: top,
      bottom: 7 - top,
    );
  }
}

class _CubeFaceValues {
  final int front;
  final int back;
  final int right;
  final int left;
  final int top;
  final int bottom;

  const _CubeFaceValues({
    required this.front,
    required this.back,
    required this.right,
    required this.left,
    required this.top,
    required this.bottom,
  });
}

class _DieFace extends StatelessWidget {
  final int value;
  final double size;

  const _DieFace({required this.value, required this.size});

  static const _pipPositions = <int, List<Offset>>{
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.27, 0.27), Offset(0.73, 0.73)],
    3: [Offset(0.27, 0.27), Offset(0.5, 0.5), Offset(0.73, 0.73)],
    4: [
      Offset(0.27, 0.27),
      Offset(0.73, 0.27),
      Offset(0.27, 0.73),
      Offset(0.73, 0.73),
    ],
    5: [
      Offset(0.27, 0.27),
      Offset(0.73, 0.27),
      Offset(0.5, 0.5),
      Offset(0.27, 0.73),
      Offset(0.73, 0.73),
    ],
    6: [
      Offset(0.27, 0.2),
      Offset(0.73, 0.2),
      Offset(0.27, 0.5),
      Offset(0.73, 0.5),
      Offset(0.27, 0.8),
      Offset(0.73, 0.8),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _pipPositions[value.clamp(1, 6).toInt()]!;
    final pipSize = size * 0.135;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF655B), Color(0xFFC51F2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF5E0B13), width: 1.2),
        borderRadius: BorderRadius.circular(size * 0.16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 14,
            offset: Offset(4, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          for (final pip in pips)
            Positioned(
              left: size * pip.dx - pipSize / 2,
              top: size * pip.dy - pipSize / 2,
              child: Container(
                width: pipSize,
                height: pipSize,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7E8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── shared widgets ────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  const _PrimaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: 200,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? kPrimaryGrad : null,
          color: enabled ? null : kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: MaterialButton(
          onPressed: onPressed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: enabled ? Colors.white : kTextMuted,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.notoSans(
                  color: enabled ? Colors.white : kTextMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final String label;
  final String value;
  const _ResultBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.notoSans(
              color: kPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
