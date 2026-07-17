import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class TelepathyScreen extends StatefulWidget {
  const TelepathyScreen({super.key});

  @override
  State<TelepathyScreen> createState() => _TelepathyScreenState();
}

class _TelepathyScreenState extends State<TelepathyScreen> {
  final _socket = SocketService();
  String? _myChoice;
  bool _waiting = false;

  final _options = ['치킨 🍗', '피자 🍕', '족발 🐷', '회 🐟', '떡볶이 🌶️', '라면 🍜'];

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
    setState(() {
      _waiting = _socket.telepathySuccess == null && _myChoice != null;
    });
  }

  void _pick(String opt) {
    if (_waiting) return;
    setState(() {
      _myChoice = opt;
      _waiting = true;
    });
    _socket.playTelepathy(opt, _options);
  }

  void _reset() {
    setState(() {
      _myChoice = null;
      _waiting = false;
    });
    _socket.telepathySuccess = null;
    _socket.telepathySelected = null;
    _socket.telepathyChoices = null;
  }

  @override
  Widget build(BuildContext context) {
    final success = _socket.telepathySuccess;
    final selected = _socket.telepathySelected;
    final choices = _socket.telepathyChoices;

    return GameScaffold(
      title: '🧠 텔레파시',
      actions: [const GameMenuButton()],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (success != null) ...[
              _buildResult(success, selected, choices),
              const SizedBox(height: 32),
              _ResetBtn(onTap: _reset),
            ] else if (_waiting) ...[
              const _WaitWidget(),
              const SizedBox(height: 20),
              if (_myChoice != null)
                Text(
                  '내 선택: $_myChoice',
                  style: GoogleFonts.notoSans(
                    color: kPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ] else ...[
              Text(
                '같은 걸 고르면 텔레파시 성공!',
                style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildGrid(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: _options.map((opt) {
        return GestureDetector(
          onTap: () => _pick(opt),
          child: Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Center(
              child: Text(
                opt,
                style: GoogleFonts.notoSans(
                  color: kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResult(
    bool success,
    String? selected,
    Map<String, String>? choices,
  ) {
    return Column(
      children: [
        Text(success ? '✨' : '💔', style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 12),
        Text(
          success ? '텔레파시 성공!' : '아쉽게 실패...',
          style: GoogleFonts.notoSans(
            color: success ? kSuccess : kError,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (success && selected != null) ...[
          const SizedBox(height: 8),
          Text(
            '둘 다 "$selected" 선택!',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 15),
          ),
        ] else if (!success && choices != null) ...[
          const SizedBox(height: 16),
          ...choices.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${e.key}: ${e.value}',
                style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WaitWidget extends StatelessWidget {
  const _WaitWidget();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary),
        ),
        const SizedBox(height: 16),
        Text(
          '상대방 선택 대기 중...',
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16),
        ),
      ],
    );
  }
}

class _ResetBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('다시 하기'),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
