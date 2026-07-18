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
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;
  bool _rolling = false;

  static const _faces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() => _rolling = false);
    _shakeCtrl.forward(from: 0);
  }

  void _roll() {
    if (_rolling) return;
    setState(() => _rolling = true);
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
      animation: _shake,
      builder: (_, child) {
        final offset = sin(_shake.value * pi * 6) * 8 * (1 - _shake.value);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: _rolling ? kPrimary : kBorder,
            width: _rolling ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: _rolling ? 0.3 : 0.1),
              blurRadius: _rolling ? 32 : 12,
              spreadRadius: _rolling ? 4 : 0,
            ),
          ],
        ),
        child: Center(
          child: _rolling
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: kPrimary,
                  ),
                )
              : Text(
                  value != null ? _faces[value - 1] : '🎲',
                  style: const TextStyle(fontSize: 80),
                ),
        ),
      ),
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
