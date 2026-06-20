import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/main_design.dart';
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

  // legacy single-round state
  String? _myChoice;
  bool _waiting = false;

  // multi-mode pick state
  bool _picked = false;
  int _hanaFingers = 0;
  int _hanaGuess = 0;

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
    // if round result arrived, reset pick state for next round
    if (_socket.rpsRoundWinner != null && _socket.rpsGameWinner == null) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            _picked = false;
            _hanaFingers = 0;
            _hanaGuess = 0;
          });
          _socket.clearRpsRound();
        }
      });
    }
    setState(() {
      _waiting = _socket.rpsResult == null && _myChoice != null;
    });
  }

  // ── Single-round legacy (mode selection 전) ──────────────────────────────

  void _legacyPick(String choice) {
    if (_waiting) return;
    setState(() {
      _myChoice = choice;
      _waiting = true;
    });
    _socket.playRps(choice);
  }

  void _legacyReset() {
    setState(() {
      _myChoice = null;
      _waiting = false;
    });
    _socket.rpsResult = null;
    _socket.rpsChoices = null;
  }

  // ── Multi-mode ───────────────────────────────────────────────────────────

  bool get _isHost =>
      _socket.userId != null && _socket.lobbyHost == _socket.userId;

  void _startMode(String mode) {
    _socket.startRpsGame(mode);
    setState(() {
      _picked = false;
    });
  }

  void _pickChoice(String choice) {
    if (_picked) return;
    setState(() => _picked = true);
    _socket.pickRps(choice);
  }

  void _submitHanabagi() {
    if (_picked) return;
    setState(() => _picked = true);
    _socket.pickHanabagi(_hanaFingers, _hanaGuess);
  }

  void _resetGame() => _socket.resetRpsGame();

  static const _choices = [
    ('rock', '✊', '바위'),
    ('scissors', '✌️', '가위'),
    ('paper', '✋', '보'),
  ];

  String _choiceEmoji(String? c) {
    final choice = _choices.firstWhere(
      (e) => e.$1 == c,
      orElse: () => ('', '?', ''),
    );
    return choice.$2;
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final mode = sock.rpsMode;
    final active = sock.rpsActive;
    final gameWinner = sock.rpsGameWinner;

    return GameScaffold(
      title: '✊ 가위바위보',
      actions: [const GameMenuButton()],
      child: LayoutBuilder(
        builder: (ctx, box) {
          final compact = box.maxWidth < 430;
          final pad = compact ? 16.0 : 24.0;

          // 1) 모드 미선택 상태 (구 단판 or 모드 선택 화면)
          if (mode == null && !active && gameWinner == null) {
            return _ModeSelectView(
              compact: compact,
              pad: pad,
              isHost: _isHost,
              onMode: _startMode,
              // legacy single-round state
              singleResult: sock.rpsResult,
              singleChoices: sock.rpsChoices,
              userId: sock.userId,
              singleWaiting: _waiting,
              myChoice: _myChoice,
              onLegacyPick: _legacyPick,
              onLegacyReset: _legacyReset,
            );
          }

          // 2) 게임 끝
          if (gameWinner != null) {
            return _GameOverView(
              compact: compact,
              pad: pad,
              gameWinner: gameWinner,
              userId: sock.userId,
              scores: sock.rpsScores,
              isHost: _isHost,
              onReset: _resetGame,
            );
          }

          // 3) 진행 중
          if (mode == 'rps3') {
            return _Rps3View(
              compact: compact,
              pad: pad,
              sock: sock,
              picked: _picked,
              roundWinner: sock.rpsRoundWinner,
              lastChoices: sock.rpsLastChoices,
              choiceEmoji: _choiceEmoji,
              onPick: _pickChoice,
              isHost: _isHost,
              onReset: _resetGame,
            );
          }
          if (mode == 'mukjippa') {
            return _MukjippaView(
              compact: compact,
              pad: pad,
              sock: sock,
              picked: _picked,
              roundWinner: sock.rpsRoundWinner,
              lastChoices: sock.rpsLastChoices,
              choiceEmoji: _choiceEmoji,
              onPick: _pickChoice,
              isHost: _isHost,
              onReset: _resetGame,
            );
          }
          if (mode == 'hanabagi') {
            return _HanabagiView(
              compact: compact,
              pad: pad,
              sock: sock,
              picked: _picked,
              fingers: _hanaFingers,
              guess: _hanaGuess,
              roundWinner: sock.rpsRoundWinner,
              lastFingers: sock.rpsLastFingers,
              lastGuesses: sock.rpsLastGuesses,
              lastTotal: sock.rpsLastTotal,
              onFingersChanged: (v) => setState(() => _hanaFingers = v),
              onGuessChanged: (v) => setState(() => _hanaGuess = v),
              onSubmit: _submitHanabagi,
              isHost: _isHost,
              onReset: _resetGame,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Selection View
// ─────────────────────────────────────────────────────────────────────────────

class _ModeSelectView extends StatelessWidget {
  final bool compact;
  final double pad;
  final bool isHost;
  final void Function(String) onMode;
  // legacy single-round
  final String? singleResult;
  final Map<String, String>? singleChoices;
  final String? userId;
  final bool singleWaiting;
  final String? myChoice;
  final void Function(String) onLegacyPick;
  final VoidCallback onLegacyReset;

  const _ModeSelectView({
    required this.compact,
    required this.pad,
    required this.isHost,
    required this.onMode,
    required this.singleResult,
    required this.singleChoices,
    required this.userId,
    required this.singleWaiting,
    required this.myChoice,
    required this.onLegacyPick,
    required this.onLegacyReset,
  });

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
    // If single-round result is showing, show that
    if (singleResult != null && singleChoices != null) {
      final (label, color) = _resultLabels[singleResult] ?? ('?', kTextMuted);
      final emojiMap = {'rock': '✊', 'scissors': '✌️', 'paper': '✋'};
      final myKey = userId ?? '';
      final opKey = singleChoices!.keys.firstWhere(
        (k) => k != myKey,
        orElse: () => '',
      );
      final myEmoji = emojiMap[singleChoices![myKey]] ?? '?';
      final opEmoji = emojiMap[singleChoices![opKey]] ?? '?';

      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                label,
                style: GoogleFonts.notoSans(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PlayerHand(
                  name: myKey.isEmpty ? '나' : (singleChoices != null ? SocketService().nameOf(myKey) : myKey),
                  emoji: myEmoji,
                  isMe: true,
                ),
                Text(
                  'vs',
                  style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 18),
                ),
                _PlayerHand(
                  name: opKey.isEmpty ? '상대' : (singleChoices != null ? SocketService().nameOf(opKey) : opKey),
                  emoji: opEmoji,
                  isMe: false,
                ),
              ],
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onLegacyReset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (singleWaiting) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary),
            ),
            SizedBox(height: 20),
            Text('상대방 선택 대기 중...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '게임 모드 선택',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w900,
              color: kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isHost ? '원하는 모드를 골라 게임을 시작하세요' : '방장이 게임 모드를 선택하는 중이에요',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (isHost) ...[
            _ModeCard(
              emoji: '✊',
              title: '가위바위보 3판선승',
              desc: '먼저 3번 이기면 승리! 무승부는 점수 없이 계속해요.',
              color: const Color(0xFF5C6BC0),
              onTap: () => onMode('rps3'),
              compact: compact,
            ),
            const SizedBox(height: 12),
            _ModeCard(
              emoji: '🀄',
              title: '묵찌빠',
              desc: '가위바위보로 공격자 결정 → 묵찌빠에서 같은 걸 내면 공격자 승!',
              color: const Color(0xFFE53935),
              onTap: () => onMode('mukjippa'),
              compact: compact,
            ),
            const SizedBox(height: 12),
            _ModeCard(
              emoji: '🖐️',
              title: '하나빼기',
              desc: '0~5 손가락을 동시에 내고 합계를 예측! 맞춘 사람이 먼저 3점이면 승리.',
              color: const Color(0xFF2E7D32),
              onTap: () => onMode('hanabagi'),
              compact: compact,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              '단판 가위바위보',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: kTextMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _choices.map((c) {
                final (key, emoji, label) = c;
                return GestureDetector(
                  onTap: () => onLegacyPick(key),
                  child: Container(
                    width: compact ? 80 : 96,
                    height: compact ? 80 : 96,
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          emoji,
                          style: TextStyle(fontSize: compact ? 30 : 36),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.notoSans(
                            color: kTextMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            // Guest - single round only
            const SizedBox(height: 8),
            Text(
              '단판 가위바위보',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: kTextMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _choices.map((c) {
                final (key, emoji, label) = c;
                return GestureDetector(
                  onTap: () => onLegacyPick(key),
                  child: Container(
                    width: compact ? 80 : 96,
                    height: compact ? 80 : 96,
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          emoji,
                          style: TextStyle(fontSize: compact ? 30 : 36),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.notoSans(
                            color: kTextMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: compact ? 30 : 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSans(
                      color: color,
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.notoSans(
                      color: kTextMuted,
                      fontSize: compact ? 11 : 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: color.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game Over View
// ─────────────────────────────────────────────────────────────────────────────

class _GameOverView extends StatelessWidget {
  final bool compact;
  final double pad;
  final String gameWinner;
  final String? userId;
  final Map<String, int> scores;
  final bool isHost;
  final VoidCallback onReset;

  const _GameOverView({
    required this.compact,
    required this.pad,
    required this.gameWinner,
    required this.userId,
    required this.scores,
    required this.isHost,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final iWon = gameWinner == userId;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            iWon ? '🎉 승리!' : '😢 패배',
            style: GoogleFonts.notoSans(
              fontSize: compact ? 36 : 44,
              fontWeight: FontWeight.w900,
              color: iWon ? kSuccess : kError,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            iWon ? '상대를 이겼어요!' : '상대에게 졌어요...',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 15),
          ),
          if (scores.isNotEmpty) ...[
            const SizedBox(height: 20),
            _ScoreRow(scores: scores, userId: userId, compact: compact),
          ],
          const SizedBox(height: 32),
          if (isHost)
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          else
            Text(
              '방장이 다시 시작하길 기다려요',
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RPS 3-Win View
// ─────────────────────────────────────────────────────────────────────────────

class _Rps3View extends StatelessWidget {
  final bool compact;
  final double pad;
  final SocketService sock;
  final bool picked;
  final String? roundWinner;
  final Map<String, String>? lastChoices;
  final String Function(String?) choiceEmoji;
  final void Function(String) onPick;
  final bool isHost;
  final VoidCallback onReset;

  const _Rps3View({
    required this.compact,
    required this.pad,
    required this.sock,
    required this.picked,
    required this.roundWinner,
    required this.lastChoices,
    required this.choiceEmoji,
    required this.onPick,
    required this.isHost,
    required this.onReset,
  });

  static const _choices = [
    ('rock', '✊', '바위'),
    ('scissors', '✌️', '가위'),
    ('paper', '✋', '보'),
  ];

  @override
  Widget build(BuildContext context) {
    final userId = sock.userId ?? '';
    final players = sock.rpsPlayers;
    final opId = players.firstWhere((p) => p != userId, orElse: () => '');
    final myScore = sock.rpsScores[userId] ?? 0;
    final opScore = sock.rpsScores[opId] ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        children: [
          // Score board
          _ScoreBoard(
            myScore: myScore,
            opScore: opScore,
            target: 3,
            compact: compact,
            myLabel: sock.nameOf(userId).isNotEmpty ? sock.nameOf(userId) : '나',
            opLabel: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
          ),
          const SizedBox(height: 20),

          // Round result flash
          if (roundWinner != null && lastChoices != null) ...[
            _RoundResultBanner(
              roundWinner: roundWinner!,
              userId: userId,
              myEmoji: choiceEmoji(lastChoices![userId]),
              opEmoji: choiceEmoji(lastChoices![opId]),
              compact: compact,
            ),
            const SizedBox(height: 16),
          ],

          // Pick row
          if (!picked && roundWinner == null) ...[
            Text(
              '선택하세요',
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 15),
            ),
            const SizedBox(height: 16),
            _ChoiceRow(choices: _choices, onPick: onPick, compact: compact),
          ] else if (picked && roundWinner == null) ...[
            const _WaitingWidget(),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 묵찌빠 View
// ─────────────────────────────────────────────────────────────────────────────

class _MukjippaView extends StatelessWidget {
  final bool compact;
  final double pad;
  final SocketService sock;
  final bool picked;
  final String? roundWinner;
  final Map<String, String>? lastChoices;
  final String Function(String?) choiceEmoji;
  final void Function(String) onPick;
  final bool isHost;
  final VoidCallback onReset;

  const _MukjippaView({
    required this.compact,
    required this.pad,
    required this.sock,
    required this.picked,
    required this.roundWinner,
    required this.lastChoices,
    required this.choiceEmoji,
    required this.onPick,
    required this.isHost,
    required this.onReset,
  });

  static const _choices = [
    ('rock', '✊', '묵'),
    ('scissors', '✌️', '찌'),
    ('paper', '✋', '빠'),
  ];

  @override
  Widget build(BuildContext context) {
    final userId = sock.userId ?? '';
    final players = sock.rpsPlayers;
    final opId = players.firstWhere((p) => p != userId, orElse: () => '상대');
    final phase = sock.rpsMukjippaPhase;
    final attacker = sock.rpsMukjippaAttacker;
    final iAmAttacker = attacker == userId;

    String phaseLabel;
    String phaseDesc;
    if (phase == 'determine') {
      phaseLabel = '가위바위보!';
      phaseDesc = '이긴 사람이 공격자가 돼요';
    } else {
      phaseLabel = '묵찌빠!';
      phaseDesc = iAmAttacker
          ? '나는 공격자! 상대와 같은 걸 내면 승리!'
          : '${attacker ?? '상대'}가 공격자. 다른 걸 내야 살아요!';
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        children: [
          // Phase banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
            decoration: BoxDecoration(
              color: phase == 'determine'
                  ? const Color(0xFF5C6BC0).withValues(alpha: 0.1)
                  : (iAmAttacker
                        ? const Color(0xFFE53935).withValues(alpha: 0.1)
                        : const Color(0xFF2E7D32).withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: phase == 'determine'
                    ? const Color(0xFF5C6BC0).withValues(alpha: 0.4)
                    : (iAmAttacker
                          ? const Color(0xFFE53935).withValues(alpha: 0.4)
                          : const Color(0xFF2E7D32).withValues(alpha: 0.4)),
              ),
            ),
            child: Column(
              children: [
                Text(
                  phaseLabel,
                  style: GoogleFonts.notoSans(
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2A1A0E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phaseDesc,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: kTextMuted,
                    fontSize: compact ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),

          if (attacker != null) ...[
            const SizedBox(height: 12),
            Text(
              '공격자: ${iAmAttacker ? "나 😈" : "$attacker 😈"}',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFE53935),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Last round flash
          if (roundWinner != null && lastChoices != null) ...[
            _RoundResultBanner(
              roundWinner: roundWinner == 'tie_attacker_wins'
                  ? (attacker ?? roundWinner!)
                  : roundWinner!,
              userId: userId,
              myEmoji: choiceEmoji(lastChoices![userId]),
              opEmoji: choiceEmoji(lastChoices![opId]),
              compact: compact,
              customLabel: roundWinner == 'tie_attacker_wins'
                  ? '같은 패! 공격자 승'
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // Pick
          if (!picked && roundWinner == null) ...[
            Text(
              phase == 'determine' ? '가위바위보를 선택하세요' : '묵찌빠를 선택하세요',
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _ChoiceRow(choices: _choices, onPick: onPick, compact: compact),
          ] else if (picked && roundWinner == null) ...[
            const _WaitingWidget(),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 하나빼기 View
// ─────────────────────────────────────────────────────────────────────────────

class _HanabagiView extends StatelessWidget {
  final bool compact;
  final double pad;
  final SocketService sock;
  final bool picked;
  final int fingers;
  final int guess;
  final String? roundWinner;
  final Map<String, int>? lastFingers;
  final Map<String, int>? lastGuesses;
  final int? lastTotal;
  final void Function(int) onFingersChanged;
  final void Function(int) onGuessChanged;
  final VoidCallback onSubmit;
  final bool isHost;
  final VoidCallback onReset;

  const _HanabagiView({
    required this.compact,
    required this.pad,
    required this.sock,
    required this.picked,
    required this.fingers,
    required this.guess,
    required this.roundWinner,
    required this.lastFingers,
    required this.lastGuesses,
    required this.lastTotal,
    required this.onFingersChanged,
    required this.onGuessChanged,
    required this.onSubmit,
    required this.isHost,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final userId = sock.userId ?? '';
    final players = sock.rpsPlayers;
    final opId = players.firstWhere((p) => p != userId, orElse: () => '');
    final myScore = sock.rpsScores[userId] ?? 0;
    final opScore = sock.rpsScores[opId] ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScoreBoard(
            myScore: myScore,
            opScore: opScore,
            target: 3,
            compact: compact,
            myLabel: sock.nameOf(userId).isNotEmpty ? sock.nameOf(userId) : '나',
            opLabel: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
          ),
          const SizedBox(height: 20),

          // Last round result
          if (roundWinner != null && lastFingers != null) ...[
            _HanabagiResult(
              userId: userId,
              opId: opId,
              roundWinner: roundWinner!,
              lastFingers: lastFingers!,
              lastGuesses: lastGuesses ?? {},
              lastTotal: lastTotal ?? 0,
              compact: compact,
            ),
            const SizedBox(height: 16),
          ],

          // Input
          if (!picked && roundWinner == null) ...[
            Text(
              '손가락 개수',
              style: GoogleFonts.notoSans(
                color: kText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _FingerPicker(
              value: fingers,
              onChanged: onFingersChanged,
              compact: compact,
            ),
            const SizedBox(height: 20),
            Text(
              '합계 예측 (0 ~ 10)',
              style: GoogleFonts.notoSans(
                color: kText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _GuessStepper(
              value: guess,
              onChanged: onGuessChanged,
              compact: compact,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: compact ? 46 : 52,
              child: ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  '제출!',
                  style: GoogleFonts.notoSans(
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ] else if (picked && roundWinner == null) ...[
            const _WaitingWidget(),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreBoard extends StatelessWidget {
  final int myScore;
  final int opScore;
  final int target;
  final bool compact;
  final String myLabel;
  final String opLabel;

  const _ScoreBoard({
    required this.myScore,
    required this.opScore,
    required this.target,
    required this.compact,
    required this.myLabel,
    required this.opLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ScoreCell(
            label: '나',
            score: myScore,
            target: target,
            isMe: true,
            compact: compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'vs',
              style: GoogleFonts.notoSans(
                color: kTextMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _ScoreCell(
            label: '상대',
            score: opScore,
            target: target,
            isMe: false,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  final String label;
  final int score;
  final int target;
  final bool isMe;
  final bool compact;

  const _ScoreCell({
    required this.label,
    required this.score,
    required this.target,
    required this.isMe,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
            color: isMe ? kPrimary : kAccent,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score / $target',
          style: GoogleFonts.notoSans(
            color: kText,
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(target, (i) {
            return Container(
              width: compact ? 10 : 12,
              height: compact ? 10 : 12,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < score ? (isMe ? kPrimary : kAccent) : kBorder,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final Map<String, int> scores;
  final String? userId;
  final bool compact;

  const _ScoreRow({
    required this.scores,
    required this.userId,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final entries = scores.entries.toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: entries.map((e) {
        final isMe = e.key == userId;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                isMe ? '나' : '상대',
                style: GoogleFonts.notoSans(
                  color: isMe ? kPrimary : kAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${e.value}',
                style: GoogleFonts.notoSans(
                  color: kText,
                  fontSize: compact ? 28 : 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RoundResultBanner extends StatelessWidget {
  final String roundWinner;
  final String userId;
  final String myEmoji;
  final String opEmoji;
  final bool compact;
  final String? customLabel;

  const _RoundResultBanner({
    required this.roundWinner,
    required this.userId,
    required this.myEmoji,
    required this.opEmoji,
    required this.compact,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDraw = roundWinner == 'draw';
    final iWon = !isDraw && roundWinner == userId;
    final label =
        customLabel ?? (isDraw ? '🤝 무승부' : (iWon ? '🎉 이겼어요!' : '😢 졌어요'));
    final color = isDraw ? kGold : (iWon ? kSuccess : kError);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.notoSans(
              color: color,
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(myEmoji, style: TextStyle(fontSize: compact ? 32 : 38)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'vs',
                  style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
                ),
              ),
              Text(opEmoji, style: TextStyle(fontSize: compact ? 32 : 38)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HanabagiResult extends StatelessWidget {
  final String userId;
  final String opId;
  final String roundWinner;
  final Map<String, int> lastFingers;
  final Map<String, int> lastGuesses;
  final int lastTotal;
  final bool compact;

  const _HanabagiResult({
    required this.userId,
    required this.opId,
    required this.roundWinner,
    required this.lastFingers,
    required this.lastGuesses,
    required this.lastTotal,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isDraw = roundWinner == 'draw';
    final iWon = !isDraw && roundWinner == userId;
    final color = isDraw ? kGold : (iWon ? kSuccess : kError);
    final label = isDraw ? '🤝 무승부' : (iWon ? '🎉 맞혔어요!' : '😢 못 맞혔어요');

    final myF = lastFingers[userId] ?? 0;
    final opF = lastFingers[opId] ?? 0;
    final myG = lastGuesses[userId] ?? 0;
    final opG = lastGuesses[opId] ?? 0;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.notoSans(
              color: color,
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '합계: $lastTotal',
            style: GoogleFonts.notoSans(
              color: kText,
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HanaCell(
                label: '나',
                fingers: myF,
                guess: myG,
                hit: myG == lastTotal,
                compact: compact,
              ),
              _HanaCell(
                label: '상대',
                fingers: opF,
                guess: opG,
                hit: opG == lastTotal,
                compact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HanaCell extends StatelessWidget {
  final String label;
  final int fingers;
  final int guess;
  final bool hit;
  final bool compact;

  const _HanaCell({
    required this.label,
    required this.fingers,
    required this.guess,
    required this.hit,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '$fingers개',
          style: GoogleFonts.notoSans(
            color: kText,
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '예측: $guess ${hit ? "✅" : "❌"}',
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final List<(String, String, String)> choices;
  final void Function(String) onPick;
  final bool compact;

  const _ChoiceRow({
    required this.choices,
    required this.onPick,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: choices.map((c) {
        final (key, emoji, label) = c;
        return GestureDetector(
          onTap: () => onPick(key),
          child: Container(
            width: compact ? 80 : 96,
            height: compact ? 80 : 96,
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: compact ? 30 : 36)),
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
}

class _FingerPicker extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;
  final bool compact;

  const _FingerPicker({
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  static const _labels = ['✊ 0', '☝️ 1', '✌️ 2', '🤟 3', '🖖 4', '🖐️ 5'];

  @override
  Widget build(BuildContext context) {
    final size = compact ? 46.0 : 54.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (i) {
        final selected = value == i;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selected ? kPrimary.withValues(alpha: 0.15) : kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? kPrimary : kBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                _labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: compact ? 10 : 11),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GuessStepper extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;
  final bool compact;

  const _GuessStepper({
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: Icon(
            Icons.remove_circle,
            color: value > 0 ? kPrimary : kBorder,
            size: compact ? 28 : 32,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: kText,
              fontSize: compact ? 28 : 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: value < 10 ? () => onChanged(value + 1) : null,
          icon: Icon(
            Icons.add_circle,
            color: value < 10 ? kPrimary : kBorder,
            size: compact ? 28 : 32,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }
}

class _PlayerHand extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isMe;
  const _PlayerHand({
    required this.name,
    required this.emoji,
    required this.isMe,
  });

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
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary),
        ),
        SizedBox(height: 20),
        Text('상대방 선택 대기 중...'),
      ],
    );
  }
}
