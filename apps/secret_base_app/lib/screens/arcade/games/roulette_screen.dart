import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> with SingleTickerProviderStateMixin {
  final _socket = SocketService();
  late AnimationController _spinCtrl;
  late Animation<double> _spin;
  bool _spinning = false;

  List<String> _options = ['야식', '벌칙', '결제자', '면제권', '산책', '게임'];
  final _editCtrl = TextEditingController();

  static const _colors = [kPrimary, kAccent, kGold, kTeal, Color(0xFF5DADE2), Color(0xFFFF6348)];

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _spin = CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOut);
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _editCtrl.dispose();
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() => _spinning = false);
    _spinCtrl.forward(from: 0);
  }

  void _spin2() {
    if (_spinning || _options.isEmpty) return;
    setState(() => _spinning = true);
    _socket.spinRoulette(_options);
  }

  void _addOption() {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _options.add(text);
      _editCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _socket.lastRoulette;
    return GameScaffold(
      title: '🎡 룰렛',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildWheel(result),
            const SizedBox(height: 24),
            if (result != null)
              _ResultCard(result: result),
            const SizedBox(height: 24),
            _buildOptions(),
            const SizedBox(height: 32),
            _SpinButton(spinning: _spinning, onTap: _spin2),
          ],
        ),
      ),
    );
  }

  Widget _buildWheel(String? result) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, child) {
        return Transform.rotate(
          angle: _spin.value * 2 * pi * 3,
          child: child,
        );
      },
      child: SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(painter: _WheelPainter(_options, _colors)),
      ),
    );
  }

  Widget _buildOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '항목 관리',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.asMap().entries.map((e) {
              final i = e.key;
              final opt = e.value;
              return GestureDetector(
                onLongPress: () => setState(() => _options.removeAt(i)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colors[i % _colors.length].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _colors[i % _colors.length].withOpacity(0.4)),
                  ),
                  child: Text(
                    opt,
                    style: GoogleFonts.notoSans(
                      color: _colors[i % _colors.length],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _editCtrl,
                  style: const TextStyle(color: kText, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '항목 추가',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addOption(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addOption,
                icon: const Icon(Icons.add_circle, color: kPrimary),
              ),
            ],
          ),
          Text(
            '항목을 길게 눌러 삭제',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kAccent.withOpacity(0.15), kPrimary.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('선택됨', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            result,
            style: GoogleFonts.notoSans(color: kText, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SpinButton extends StatelessWidget {
  final bool spinning;
  final VoidCallback onTap;
  const _SpinButton({required this.spinning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: spinning ? null : kAccentGrad,
          color: spinning ? kCard : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: spinning ? null : [BoxShadow(color: kAccent.withOpacity(0.3), blurRadius: 16)],
        ),
        child: MaterialButton(
          onPressed: spinning ? null : onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Text(
            spinning ? '돌리는 중...' : '돌리기!',
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

class _WheelPainter extends CustomPainter {
  final List<String> items;
  final List<Color> colors;
  _WheelPainter(this.items, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = 2 * pi / items.length;

    for (int i = 0; i < items.length; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep - pi / 2,
        sweep,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = kBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep - pi / 2,
        sweep,
        true,
        borderPaint,
      );

      final angle = i * sweep - pi / 2 + sweep / 2;
      final textRadius = radius * 0.65;
      final textOffset = Offset(
        center.dx + textRadius * cos(angle),
        center.dy + textRadius * sin(angle),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: items[i],
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, textOffset - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.items != items;
}
