import 'package:flutter/material.dart';

import '../../core/game_sfx/game_sfx.dart';
import '../../core/socket_service.dart';
import 'game_theme.dart';

/// 서버 허용 목록과 같아야 한다(services/realtime-server/src/games/reaction.js).
const kReactionEmojis = ['😏', '😅', '😱', '🤞', '😭', '😎'];

/// 접혀 있다가 누르면 펼쳐지는 이모지 리액션 버튼. 게임 조작부를 가리지 않게 작다.
class ReactionButton extends StatefulWidget {
  final GameTheme theme;
  final String gameType;

  const ReactionButton({
    super.key,
    required this.theme,
    required this.gameType,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: t.dark ? 0.75 : 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_open)
            for (final e in kReactionEmojis)
              _EmojiTap(
                emoji: e,
                onTap: () {
                  SocketService().sendReaction(e, gameType: widget.gameType);
                  GameSfx.instance.play(GameSound.pop);
                  setState(() => _open = false);
                },
              ),
          Semantics(
            button: true,
            label: _open ? '리액션 닫기' : '리액션 보내기',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _open = !_open),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: _open
                      ? Icon(Icons.close_rounded, size: 18, color: t.ink)
                      : const Text('😊', style: TextStyle(fontSize: 19)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiTap extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiTap({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$emoji 보내기',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}

/// 받은 리액션을 플레이어 쪽에 말풍선으로 3초간 띄운다.
/// [forPlayer]가 보낸 리액션만 보여 준다.
class ReactionBubble extends StatefulWidget {
  final GameTheme theme;
  final String? forPlayer;
  final String gameType;

  const ReactionBubble({
    super.key,
    required this.theme,
    required this.forPlayer,
    required this.gameType,
  });

  @override
  State<ReactionBubble> createState() => _ReactionBubbleState();
}

class _ReactionBubbleState extends State<ReactionBubble> {
  final _socket = SocketService();
  int? _shownAt;
  String? _emoji;

  @override
  void initState() {
    super.initState();
    // 화면에 들어오기 전 받은 리액션은 다시 띄우지 않는다.
    _shownAt = _socket.lastReaction?.at;
    _socket.addListener(_onSocket);
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    super.dispose();
  }

  void _onSocket() {
    final r = _socket.lastReaction;
    if (r == null || r.at == _shownAt || r.by != widget.forPlayer) return;
    if (r.gameType != null && r.gameType != widget.gameType) return;
    _shownAt = r.at;
    if (r.by != _socket.userId) GameSfx.instance.play(GameSound.pop);
    setState(() => _emoji = r.emoji);
    final at = r.at;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _shownAt == at) setState(() => _emoji = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
          child: child,
        ),
        child: _emoji == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Container(
                key: ValueKey(_shownAt),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: t.dark ? Colors.white : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.gold.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(_emoji!, style: const TextStyle(fontSize: 26)),
              ),
      ),
    );
  }
}
