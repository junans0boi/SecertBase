import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class RpsScreen extends StatefulWidget {
  const RpsScreen({super.key});

  @override
  State<RpsScreen> createState() => _RpsScreenState();
}

class _RpsScreenState extends State<RpsScreen> {
  final _socket = SocketService();
  String? _myChoice;
  bool _waiting = false;

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
      _waiting = _socket.rpsResult == null && _myChoice != null;
    });
  }

  void _pick(String choice) {
    if (_waiting) return;
    setState(() {
      _myChoice = choice;
      _waiting = true;
    });
    _socket.playRps(choice);
  }

  void _reset() {
    setState(() {
      _myChoice = null;
      _waiting = false;
    });
    _socket.rpsResult = null;
    _socket.rpsChoices = null;
  }

  static const _choices = [
    ('rock', '✊', '바위'),
    ('scissors', '✌️', '가위'),
    ('paper', '✋', '보'),
  ];

  static const _resultLabels = {
    'win': ('🎉 승리!', kSuccess),
    'lose': ('😢 패배', kError),
    'draw': ('🤝 무승부', kGold),
  };

  @override
  Widget build(BuildContext context) {
    final result = _socket.rpsResult;
    final choices = _socket.rpsChoices;
    final userId = _socket.userId;

    return GameScaffold(
      title: '✊ 가위바위보',
      actions: [const GameMenuButton()],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (result != null && choices != null) ...[
              _buildReveal(result, choices, userId),
              const SizedBox(height: 32),
              _ResetButton(onTap: _reset),
            ] else if (_waiting) ...[
              const _WaitingWidget(),
            ] else ...[
              Text(
                '선택하세요',
                style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16),
              ),
              const SizedBox(height: 40),
              _buildChoiceRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _choices.map((c) {
        final (key, emoji, label) = c;
        final selected = _myChoice == key;
        return GestureDetector(
          onTap: () => _pick(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: selected ? kPrimary.withOpacity(0.2) : kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? kPrimary : kBorder,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: kPrimary.withOpacity(0.25), blurRadius: 16)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReveal(String result, Map<String, String> choices, String? userId) {
    final (label, color) = _resultLabels[result] ?? ('?', kTextMuted);

    final emojiMap = {'rock': '✊', 'scissors': '✌️', 'paper': '✋'};
    final myKey = userId ?? '';
    final opponentKey = choices.keys.firstWhere((k) => k != myKey, orElse: () => '');
    final myEmoji = emojiMap[choices[myKey] ?? ''] ?? '?';
    final opEmoji = emojiMap[choices[opponentKey] ?? ''] ?? '?';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            label,
            style: GoogleFonts.notoSans(color: color, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PlayerHand(name: myKey.isEmpty ? '나' : myKey, emoji: myEmoji, isMe: true),
            Text('vs', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 18)),
            _PlayerHand(name: opponentKey.isEmpty ? '상대' : opponentKey, emoji: opEmoji, isMe: false),
          ],
        ),
      ],
    );
  }
}

class _PlayerHand extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isMe;
  const _PlayerHand({required this.name, required this.emoji, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 60)),
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.notoSans(
            color: isMe ? kPrimary : kAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _WaitingWidget extends StatelessWidget {
  const _WaitingWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary),
        ),
        const SizedBox(height: 20),
        Text(
          '상대방 선택 대기 중...',
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16),
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetButton({required this.onTap});

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
