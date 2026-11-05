import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin {
  final _socket = SocketService();
  late AnimationController _spinCtrl;
  late Animation<double> _spin;
  bool _spinning = false;
  int _seenSeq = 0;
  double _turns = 3; // 서버가 고른 칸이 위쪽 포인터에 오도록 계산한 총 회전 수

  final List<String> _options = ['야식', '벌칙', '결제자', '면제권', '산책', '게임'];
  final _editCtrl = TextEditingController();

  static const _colors = [
    kPrimary,
    kAccent,
    kGold,
    kTeal,
    Color(0xFF5DADE2),
    Color(0xFFFF6348),
  ];

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _spin = CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOut);
    _seenSeq = _socket.rouletteSeq;
    _socket.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _propose());
  }

  void _propose() => _socket.proposeRoulette(List<String>.from(_options));

  @override
  void dispose() {
    _spinCtrl.dispose();
    _editCtrl.dispose();
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    // 새 결과가 왔을 때만 돈다(다른 알림마다 휠이 다시 돌거나 항목이 되돌아가지 않게).
    if (_socket.rouletteSeq == _seenSeq) {
      setState(() {});
      return;
    }
    _seenSeq = _socket.rouletteSeq;
    final opts = _socket.lastRouletteOptions;
    final index = _socket.lastRouletteIndex ?? 0;
    final count = (opts != null && opts.isNotEmpty)
        ? opts.length
        : _options.length;
    setState(() {
      _spinning = true;
      if (opts != null && opts.isNotEmpty) {
        _options
          ..clear()
          ..addAll(opts);
      }
      // 칸 i는 위쪽에서 시계 방향으로 i번째. 그 칸의 가운데가 위쪽 포인터에 오도록 회전한다.
      final segment = count == 0 ? 0.0 : (index + 0.5) / count;
      _turns = 3 + (1 - segment);
    });
    _spinCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _spinning = false);
    });
  }

  void _spin2() {
    if (_spinning) return;
    if (_options.length < 2 || _options.length > 12) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('항목은 2개 이상 12개 이하로 정해 주세요')));
      return;
    }
    _socket.spinRoulette(List<String>.from(_options));
  }

  void _addOption() {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    if (_options.length >= 12) return;
    setState(() {
      _options.add(text);
      _editCtrl.clear();
    });
    _propose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _socket.lastRoulette;
    return GameScaffold(
      title: '🎡 룰렛',
      actions: [const GameMenuButton()],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildWheel(result),
            const SizedBox(height: 24),
            if (result != null) _ResultCard(result: result),
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
    final wheel = AnimatedBuilder(
      animation: _spin,
      builder: (_, child) {
        return Transform.rotate(
          angle: _spin.value * 2 * pi * _turns,
          child: child,
        );
      },
      child: SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(painter: _WheelPainter(_options, _colors)),
      ),
    );
    // 위쪽 포인터: 멈춘 칸이 결과다.
    return SizedBox(
      width: 200,
      height: 222,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(top: 18, child: wheel),
          const Icon(Icons.arrow_drop_down_rounded, size: 40, color: kText),
        ],
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
            style: GoogleFonts.notoSans(
              color: kTextMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.asMap().entries.map((e) {
              final i = e.key;
              final opt = e.value;
              return GestureDetector(
                onLongPress: () {
                  setState(() => _options.removeAt(i));
                  _propose();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _colors[i % _colors.length].withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _colors[i % _colors.length].withValues(alpha: 0.4),
                    ),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
          colors: [
            kAccent.withValues(alpha: 0.15),
            kPrimary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '선택됨',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            result,
            style: GoogleFonts.notoSans(
              color: kText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
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
          gradient: spinning ? null : kPrimaryGrad,
          color: spinning ? kCard : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: spinning
              ? null
              : [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 16)],
        ),
        child: MaterialButton(
          onPressed: spinning ? null : onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
        ..color = colors[i % colors.length].withValues(alpha: 0.8)
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, textOffset - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.items != items;
}
