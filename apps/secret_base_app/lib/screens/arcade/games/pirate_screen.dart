import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class PirateScreen extends StatefulWidget {
  const PirateScreen({super.key});

  @override
  State<PirateScreen> createState() => _PirateScreenState();
}

class _PirateScreenState extends State<PirateScreen> {
  final _socket = SocketService();
  int _slots = 8;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() => _spinning = false);
    HapticFeedback.heavyImpact();
  }

  void _spin() {
    if (_spinning) return;
    setState(() => _spinning = true);
    _socket.spinPirate(_slots);
  }

  void _reset() {
    setState(() {
      _pickedSlot = null;
      _spinning = false;
    });
    _socket.pirateSlot = null;
  }

  @override
  Widget build(BuildContext context) {
    final bombSlot = _socket.pirateSlot;
    return GameScaffold(
      title: '🏴‍☠️ 해적 룰렛',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              '폭탄이 숨어있는 통 어디?',
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildSlotGrid(bombSlot),
            const SizedBox(height: 24),
            _buildSlotStepper(),
            const SizedBox(height: 32),
            if (bombSlot != null) ...[
              _BombResult(slot: bombSlot, total: _socket.pirateSlots ?? _slots),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: const BorderSide(color: kPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ] else
              _SpinBtn(spinning: _spinning, onTap: _spin),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotGrid(int? bombSlot) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _slots <= 6 ? 3 : 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: _slots,
      itemBuilder: (ctx, i) {
        final isBomb = bombSlot == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            color: bombSlot == null
                ? kCard
                : isBomb
                    ? kError.withOpacity(0.2)
                    : kSuccess.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bombSlot == null
                  ? kBorder
                  : isBomb
                      ? kError.withOpacity(0.6)
                      : kSuccess.withOpacity(0.4),
              width: isBomb ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              bombSlot == null
                  ? '${i + 1}'
                  : isBomb
                      ? '💣'
                      : '✅',
              style: TextStyle(
                fontSize: bombSlot == null ? 16 : 24,
                color: kTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('통 개수: ', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
        IconButton(
          onPressed: _slots > 4 ? () => setState(() => _slots--) : null,
          icon: const Icon(Icons.remove_circle_outline, color: kPrimary),
        ),
        Text(
          '$_slots',
          style: GoogleFonts.notoSans(color: kText, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        IconButton(
          onPressed: _slots < 12 ? () => setState(() => _slots++) : null,
          icon: const Icon(Icons.add_circle_outline, color: kPrimary),
        ),
      ],
    );
  }
}

class _BombResult extends StatelessWidget {
  final int slot;
  final int total;
  const _BombResult({required this.slot, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kError.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kError.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('💣', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            '폭탄은 ${slot + 1}번 통!',
            style: GoogleFonts.notoSans(color: kError, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            '($total개 중)',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SpinBtn extends StatelessWidget {
  final bool spinning;
  final VoidCallback onTap;
  const _SpinBtn({required this.spinning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: spinning ? null : LinearGradient(colors: [const Color(0xFFFF6348), const Color(0xFFCC4F3A)]),
          color: spinning ? kCard : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: MaterialButton(
          onPressed: spinning ? null : onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Text(
            spinning ? '확인 중...' : '폭탄 찾기!',
            style: GoogleFonts.notoSans(
              color: spinning ? kTextMuted : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
