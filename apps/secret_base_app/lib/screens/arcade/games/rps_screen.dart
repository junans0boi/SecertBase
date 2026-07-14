import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

// ── Phase state ──────────────────────────────────────────────────────────────
enum _Phase {
  idle, // nothing running
  picking, // 선택 화면
  waiting, // 선택 후 상대방 대기
  postChant, // 결과 공개 전 챈트
  result, // 결과 표시
}

// ── Screen ───────────────────────────────────────────────────────────────────
class RpsScreen extends StatefulWidget {
  const RpsScreen({super.key});
  @override
  State<RpsScreen> createState() => _RpsScreenState();
}

class _RpsScreenState extends State<RpsScreen> with TickerProviderStateMixin {
  final _socket = SocketService();

  // ── legacy single-round ───────────────────────────────────────────────────
  String? _myChoice;
  bool _waiting = false;

  // ── multi-mode ────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.idle;
  List<String> _chantLetters = [];
  int _chantStep = 0;
  Timer? _chantTimer;

  int _hanaFingers = 0;
  int _hanaGuess = 0;

  // ── 묵찌빠 carry-over (이전 라운드 승자가 낸 패 label: '묵'/'찌'/'빠') ────
  // null = 결정전 단계, not null = 플레이 단계
  String? _mukCarryover;

  // ── tap block (prevent double-tap on choice buttons) ─────────────────────
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _chantTimer?.cancel();
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  // ── state machine ─────────────────────────────────────────────────────────

  void _rebuild() {
    if (!mounted) return;

    final mode = _socket.rpsMode;
    final active = _socket.rpsActive;
    final roundWinner = _socket.rpsRoundWinner;
    final gameWinner = _socket.rpsGameWinner;

    // 게임 종료
    if (gameWinner != null) {
      if (_phase != _Phase.idle) {
        _chantTimer?.cancel();
        setState(() => _phase = _Phase.idle);
      } else {
        setState(() {});
      }
      return;
    }

    // 라운드 결과 → 챈트 시작
    if (roundWinner != null &&
        _phase != _Phase.postChant &&
        _phase != _Phase.result) {
      _startPostChant();
      return;
    }

    // 제로 모드는 시작 전 가위바위보 없이 바로 동시 선택
    if (active && mode == 'hanabagi' && _phase == _Phase.idle) {
      setState(() {
        _phase = _Phase.picking;
        _tapped = false;
        _hanaFingers = 0;
        _hanaGuess = 0;
      });
      return;
    }

    // 단판 가위바위보 대기 상태
    setState(() {
      _waiting = _socket.rpsResult == null && _myChoice != null;
    });
  }

  // ── post-chant (결과 공개 전 챈트) ────────────────────────────────────────

  void _startPostChant() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final mode = _socket.rpsMode ?? 'rps3';

    List<String> letters;
    if (mode == 'rps3') {
      letters = ['가', '위', '바', '위', '보'];
    } else if (mode == 'mukjippa') {
      if (_mukCarryover == null) {
        // 결정전 라운드: 가위바위보 챈트
        // (_mukCarryover가 null이면 아직 결정전 단계임.
        //  round_result 후 phase가 이미 'play'로 바뀌어도 carryover로 구분)
        letters = ['가', '위', '바', '위', '보'];
      } else {
        // 플레이 라운드: carry-over + 공격자 패 + 수비자 패
        final attackerId = _socket.rpsMukjippaAttacker ?? '';
        final players = _socket.rpsPlayers;
        final defenderId = players.firstWhere(
          (p) => p != attackerId,
          orElse: () => '',
        );
        final attackerThrow = _choiceToMukLabel(
          _socket.rpsLastChoices?[attackerId],
        );
        final defenderThrow = _choiceToMukLabel(
          _socket.rpsLastChoices?[defenderId],
        );
        // 예: 묵~묵~찌 (carryover → 공격자가 낸것 → 수비자가 낸것)
        letters = [_mukCarryover!, attackerThrow, defenderThrow];
      }
    } else {
      // zero
      letters = ['하나', '둘'];
    }

    setState(() {
      _phase = _Phase.postChant;
      _chantLetters = letters;
      _chantStep = 0;
    });

    _runChant(
      onDone: () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() => _phase = _Phase.result);
        Timer(const Duration(milliseconds: 1600), () {
          if (!mounted) return;

          // carry-over 업데이트: clearRpsRound() 전에 캡처
          if (mode == 'mukjippa') {
            final winner = _socket.rpsRoundWinner;
            final attacker = _socket.rpsMukjippaAttacker;
            final choices = _socket.rpsLastChoices;
            if (winner != null &&
                winner != 'draw' &&
                attacker != null &&
                choices != null) {
              // 결정전이 끝났거나(carryover null) 플레이 라운드가 끝남:
              // 새 공격자(라운드 승자)의 패가 다음 라운드 carry-over
              _mukCarryover = _choiceToMukLabel(choices[attacker]);
            }
            // draw면 carryover 유지 (결정전 draw → null 유지, 플레이 draw 없음)
          }

          setState(() {
            _phase = _Phase.idle;
            _tapped = false;
            _hanaFingers = 0;
            _hanaGuess = 0;
          });
          _socket.clearRpsRound();
          // 제로: 다음 라운드도 가위바위보 없이 바로 선택
          if (_socket.rpsActive && _socket.rpsMode == 'hanabagi') {
            setState(() => _phase = _Phase.picking);
          }
        });
      },
      stepMs: 420,
    );
  }

  // ── chant runner ──────────────────────────────────────────────────────────

  void _runChant({required VoidCallback onDone, int stepMs = 420}) {
    _chantTimer?.cancel();
    _chantTimer = Timer(Duration(milliseconds: stepMs), () {
      if (!mounted) return;
      if (_chantStep < _chantLetters.length - 1) {
        setState(() => _chantStep++);
        _runChant(onDone: onDone, stepMs: stepMs);
      } else {
        // 마지막 글자 잠깐 유지
        Timer(const Duration(milliseconds: 280), () {
          if (!mounted) return;
          onDone();
        });
      }
    });
  }

  // ── picks ─────────────────────────────────────────────────────────────────

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

  bool get _isHost =>
      _socket.userId != null && _socket.lobbyHost == _socket.userId;

  void _startMode(String mode) {
    _mukCarryover = null;
    _socket.startRpsGame(mode);
    setState(() {
      _tapped = false;
      _phase = _Phase.idle;
    });
  }

  void _pickChoice(String choice) {
    if (_tapped || _phase == _Phase.waiting) return;
    setState(() {
      _tapped = true;
      _phase = _Phase.waiting;
    });
    HapticFeedback.selectionClick();
    _socket.pickRps(choice);
  }

  void _submitHanabagi() {
    if (_tapped) return;
    setState(() {
      _tapped = true;
      _phase = _Phase.waiting;
    });
    HapticFeedback.selectionClick();
    _socket.pickHanabagi(_hanaFingers, _hanaGuess);
  }

  void _resetGame() {
    _mukCarryover = null;
    _socket.resetRpsGame();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static const _choices = [
    ('rock', '✊', '바위'),
    ('scissors', '✌️', '가위'),
    ('paper', '✋', '보'),
  ];

  static const _mukLabels = {'rock': '묵', 'scissors': '찌', 'paper': '빠'};

  String _choiceEmoji(String? c) =>
      _choices.firstWhere((e) => e.$1 == c, orElse: () => ('', '?', '')).$2;

  String _choiceToMukLabel(String? c) => _mukLabels[c] ?? '?';

  Color _chantColor() {
    final mode = _socket.rpsMode ?? 'rps3';
    if (mode == 'mukjippa') return const Color(0xFFE53935);
    if (mode == 'hanabagi') return const Color(0xFF2E7D32);
    return kPrimary;
  }

  // ── build ─────────────────────────────────────────────────────────────────

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

          // ── 챈트 오버레이 ─────────────────────────────────────────────────
          if (_phase == _Phase.postChant) {
            return _ChantView(
              letters: _chantLetters,
              step: _chantStep,
              color: _chantColor(),
              isPost: _phase == _Phase.postChant,
              compact: compact,
            );
          }

          // ── 모드 미선택 ────────────────────────────────────────────────────
          if (mode == null && !active && gameWinner == null) {
            return _ModeSelectView(
              compact: compact,
              pad: pad,
              isHost: _isHost,
              onMode: _startMode,
              singleResult: sock.rpsResult,
              singleChoices: sock.rpsChoices,
              userId: sock.userId,
              singleWaiting: _waiting,
              myChoice: _myChoice,
              onLegacyPick: _legacyPick,
              onLegacyReset: _legacyReset,
            );
          }

          // ── 게임 종료 ──────────────────────────────────────────────────────
          if (gameWinner != null) {
            return _GameOverView(
              compact: compact,
              pad: pad,
              mode: sock.rpsMode,
              gameWinner: gameWinner,
              userId: sock.userId,
              scores: sock.rpsScores,
              history: sock.rpsRoundHistory,
              isHost: _isHost,
              onReset: _resetGame,
            );
          }

          // ── 결과 표시 (챈트 직후) ──────────────────────────────────────────
          if (_phase == _Phase.result) {
            return _ResultView(
              compact: compact,
              pad: pad,
              sock: sock,
              choiceEmoji: _choiceEmoji,
            );
          }

          // ── 진행 중 ────────────────────────────────────────────────────────
          final isWaiting = _phase == _Phase.waiting;

          if (mode == 'rps3') {
            return _Rps3View(
              compact: compact,
              pad: pad,
              sock: sock,
              tapped: _tapped,
              waiting: isWaiting,
              onPick: _pickChoice,
            );
          }
          if (mode == 'mukjippa') {
            return _MukjippaView(
              compact: compact,
              pad: pad,
              sock: sock,
              tapped: _tapped,
              waiting: isWaiting,
              onPick: _pickChoice,
              carryover: _mukCarryover,
            );
          }
          if (mode == 'hanabagi') {
            return _HanabagiView(
              compact: compact,
              pad: pad,
              sock: sock,
              tapped: _tapped,
              waiting: isWaiting,
              pickerEnabled: _phase == _Phase.picking,
              fingers: _hanaFingers,
              guess: _hanaGuess,
              onFingersChanged: (v) => setState(() => _hanaFingers = v),
              onGuessChanged: (v) => setState(() => _hanaGuess = v),
              onSubmit: _submitHanabagi,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chant View
// ─────────────────────────────────────────────────────────────────────────────

class _ChantView extends StatelessWidget {
  final List<String> letters;
  final int step;
  final Color color;
  final bool isPost;
  final bool compact;

  const _ChantView({
    required this.letters,
    required this.step,
    required this.color,
    required this.isPost,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final current = step < letters.length ? letters[step] : '';

    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── 큰 글자 (튀어오르는 애니메이션) ────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) {
                final scale = Tween(begin: 0.2, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                );
                return ScaleTransition(
                  scale: scale,
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: Text(
                current,
                key: ValueKey('$step-$current'),
                style: GoogleFonts.notoSans(
                  fontSize: compact ? 96 : 120,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // ── 진행 열 ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < letters.length; i++) ...[
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontSize: i == step ? 22 : (i < step ? 16 : 13),
                      fontWeight: i == step ? FontWeight.w900 : FontWeight.w400,
                      color: i <= step ? color : const Color(0xFFDDDDDD),
                    ),
                    child: Text(letters[i]),
                  ),
                  if (i < letters.length - 1)
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 14,
                        color: i < step
                            ? color.withValues(alpha: 0.5)
                            : const Color(0xFFE0E0E0),
                      ),
                      child: const Text('~'),
                    ),
                ],
              ],
            ),
            if (isPost) ...[
              const SizedBox(height: 20),
              Text(
                '결과 공개 중...',
                style: GoogleFonts.notoSans(
                  color: const Color(0xFFAAAAAA),
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result View  (챈트 후 결과 요약)
// ─────────────────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final bool compact;
  final double pad;
  final SocketService sock;
  final String Function(String?) choiceEmoji;

  const _ResultView({
    required this.compact,
    required this.pad,
    required this.sock,
    required this.choiceEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final userId = sock.userId ?? '';
    final players = sock.rpsPlayers;
    final opId = players.firstWhere((p) => p != userId, orElse: () => '');
    final roundWinner = sock.rpsRoundWinner;
    final mode = sock.rpsMode ?? '';
    final myScore = sock.rpsScores[userId] ?? 0;
    final opScore = sock.rpsScores[opId] ?? 0;

    // Determine display
    final isDraw = roundWinner == 'draw' || roundWinner == null;
    final iWon = !isDraw && roundWinner == userId;
    final isTieAttackerWins = roundWinner == 'tie_attacker_wins';

    String outcomeLabel;
    Color outcomeColor;
    if (isTieAttackerWins) {
      final amAttacker = sock.rpsMukjippaAttacker == userId;
      outcomeLabel = amAttacker ? '🎉 같은 패! 내가 승리!' : '😢 같은 패... 상대 승리';
      outcomeColor = amAttacker ? kSuccess : kError;
    } else if (isDraw) {
      outcomeLabel = '🤝 무승부';
      outcomeColor = kGold;
    } else {
      outcomeLabel = iWon ? '🎉 이겼어요!' : '😢 졌어요';
      outcomeColor = iWon ? kSuccess : kError;
    }

    // Choices display
    final choices = sock.rpsLastChoices;
    Widget handRow = const SizedBox.shrink();
    if (choices != null && (mode == 'rps3' || mode == 'mukjippa')) {
      final myEmoji = choiceEmoji(choices[userId]);
      final opEmoji = choiceEmoji(choices[opId]);
      handRow = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HandBubble(
            emoji: myEmoji,
            label: sock.nameOf(userId).isNotEmpty ? sock.nameOf(userId) : '나',
            isMe: true,
            compact: compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'vs',
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16),
            ),
          ),
          _HandBubble(
            emoji: opEmoji,
            label: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
            isMe: false,
            compact: compact,
          ),
        ],
      );
    } else if (mode == 'hanabagi') {
      final fingers = sock.rpsLastFingers;
      final guesses = sock.rpsLastGuesses;
      final total = sock.rpsLastTotal ?? 0;
      if (fingers != null && guesses != null) {
        final myF = fingers[userId] ?? 0;
        final opF = fingers[opId] ?? 0;
        final myG = guesses[userId] ?? 0;
        final opG = guesses[opId] ?? 0;
        handRow = Column(
          children: [
            Text(
              '합계: $total',
              style: GoogleFonts.notoSans(
                color: kText,
                fontSize: compact ? 26 : 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HanaResultCell(
                  name: sock.nameOf(userId).isNotEmpty
                      ? sock.nameOf(userId)
                      : '나',
                  fingers: myF,
                  guess: myG,
                  hit: myG == total,
                  isMe: true,
                  compact: compact,
                ),
                _HanaResultCell(
                  name: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
                  fingers: opF,
                  guess: opG,
                  hit: opG == total,
                  isMe: false,
                  compact: compact,
                ),
              ],
            ),
          ],
        );
      }
    }

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 결과 배너
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: compact ? 14 : 18,
              horizontal: compact ? 16 : 20,
            ),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: outcomeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              outcomeLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: outcomeColor,
                fontSize: compact ? 22 : 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 20),
          handRow,
          if (mode == 'rps3' || mode == 'hanabagi') ...[
            const SizedBox(height: 20),
            _ScoreBoard(
              myScore: myScore,
              opScore: opScore,
              target: 3,
              compact: compact,
              myLabel: sock.nameOf(userId).isNotEmpty
                  ? sock.nameOf(userId)
                  : '나',
              opLabel: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
            ),
          ],
          if (mode == 'mukjippa' && sock.rpsMukjippaAttacker != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '공격자: ${sock.nameOf(sock.rpsMukjippaAttacker) == '' ? '?' : sock.nameOf(sock.rpsMukjippaAttacker)} 😈',
                style: GoogleFonts.notoSans(
                  color: const Color(0xFFE53935),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HandBubble extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isMe;
  final bool compact;

  const _HandBubble({
    required this.emoji,
    required this.label,
    required this.isMe,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: TextStyle(fontSize: compact ? 52 : 64)),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.notoSans(
            color: isMe ? kPrimary : kAccent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HanaResultCell extends StatelessWidget {
  final String name;
  final int fingers;
  final int guess;
  final bool hit;
  final bool isMe;
  final bool compact;

  const _HanaResultCell({
    required this.name,
    required this.fingers,
    required this.guess,
    required this.hit,
    required this.isMe,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: hit ? kSuccess.withValues(alpha: 0.08) : kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hit ? kSuccess.withValues(alpha: 0.4) : kBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: GoogleFonts.notoSans(
              color: isMe ? kPrimary : kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$fingers개',
            style: GoogleFonts.notoSans(
              color: kText,
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '예측 $guess ${hit ? '✅' : '❌'}',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12),
          ),
        ],
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
    'win': ('🎉 이겼어요!', kSuccess),
    'lose': ('😢 졌어요', kError),
    'draw': ('🤝 무승부', kGold),
  };

  @override
  Widget build(BuildContext context) {
    if (singleResult != null && singleChoices != null) {
      final (label, color) = _resultLabels[singleResult] ?? ('?', kTextMuted);
      final emojiMap = {'rock': '✊', 'scissors': '✌️', 'paper': '✋'};
      final sock = SocketService();
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                label,
                style: GoogleFonts.notoSans(
                  color: color,
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HandBubble(
                  emoji: myEmoji,
                  label: myKey.isEmpty ? '나' : sock.nameOf(myKey),
                  isMe: true,
                  compact: compact,
                ),
                Text(
                  'vs',
                  style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 18),
                ),
                _HandBubble(
                  emoji: opEmoji,
                  label: opKey.isEmpty ? '상대' : sock.nameOf(opKey),
                  isMe: false,
                  compact: compact,
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
      return const _LiveWaitingView();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isHost ? '게임 모드를 골라요' : '방장이 모드 선택 중이에요',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w900,
              color: kText,
            ),
          ),
          const SizedBox(height: 4),
          if (!isHost)
            Text(
              '선택이 완료되면 바로 시작해요',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
            ),
          const SizedBox(height: 20),
          if (isHost) ...[
            _ModeCard(
              emoji: '✊',
              title: '가위바위보 3판선승',
              desc: '먼저 3번 이기면 승리. 무승부는 점수 없이 계속!',
              color: kPrimary,
              onTap: () => onMode('rps3'),
              compact: compact,
            ),
            const SizedBox(height: 12),
            _ModeCard(
              emoji: '🀄',
              title: '묵찌빠',
              desc: '가위바위보로 공격자 결정 → 묵찌빠에서 같은 패 내면 공격자 승!',
              color: const Color(0xFFE53935),
              onTap: () => onMode('mukjippa'),
              compact: compact,
            ),
            const SizedBox(height: 12),
            _ModeCard(
              emoji: '0️⃣',
              title: '제로',
              desc: '내 숫자와 합계 예측을 동시에 선택해요. 먼저 3점을 따면 승리.',
              color: const Color(0xFF2E7D32),
              onTap: () => onMode('hanabagi'),
              compact: compact,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
          ],
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
                        style: TextStyle(fontSize: compact ? 28 : 34),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.notoSans(
                          color: kTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji, title, desc;
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
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: compact ? 28 : 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSans(
                      color: color,
                      fontSize: compact ? 14 : 15,
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
              size: 13,
              color: color.withValues(alpha: 0.5),
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
  final String? mode;
  final String gameWinner;
  final String? userId;
  final Map<String, int> scores;
  final List<Map<String, dynamic>> history;
  final bool isHost;
  final VoidCallback onReset;

  const _GameOverView({
    required this.compact,
    required this.pad,
    required this.mode,
    required this.gameWinner,
    required this.userId,
    required this.scores,
    required this.history,
    required this.isHost,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final sock = SocketService();
    final iWon = gameWinner == userId;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              iWon ? '🏆 최종 승리!' : '😢 최종 패배',
              style: GoogleFonts.notoSans(
                fontSize: compact ? 32 : 40,
                fontWeight: FontWeight.w900,
                color: iWon ? kSuccess : kError,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              iWon ? '대단해요!' : '다음엔 이길 거예요!',
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
            ),
            if (scores.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: scores.entries.map((e) {
                  final isMe = e.key == userId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          isMe
                              ? '나'
                              : (sock.nameOf(e.key).isNotEmpty
                                    ? sock.nameOf(e.key)
                                    : '상대'),
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
                            fontSize: compact ? 36 : 44,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (mode == 'hanabagi' && history.isNotEmpty) ...[
              const SizedBox(height: 22),
              _ZeroHistoryList(
                history: history,
                userId: userId,
                compact: compact,
              ),
            ],
            const SizedBox(height: 32),
            if (isHost)
              ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
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
      ),
    );
  }
}

class _ZeroHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String? userId;
  final bool compact;

  const _ZeroHistoryList({
    required this.history,
    required this.userId,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final sock = SocketService();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '라운드 상세',
            style: GoogleFonts.notoSans(
              color: kText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...history.map((round) {
            final fingers = _intMap(round['fingers']);
            final guesses = _intMap(round['guesses']);
            final players = fingers.keys.toList();
            final me = userId ?? '';
            final opponent = players.firstWhere(
              (p) => p != me,
              orElse: () {
                return players.isNotEmpty ? players.first : '';
              },
            );
            final winner = '${round['roundWinner'] ?? ''}';
            final total = round['total'] ?? 0;
            final myName = sock.nameOf(me).isNotEmpty ? sock.nameOf(me) : '나';
            final opName = sock.nameOf(opponent).isNotEmpty
                ? sock.nameOf(opponent)
                : '상대';
            final result = winner == 'draw'
                ? '무승부'
                : winner == me
                ? '$myName 승'
                : '$opName 승';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${round['round']}R · 합 $total · $result',
                      style: GoogleFonts.notoSans(
                        color: kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$myName: ${fingers[me] ?? 0} / 예측 ${guesses[me] ?? 0}    '
                      '$opName: ${fingers[opponent] ?? 0} / 예측 ${guesses[opponent] ?? 0}',
                      style: GoogleFonts.notoSans(
                        color: kTextMuted,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static Map<String, int> _intMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RPS 3-Win View
// ─────────────────────────────────────────────────────────────────────────────

class _Rps3View extends StatelessWidget {
  final bool compact;
  final double pad;
  final SocketService sock;
  final bool tapped;
  final bool waiting;
  final void Function(String) onPick;

  const _Rps3View({
    required this.compact,
    required this.pad,
    required this.sock,
    required this.tapped,
    required this.waiting,
    required this.onPick,
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

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ScoreBoard(
            myScore: myScore,
            opScore: opScore,
            target: 3,
            compact: compact,
            myLabel: sock.nameOf(userId).isNotEmpty ? sock.nameOf(userId) : '나',
            opLabel: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
          ),
          const SizedBox(height: 28),
          if (waiting) ...[
            const _LiveWaitingView(),
          ] else ...[
            Text(
              '가위바위보!',
              style: GoogleFonts.notoSans(
                color: kText,
                fontSize: compact ? 20 : 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            _ChoiceRow(
              choices: _choices,
              onPick: onPick,
              tapped: tapped,
              compact: compact,
            ),
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
  final bool tapped;
  final bool waiting;
  final void Function(String) onPick;
  final String? carryover; // 현재 공격자의 "리드" 패 label ('묵'/'찌'/'빠')

  const _MukjippaView({
    required this.compact,
    required this.pad,
    required this.sock,
    required this.tapped,
    required this.waiting,
    required this.onPick,
    this.carryover,
  });

  static const _mukChoices = [
    ('rock', '✊', '묵'),
    ('scissors', '✌️', '찌'),
    ('paper', '✋', '빠'),
  ];

  static const _rpsChoices = [
    ('rock', '✊', '바위'),
    ('scissors', '✌️', '가위'),
    ('paper', '✋', '보'),
  ];

  @override
  Widget build(BuildContext context) {
    final userId = sock.userId ?? '';
    final phase = sock.rpsMukjippaPhase;
    final attacker = sock.rpsMukjippaAttacker;
    final iAmAttacker = attacker == userId;
    final isMukPhase = phase == 'play';

    final modeColor = const Color(0xFFE53935);

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 페이즈 배너
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: compact ? 12 : 14,
              horizontal: compact ? 14 : 18,
            ),
            decoration: BoxDecoration(
              color: (isMukPhase ? modeColor : kPrimary).withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isMukPhase ? modeColor : kPrimary).withValues(
                  alpha: 0.3,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMukPhase ? '묵찌빠!' : '가위바위보!',
                      style: GoogleFonts.notoSans(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: isMukPhase ? modeColor : kPrimary,
                      ),
                    ),
                    // 플레이 페이즈일 때 현재 리드 패를 배지로 표시
                    if (isMukPhase && carryover != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: modeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: modeColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '$carryover 에서 시작',
                          style: GoogleFonts.notoSans(
                            color: modeColor,
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isMukPhase
                      ? (iAmAttacker
                            ? '나는 공격자 😈 — 같은 패를 내면 승리!'
                            : '${sock.nameOf(attacker).isNotEmpty ? sock.nameOf(attacker) : '상대'}가 공격자 — 다른 패를 내야 살아!')
                      : '이긴 사람이 공격자가 돼요',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: kTextMuted,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (waiting) ...[
            const _LiveWaitingView(),
          ] else ...[
            _ChoiceRow(
              choices: isMukPhase ? _mukChoices : _rpsChoices,
              onPick: onPick,
              tapped: tapped,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zero View
// ─────────────────────────────────────────────────────────────────────────────

class _HanabagiView extends StatelessWidget {
  final bool compact;
  final double pad;
  final SocketService sock;
  final bool tapped;
  final bool waiting;
  final bool pickerEnabled;
  final int fingers;
  final int guess;
  final void Function(int) onFingersChanged;
  final void Function(int) onGuessChanged;
  final VoidCallback onSubmit;

  const _HanabagiView({
    required this.compact,
    required this.pad,
    required this.sock,
    required this.tapped,
    required this.waiting,
    required this.pickerEnabled,
    required this.fingers,
    required this.guess,
    required this.onFingersChanged,
    required this.onGuessChanged,
    required this.onSubmit,
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
          if (waiting) ...[
            const SizedBox(height: 20),
            const _LiveWaitingView(
              emojis: ['0', '3', '5', '8'],
              label: '상대방 선택 대기 중...',
            ),
          ] else if (pickerEnabled) ...[
            Text(
              '내 숫자',
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
                onPressed: tapped ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
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
          ] else ...[
            const SizedBox(height: 40),
            Center(
              child: Text(
                '잠시만요...',
                style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Waiting (선택 후 상대방 대기 - 생동감 있는 버전)
// ─────────────────────────────────────────────────────────────────────────────

class _LiveWaitingView extends StatefulWidget {
  final List<String> emojis;
  final String label;

  const _LiveWaitingView({
    this.emojis = const ['✊', '✌️', '✋'],
    this.label = '상대방 선택 대기 중...',
  });

  @override
  State<_LiveWaitingView> createState() => _LiveWaitingViewState();
}

class _LiveWaitingViewState extends State<_LiveWaitingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  int _emojiIdx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.88,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _timer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (mounted) {
        setState(() => _emojiIdx = (_emojiIdx + 1) % widget.emojis.length);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(
            scale: _pulse.value,
            child: Text(
              widget.emojis[_emojiIdx],
              style: const TextStyle(fontSize: 56),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          widget.label,
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceRow extends StatelessWidget {
  final List<(String, String, String)> choices;
  final void Function(String) onPick;
  final bool tapped;
  final bool compact;

  const _ChoiceRow({
    required this.choices,
    required this.onPick,
    required this.tapped,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 88.0 : 104.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: choices.map((c) {
        final (key, emoji, label) = c;
        return GestureDetector(
          onTap: tapped ? null : () => onPick(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: tapped ? kCard.withValues(alpha: 0.5) : kCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: tapped ? kBorder.withValues(alpha: 0.3) : kBorder,
              ),
              boxShadow: tapped
                  ? null
                  : [
                      BoxShadow(
                        color: kBorder.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: compact ? 34 : 42)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.notoSans(
                    color: tapped
                        ? kTextMuted.withValues(alpha: 0.4)
                        : kTextMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  final int myScore, opScore, target;
  final bool compact;
  final String myLabel, opLabel;

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
            label: myLabel,
            score: myScore,
            target: target,
            isMe: true,
            compact: compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
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
            label: opLabel,
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
  final int score, target;
  final bool isMe, compact;

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
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: GoogleFonts.notoSans(
            color: kText,
            fontSize: compact ? 28 : 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            target,
            (i) => Container(
              width: compact ? 10 : 12,
              height: compact ? 10 : 12,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < score ? (isMe ? kPrimary : kAccent) : kBorder,
              ),
            ),
          ),
        ),
      ],
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

  static const _labels = ['✊', '☝️', '✌️', '🤟', '🖖', '🖐️'];
  static const _nums = ['0', '1', '2', '3', '4', '5'];

  @override
  Widget build(BuildContext context) {
    final sz = compact ? 46.0 : 54.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (i) {
        final sel = value == i;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: sz,
            height: sz,
            decoration: BoxDecoration(
              color: sel ? kPrimary.withValues(alpha: 0.12) : kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? kPrimary : kBorder,
                width: sel ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_labels[i], style: TextStyle(fontSize: compact ? 14 : 16)),
                Text(
                  _nums[i],
                  style: GoogleFonts.notoSans(
                    color: sel ? kPrimary : kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
            size: compact ? 30 : 34,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        SizedBox(
          width: 70,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: kText,
              fontSize: compact ? 32 : 38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: value < 10 ? () => onChanged(value + 1) : null,
          icon: Icon(
            Icons.add_circle,
            color: value < 10 ? kPrimary : kBorder,
            size: compact ? 30 : 34,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ],
    );
  }
}
