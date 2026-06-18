import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';

class GameLobbyScreen extends StatefulWidget {
  final String gameType;
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final Color backgroundColor;
  final Widget gameScreen;

  const GameLobbyScreen({
    super.key,
    required this.gameType,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.backgroundColor,
    required this.gameScreen,
  });

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final _socket = SocketService();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onSocket);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _socket.joinGameLobby(widget.gameType);
    });
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    if (!_started) {
      _socket.leaveGameLobby(widget.gameType);
    }
    super.dispose();
  }

  void _onSocket() {
    if (!mounted) return;
    if (_socket.lobbyStartedGameType == widget.gameType && !_started) {
      _started = true;
      _socket.clearLobbyStart();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => widget.gameScreen));
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isHost =
        _socket.userId != null && _socket.userId == _socket.lobbyHost;
    final canStart = isHost && _socket.lobbyPlayers.length >= 2;

    return Scaffold(
      backgroundColor: kMainBg,
      body: SafeArea(
        child: CozyPage(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              children: [
                _Header(
                  emoji: widget.emoji,
                  title: widget.title,
                  description: widget.description,
                  color: widget.color,
                  backgroundColor: widget.backgroundColor,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: Center(
                    child: MainCard(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            color: widget.color,
                            size: 28,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _PlayerSlot(
                                  index: 0,
                                  color: widget.color,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _PlayerSlot(
                                  index: 1,
                                  color: widget.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          if (isHost)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: canStart
                                    ? () => _socket.startGameLobby(
                                        widget.gameType,
                                      )
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: kMainInk,
                                  disabledBackgroundColor: kMainLine,
                                  foregroundColor: kMainPaper,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  canStart ? '게임 시작' : '상대방을 기다리는 중',
                                  style: mainBody(
                                    size: 15,
                                    color: canStart ? kMainPaper : kMainMuted,
                                    weight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            )
                          else
                            Text(
                              '방장이 게임을 시작할 때까지 기다려주세요',
                              textAlign: TextAlign.center,
                              style: mainBody(size: 14, color: kMainSub),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  '먼저 들어온 사람이 방장이 됩니다',
                  style: mainBody(size: 12, color: kMainMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onBack;

  const _Header({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.backgroundColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: kMainInk,
            ),
          ),
          DoodleBadge(
            color: color,
            backgroundColor: backgroundColor,
            size: 54,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: mainTitle(size: 28)),
                const SizedBox(height: 2),
                Text(description, style: mainBody(size: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final int index;
  final Color color;

  const _PlayerSlot({required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    final socket = SocketService();
    final player = index < socket.lobbyPlayers.length
        ? socket.lobbyPlayers[index]
        : null;
    final isHost = player != null && player == socket.lobbyHost;
    final emoji = player == null
        ? '…'
        : socket.profileEmojis[player] ?? SocketService.defaultProfileEmoji;

    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: player == null ? kMainPaperSoft : color.withAlpha(32),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: player == null ? kMainLine : color.withAlpha(150),
                    width: player == null ? 1 : 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: player == null ? 24 : 38,
                      color: kMainMuted,
                    ),
                  ),
                ),
              ),
              if (isHost)
                Positioned(
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: kMainHoneySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: kMainHoney,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          player ?? '비어 있음',
          textAlign: TextAlign.center,
          style: mainBody(
            size: 14,
            color: player == null ? kMainMuted : kMainInk,
            weight: player == null ? FontWeight.w500 : FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
