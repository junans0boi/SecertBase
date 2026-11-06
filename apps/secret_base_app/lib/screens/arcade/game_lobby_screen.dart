import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import '../../core/yut_audio.dart';
import '../../widgets/play_kit/play_kit.dart';
import 'games/catch/catch_lobby.dart';
import 'games/catch/catch_screen.dart' show kCatchHowToLines;
import 'games/gostop/gostop_lobby.dart';
import 'games/gostop/gostop_panels.dart' show gostopHowToLines;
import 'games/penalty/penalty_lobby.dart';
import 'games/penalty/penalty_models.dart';
import 'games/onecard/onecard_lobby.dart';
import 'games/pirate/pirate_game_screen.dart' show kPirateHowToLines;
import 'games/pirate/pirate_lobby.dart';
import 'games/telepathy/telepathy_lobby.dart';
import 'game_lobby_themed.dart';
import 'games/yut/yut_figures.dart';
import 'games/yut/yut_lobby_view.dart';
import 'games/zero/zero_lobby.dart';
import 'games/zero/zero_screen.dart' show kZeroHowToLines;
import 'lobby_kit.dart';
import 'lobby_options.dart';

const _kStakeOptions = [0, 500, 1000, 3000];
const _kGostopStakeOptions = [0, 100, 500, 1000];

/// 판돈을 실제로 정산하는 게임. 서버 STAKE_GAME_TYPES와 같아야 한다.
const kStakeGameTypes = {'yut', 'uno', 'tank', 'gostop'};

class GameLobbyScreen extends StatefulWidget {
  final String gameType;
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final Color backgroundColor;
  final Widget gameScreen;
  // Injectable for tests: replaces the default SocketService.joinGameLobby call.
  final void Function(String gameType)? onJoinLobby;

  const GameLobbyScreen({
    super.key,
    required this.gameType,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.backgroundColor,
    required this.gameScreen,
    this.onJoinLobby,
  });

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final _socket = SocketService();
  bool _started = false;
  int _countdown = 0;
  String? _startedYutBgm;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onSocket);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (widget.onJoinLobby ?? _socket.joinGameLobby)(widget.gameType);
      if (widget.gameType == 'marble') {
        _socket.fetchAndSelectMarbleCharacter();
      }
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
    // Resume path: partner's active game detected — navigate without countdown.
    if (_socket.lobbyResumedGameType == widget.gameType && !_started) {
      _started = true;
      _socket.clearLobbyResume();
      _launchGame(resumed: true);
      return;
    }
    // Normal lobby start path.
    if (_socket.lobbyStartedGameType == widget.gameType && !_started) {
      _started = true;
      _startedYutBgm = _socket.lobbyStartedYutBgm;
      _socket.clearLobbyStart();
      _beginCountdown();
      return;
    }
    setState(() {});
  }

  void _beginCountdown() {
    setState(() => _countdown = 5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _launchGame();
      }
    });
  }

  void _launchGame({bool resumed = false}) {
    final isHost = _socket.userId == _socket.lobbyHost;
    if (!resumed && widget.gameType == 'yut') {
      YutAudio.instance.playGameStart(bgm: _startedYutBgm);
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => widget.gameScreen));
    // On resume the game is already running on the server — do not create a new game.
    // 게임 2.0 모듈은 서버가 이미 판을 만들었다(serverStart).
    if (!resumed && isHost && !_socket.lobbyStartedServerStart) {
      Future.delayed(const Duration(milliseconds: 300), () {
        switch (widget.gameType) {
          case 'yut':
            _socket.newYutGame(
              bgm: _startedYutBgm,
              stake: _socket.lobbyStartedStake,
            );
            break;
          case 'marble':
            _socket.newMarbleGame(
              characters: Map<String, String>.from(
                _socket.lobbyCharacterSelections,
              ),
            );
            break;
          case 'bomb':
            _socket.newBombGame();
            break;
          case 'uno':
            _socket.newUnoGame(
              mode: _socket.selectedUnoMode,
              stake: _socket.lobbyStartedStake,
            );
            break;
          case 'blackjack':
            _socket.startBlackjack();
            break;
          case 'oldmaid':
            _socket.startOldMaid();
            break;
          case 'penalty':
            _socket.startPenalty();
            break;
          case 'bowling':
            _socket.startBowling();
            break;
          case 'tank':
            _socket.startTank();
            break;
          case 'gostop':
            _socket.startGostop(perPointBet: _socket.lobbyStartedStake);
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost =
        _socket.userId != null && _socket.userId == _socket.lobbyHost;
    final hasTwoPlayers = _socket.lobbyPlayers.length >= 2;
    final usesStake = kStakeGameTypes.contains(widget.gameType);
    // 텔레파시 19+ 수위: 상대(비방장)가 직접 동의해야 시작할 수 있다.
    final adultHeat =
        widget.gameType == 'telepathy' &&
        _socket.lobbyOptions['heat'] == 'nuclear';
    // 판돈이 걸린 판은 상대(비방장)가 금액에 동의해야 시작할 수 있다.
    final needsReady = (usesStake && _socket.lobbyStake > 0) || adultHeat;
    final partnersReady = _socket.lobbyPlayers
        .where((p) => p != _socket.lobbyHost)
        .every((p) => _socket.lobbyReady[p] == true);
    final canStart = isHost && hasTwoPlayers && (!needsReady || partnersReady);

    final startLabel = canStart
        ? (widget.gameType == 'telepathy' ? '시작하기' : '게임 시작')
        : (hasTwoPlayers && needsReady && !partnersReady)
        ? (adultHeat ? '상대의 동의를 기다리는 중' : '상대의 판돈 동의를 기다리는 중')
        : '상대방을 기다리는 중';

    // 시안이 있는 게임(블랙잭·도둑잡기)은 모던 로비로 그린다.
    final themed = themedLobbySpecFor(widget.gameType);
    if (themed != null) {
      return Stack(
        children: [
          ThemedLobbyView(
            spec: themed,
            gameType: widget.gameType,
            players: List<String>.from(_socket.lobbyPlayers),
            host: _socket.lobbyHost,
            myId: _socket.userId,
            nicknames: Map<String, String>.from(_socket.presenceNicknames),
            isHost: isHost,
            canStart: canStart,
            startLabel: startLabel,
            onStart: () => _socket.startGameLobby(widget.gameType),
            onBack: () => Navigator.of(context).pop(),
          ),
          if (_countdown > 0)
            ThemedCountdown(theme: themed.theme, seconds: _countdown),
        ],
      );
    }

    if (widget.gameType == 'telepathy') {
      final others = _socket.lobbyPlayers.where((p) => p != _socket.userId);
      final partner = others.isEmpty ? null : others.first;
      String nameOf(String? id) {
        final n = id == null ? '' : _socket.nameOf(id);
        return n.isEmpty || n == id ? (id == _socket.userId ? '나' : '상대') : n;
      }

      return Stack(
        children: [
          TelepathyLobbyView(
            isHost: isHost,
            hasTwoPlayers: hasTwoPlayers,
            myName: nameOf(_socket.userId),
            partnerName: nameOf(partner),
            rounds: (_socket.lobbyOptions['rounds'] as num?)?.toInt() ?? 10,
            heat: '${_socket.lobbyOptions['heat'] ?? 'mild'}',
            partnerAccepted: partnersReady && hasTwoPlayers,
            iAccepted: _socket.lobbyReady[_socket.userId ?? ''] == true,
            canStart: canStart,
            startLabel: startLabel,
            onBack: () => Navigator.of(context).pop(),
            onRounds: (v) => _socket.setLobbyOption('telepathy', 'rounds', v),
            onHeat: (v) => _socket.setLobbyOption('telepathy', 'heat', v),
            onStart: () => _socket.startGameLobby('telepathy'),
            onAccept: (v) => _socket.setLobbyReady('telepathy', v),
          ),
          if (_countdown > 0) _buildCountdownOverlay(),
        ],
      );
    }

    // 해적 룰렛·제로·그림 맞히기·고스톱은 게임마다 전용 대기실을 쓴다(상태·동작은 아래와 같다).
    final game = _gameLobby(
      isHost: isHost,
      canStart: canStart,
      startLabel: startLabel,
    );
    if (game != null) {
      return Stack(
        children: [
          game.view,
          if (_countdown > 0)
            LobbyCountdown(palette: game.palette, seconds: _countdown),
        ],
      );
    }

    return Stack(
      children: [
        _buildScaffold(
          isHost: isHost,
          canStart: canStart,
          startLabel: startLabel,
        ),
        if (_countdown > 0) _buildCountdownOverlay(),
      ],
    );
  }

  ({Widget view, LobbyPalette palette})? _gameLobby({
    required bool isHost,
    required bool canStart,
    required String startLabel,
  }) {
    final type = widget.gameType;
    if (!const {'pirate', 'zero', 'catch', 'gostop'}.contains(type)) {
      return null;
    }
    final players = List<String>.from(_socket.lobbyPlayers);
    final nicknames = Map<String, String>.from(_socket.presenceNicknames);
    void onBack() => Navigator.of(context).pop();
    void onStart() => _socket.startGameLobby(type);
    return switch (type) {
      'pirate' => (
        palette: kPirateLobbyPalette,
        view: PirateLobbyView(
          holesDef: lobbyOptionsFor('pirate').single,
          holesValue: _socket.lobbyOptions['holes'],
          players: players,
          host: _socket.lobbyHost,
          me: _socket.userId,
          nicknames: nicknames,
          isHost: isHost,
          canStart: canStart,
          startLabel: startLabel,
          onHoles: (v) => _socket.setLobbyOption(type, 'holes', v),
          onStart: onStart,
          onBack: onBack,
          onHelp: () => showLobbyHowTo(
            context,
            palette: kPirateLobbyPalette,
            title: '해적 룰렛',
            lines: kPirateHowToLines,
          ),
        ),
      ),
      'zero' => (
        palette: kZeroLobbyPalette,
        view: ZeroLobbyView(
          players: players,
          host: _socket.lobbyHost,
          me: _socket.userId,
          nicknames: nicknames,
          isHost: isHost,
          canStart: canStart,
          startLabel: startLabel,
          onStart: onStart,
          onBack: onBack,
          onHelp: () => showLobbyHowTo(
            context,
            palette: kZeroLobbyPalette,
            title: '제로 규칙',
            lines: kZeroHowToLines,
          ),
        ),
      ),
      'catch' => (
        palette: kCatchLobbyPalette,
        view: CatchLobbyView(
          roundsDef: lobbyOptionsFor('catch').single,
          roundsValue: _socket.lobbyOptions['rounds'],
          players: players,
          host: _socket.lobbyHost,
          me: _socket.userId,
          nicknames: nicknames,
          isHost: isHost,
          canStart: canStart,
          startLabel: startLabel,
          onRounds: (v) => _socket.setLobbyOption(type, 'rounds', v),
          onStart: onStart,
          onBack: onBack,
          onHelp: () => showLobbyHowTo(
            context,
            palette: kCatchLobbyPalette,
            title: '그림 맞히기 규칙',
            lines: kCatchHowToLines,
          ),
        ),
      ),
      _ => (
        palette: kGostopLobbyPalette,
        view: GostopLobbyView(
          players: players,
          host: _socket.lobbyHost,
          me: _socket.userId,
          nicknames: nicknames,
          ready: _socket.lobbyReady,
          stake: _socket.lobbyStake,
          stakeOptions: _kGostopStakeOptions,
          isHost: isHost,
          canStart: canStart,
          startLabel: startLabel,
          onStake: (stake) => _socket.setLobbyStake(type, stake),
          onReady: (ready) => _socket.setLobbyReady(type, ready),
          onStart: onStart,
          onBack: onBack,
          onHelp: () => showLobbyHowTo(
            context,
            palette: kGostopLobbyPalette,
            title: '고스톱 (맞고)',
            lines: gostopHowToLines,
          ),
        ),
      ),
    };
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

  Widget _buildScaffold({
    required bool isHost,
    required bool canStart,
    required String startLabel,
  }) {
    if (widget.gameType == 'yut') {
      return YutLobbyView(
        socket: _socket,
        isHost: isHost,
        canStart: canStart,
        startLabel: startLabel,
        onStart: () => _socket.startGameLobby(widget.gameType),
        onBack: () => Navigator.of(context).pop(),
      );
    }
    final lobbyPlayers = List<String>.from(_socket.lobbyPlayers);
    final profileEmojis = Map<String, String>.from(_socket.profileEmojis);
    final nicknames = Map<String, String>.from(_socket.presenceNicknames);

    // 패널티킥은 목업 디자인(야간 방송)의 전용 대기방 화면을 쓴다. 동작은 아래와 같다.
    if (widget.gameType == 'penalty') {
      return PenaltyLobbyView(
        cellsDef: lobbyOptionsFor('penalty').single,
        cellsValue: _socket.lobbyOptions['cells'],
        myId: _socket.userId,
        hostId: _socket.lobbyHost,
        players: lobbyPlayers,
        nicknames: nicknames,
        emojis: profileEmojis,
        isHost: isHost,
        canStart: canStart,
        startLabel: startLabel,
        onSelectCells: (value) =>
            _socket.setLobbyOption(widget.gameType, 'cells', value),
        onStart: () => _socket.startGameLobby(widget.gameType),
        onBack: () => Navigator.of(context).pop(),
        onHelp: () => showGameHowTo(
          context,
          theme: GameTheme.sunsetStadium,
          title: kPenaltyHowToTitle,
          lines: kPenaltyHowToLines,
          emoji: '⚽',
        ),
      );
    }

    // 원카드는 쇼타임 디자인의 전용 대기실을 쓴다(상태·동작은 이 화면 그대로).
    if (widget.gameType == 'uno') {
      return OneCardLobby(
        players: lobbyPlayers,
        host: _socket.lobbyHost,
        me: _socket.userId,
        nicknames: nicknames,
        ready: _socket.lobbyReady,
        stake: _socket.lobbyStake,
        mode: '${_socket.lobbyOptions['mode'] ?? 'go_wild'}',
        isHost: isHost,
        canStart: canStart,
        startLabel: startLabel,
        stakeOptions: _kStakeOptions,
        onBack: () => Navigator.of(context).pop(),
        onStart: () => _socket.startGameLobby(widget.gameType),
        onStake: (stake) => _socket.setLobbyStake(widget.gameType, stake),
        onMode: (mode) => _socket.setLobbyOption(widget.gameType, 'mode', mode),
        onReady: (ready) => _socket.setLobbyReady(widget.gameType, ready),
      );
    }

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
                    child: SingleChildScrollView(
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
                                    players: lobbyPlayers,
                                    host: _socket.lobbyHost,
                                    profileEmojis: profileEmojis,
                                    nicknames: nicknames,
                                    characters: widget.gameType == 'yut'
                                        ? _socket.lobbyCharacterSelections
                                        : const {},
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _PlayerSlot(
                                    index: 1,
                                    color: widget.color,
                                    players: lobbyPlayers,
                                    host: _socket.lobbyHost,
                                    profileEmojis: profileEmojis,
                                    nicknames: nicknames,
                                    characters: widget.gameType == 'yut'
                                        ? _socket.lobbyCharacterSelections
                                        : const {},
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            for (final def in lobbyOptionsFor(
                              widget.gameType,
                            )) ...[
                              LobbyOptionPicker(
                                def: def,
                                isHost: isHost,
                                value: _socket.lobbyOptions[def.key],
                                color: widget.color,
                                onSelect: (value) => _socket.setLobbyOption(
                                  widget.gameType,
                                  def.key,
                                  value,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (kStakeGameTypes.contains(widget.gameType)) ...[
                              _StakeSelector(
                                gameType: widget.gameType,
                                isHost: isHost,
                                stake: _socket.lobbyStake,
                                color: widget.color,
                              ),
                              const SizedBox(height: 18),
                            ],
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
                                    startLabel,
                                    style: mainBody(
                                      size: 15,
                                      color: canStart ? kMainPaper : kMainMuted,
                                      weight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              )
                            else if (kStakeGameTypes.contains(
                                  widget.gameType,
                                ) &&
                                _socket.lobbyStake > 0)
                              _ReadyButton(
                                ready:
                                    _socket.lobbyReady[_socket.userId ?? ''] ==
                                    true,
                                stake: _socket.lobbyStake,
                                color: widget.color,
                                onChanged: (ready) => _socket.setLobbyReady(
                                  widget.gameType,
                                  ready,
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

/// 비방장의 판돈 동의 버튼. 방장이 금액을 바꾸면 서버가 동의를 초기화한다.
class _ReadyButton extends StatelessWidget {
  final bool ready;
  final int stake;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _ReadyButton({
    required this.ready,
    required this.stake,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          ready
              ? '$stake코인 판돈에 동의했어요. 방장이 시작하면 바로 시작돼요.'
              : '이 판에는 $stake코인이 걸려 있어요. 동의하면 준비 완료를 눌러 주세요.',
          textAlign: TextAlign.center,
          style: mainBody(size: 13, color: kMainSub),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => onChanged(!ready),
            style: OutlinedButton.styleFrom(
              foregroundColor: ready ? kMainPaper : color,
              backgroundColor: ready ? color : Colors.transparent,
              side: BorderSide(color: color, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              ready ? '준비 완료 취소' : '준비 완료',
              style: mainBody(
                size: 15,
                color: ready ? kMainPaper : color,
                weight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
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
  final List<String> players;
  final String? host;
  final Map<String, String> profileEmojis;
  final Map<String, String> nicknames;

  /// 고른 캐릭터(윷놀이). 있으면 프로필 이모지 대신 그 캐릭터 얼굴을 보여 준다.
  final Map<String, String> characters;

  const _PlayerSlot({
    required this.index,
    required this.color,
    required this.players,
    required this.host,
    required this.profileEmojis,
    required this.nicknames,
    this.characters = const {},
  });

  @override
  Widget build(BuildContext context) {
    final player = index < players.length ? players[index] : null;
    final isHost = player != null && player == host;
    final emoji = player == null
        ? '…'
        : profileEmojis[player] ?? SocketService.defaultProfileEmoji;

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
                  child: player != null && characters[player] != null
                      ? YutCharacterAvatar(
                          character: characters[player]!,
                          size: 76,
                        )
                      : Text(
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
          player == null ? '비어 있음' : (nicknames[player] ?? player),
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

class _StakeSelector extends StatelessWidget {
  final String gameType;
  final bool isHost;
  final int stake;
  final Color color;

  const _StakeSelector({
    required this.gameType,
    required this.isHost,
    required this.stake,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final socket = SocketService();
    final options = gameType == 'gostop'
        ? _kGostopStakeOptions
        : _kStakeOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🪙', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              '판돈',
              style: mainBody(
                size: 13,
                color: kMainInk,
                weight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isHost ? '방장이 선택' : '방장이 선택한 금액',
              style: mainBody(size: 11, color: kMainMuted, height: 1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: options.map((option) {
            final selected = stake == option;
            final label = option == 0 ? '무료' : '$option코인';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: option == options.last ? 0 : 8),
                child: GestureDetector(
                  onTap: isHost
                      ? () => socket.setLobbyStake(gameType, option)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.12)
                          : kMainPaperSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : kMainLine,
                        width: selected ? 1.8 : 1,
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: selected ? color : kMainSub,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 로비 옵션 선택. 방장은 고르고, 상대는 방장이 고른 값을 읽기 전용으로 본다.
class LobbyOptionPicker extends StatelessWidget {
  final LobbyOptionDef def;
  final bool isHost;
  final Object? value;
  final Color color;
  final ValueChanged<Object> onSelect;

  const LobbyOptionPicker({
    super.key,
    required this.def,
    required this.isHost,
    required this.value,
    required this.color,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final current = def.choiceFor(value).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(def.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              def.title,
              style: mainBody(
                size: 13,
                color: kMainInk,
                weight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isHost ? '방장이 선택' : '방장이 고른 설정',
              style: mainBody(size: 11, color: kMainMuted, height: 1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final choice in def.choices)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: choice == def.choices.last ? 0 : 8,
                  ),
                  child: _LobbyChoiceTile(
                    choice: choice,
                    selected: choice.value == current,
                    enabled: isHost,
                    color: color,
                    onTap: () => onSelect(choice.value),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LobbyChoiceTile extends StatelessWidget {
  final LobbyChoice choice;
  final bool selected;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _LobbyChoiceTile({
    required this.choice,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 비방장에게는 고르지 않은 선택지를 흐리게 보여 "방장이 이걸 골랐다"가 바로 보이게 한다.
    final dimmed = !enabled && !selected;
    return Semantics(
      button: enabled,
      selected: selected,
      label: '${choice.label}, ${choice.description}',
      child: GestureDetector(
        onTap: enabled && !selected ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: dimmed ? 0.45 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : kMainPaperSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : kMainLine,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  choice.label,
                  textAlign: TextAlign.center,
                  style: mainBody(
                    size: 14,
                    color: selected ? color : kMainInk,
                    weight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  choice.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: mainBody(size: 10.5, color: kMainSub, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
