import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import '../../core/uno_audio.dart';

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
  int _countdown = 0;
  Timer? _countdownTimer;

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
    _countdownTimer?.cancel();
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
      _beginCountdown();
      return;
    }
    setState(() {});
  }

  void _beginCountdown() {
    if (widget.gameType == 'uno') {
      // Unlock audio on first interaction before countdown
      UnoAudio.instance.unlock();
    }
    setState(() => _countdown = 5);
    UnoAudio.instance.countdownBeep(5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        UnoAudio.instance.countdownEnd();
        _launchGame();
      } else {
        UnoAudio.instance.countdownBeep(_countdown);
      }
    });
  }

  void _launchGame() {
    final isHost = _socket.userId == _socket.lobbyHost;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.gameScreen),
    );
    if (isHost) {
      Future.delayed(const Duration(milliseconds: 300), () {
        switch (widget.gameType) {
          case 'uno': _socket.newUnoGame(); break;
          case 'yut': _socket.newYutGame(); break;
          case 'bomb': _socket.newBombGame(); break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost =
        _socket.userId != null && _socket.userId == _socket.lobbyHost;
    final canStart = isHost && _socket.lobbyPlayers.length >= 2;

    return Stack(
      children: [
        _buildScaffold(isHost: isHost, canStart: canStart),
        if (_countdown > 0) _buildCountdownOverlay(),
      ],
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_countdown',
                  style: mainTitle(size: 96, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  '게임 시작!',
                  style: mainBody(
                    size: 22,
                    color: Colors.white70,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold({required bool isHost, required bool canStart}) {
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
