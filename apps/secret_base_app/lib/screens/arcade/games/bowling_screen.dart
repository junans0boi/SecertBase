import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lane coordinate system
//   x : -1.0 (left gutter edge) .. 1.0 (right gutter edge)
//   t :  0.0 (foul line)        .. 1.0 (back of pin deck)
// The guide line, the rolling ball and the pin collision all use the SAME
// trajectory function, so what you aim is exactly what happens.
// ─────────────────────────────────────────────────────────────────────────────

const List<double> _pinX = [
  0.0, // 1
  -0.15, 0.15, // 2 3
  -0.30, 0.0, 0.30, // 4 5 6
  -0.45, -0.15, 0.15, 0.45, // 7 8 9 10
];
const List<double> _pinT = [
  0.86,
  0.90,
  0.90,
  0.94,
  0.94,
  0.94,
  0.98,
  0.98,
  0.98,
  0.98,
];
// Pins directly behind each pin: [left child, right child]
const Map<int, List<int>> _pinBehind = {
  0: [1, 2],
  1: [3, 4],
  2: [4, 5],
  3: [6, 7],
  4: [7, 8],
  5: [8, 9],
};
// Canonical knock order used only when we must reconstruct a mid-frame deck
// (e.g. after a reconnect) knowing just how many pins are down.
const List<int> _canonicalKnockOrder = [0, 1, 2, 4, 3, 5, 7, 8, 6, 9];

double _trajX(double aim, double curve, double t) {
  final endX = (aim * 0.8 + curve * 0.5).clamp(-1.15, 1.15);
  final ctrlX = aim * 0.8 - curve * 0.55;
  final u = 1 - t;
  return 2 * u * t * ctrlX + t * t * endX;
}

class _PinKnock {
  final int pin;
  final double t; // roll progress at which the pin falls
  final int dir; // -1 falls left, 0 straight back, 1 falls right
  const _PinKnock(this.pin, this.t, this.dir);
}

class _RollSim {
  final List<_PinKnock> knocks;
  final double? gutterT; // ball dropped into the gutter at this progress
  const _RollSim(this.knocks, this.gutterT);

  int get pinsDown => knocks.length;
}

/// Deterministic pre-simulation of a roll: same (standing, aim, curve) always
/// produces the same result, so the opponent's screen can replay it exactly.
_RollSim _simulateRoll(List<bool> standing, double aim, double curve) {
  for (double t = 0.05; t < 0.85; t += 0.01) {
    if (_trajX(aim, curve, t).abs() > 0.97) {
      return _RollSim(const [], t);
    }
  }

  final knocks = <_PinKnock>[];
  final down = List<bool>.filled(10, false);

  void fall(int pin, double t, int dir, double strength) {
    if (down[pin]) return;
    down[pin] = true;
    // Clamp so late chain-knocks still animate before the roll completes.
    if (standing[pin]) knocks.add(_PinKnock(pin, math.min(t, 0.97), dir));
    final children = _pinBehind[pin];
    if (children == null || strength < 0.45) return;
    final next = strength * 0.8;
    if (dir == 0) {
      // Flat hit: both rear neighbours wobble down, but the chain dies fast.
      fall(children[0], t + 0.045, -1, 0.35);
      fall(children[1], t + 0.045, 1, 0.35);
    } else {
      final child = dir < 0 ? children[0] : children[1];
      fall(child, t + 0.045, dir, next);
    }
  }

  for (int i = 0; i < 10; i++) {
    if (down[i]) continue;
    final bx = _trajX(aim, curve, _pinT[i]);
    final dx = _pinX[i] - bx;
    if (dx.abs() >= 0.14) continue;

    if (i == 0 && dx.abs() >= 0.06) {
      // Pocket hit on the head pin: the classic strike ball. The head pin
      // sweeps both rear neighbours with real power.
      down[0] = true;
      if (standing[0]) {
        knocks.add(_PinKnock(0, _pinT[0], dx.sign.toInt()));
      }
      fall(1, _pinT[0] + 0.045, -1, 0.8);
      fall(2, _pinT[0] + 0.045, 1, 0.8);
    } else if (dx.abs() < 0.05) {
      fall(i, _pinT[i], 0, 1.0);
    } else {
      fall(i, _pinT[i], dx.sign.toInt(), 1.0);
    }
  }

  knocks.sort((a, b) => a.t.compareTo(b.t));
  return _RollSim(knocks, null);
}

class _RollContext {
  final int frame; // 0-based
  final int rollInFrame; // 0 = frame opener
  final int standing;
  const _RollContext(this.frame, this.rollInFrame, this.standing);
}

/// Dart port of the server's nextRollContext (bowling-engine.js).
_RollContext? _nextRollContext(List<int> rolls) {
  int i = 0;
  for (int f = 0; f < 9; f++) {
    if (i == rolls.length) return _RollContext(f, 0, 10);
    if (rolls[i] == 10) {
      i += 1;
      continue;
    }
    if (i + 1 == rolls.length) return _RollContext(f, 1, 10 - rolls[i]);
    i += 2;
  }
  final r = rolls.sublist(math.min(i, rolls.length));
  if (r.isEmpty) return const _RollContext(9, 0, 10);
  if (r.length == 1) {
    return _RollContext(9, 1, r[0] == 10 ? 10 : 10 - r[0]);
  }
  if (r.length == 2) {
    if (r[0] == 10) return _RollContext(9, 2, r[1] == 10 ? 10 : 10 - r[1]);
    if (r[0] + r[1] == 10) return const _RollContext(9, 2, 10);
    return null;
  }
  return null;
}

/// Standing pins for a player about to roll, given their flat roll list.
/// Priority: local cache → exact re-simulation from the server's per-roll
/// aim/curve [history] → canonical count-matching fallback.
List<bool> _deckForRolls(
  List<int> rolls,
  List<bool>? cached, {
  List<Map<String, dynamic>> history = const [],
  String? playerId,
}) {
  final ctx = _nextRollContext(rolls);
  if (ctx == null || ctx.rollInFrame == 0) return List.filled(10, true);
  if (cached != null && cached.where((s) => s).length == ctx.standing) {
    return List.of(cached);
  }

  final replayed = _deckByHistory(rolls, ctx, history, playerId);
  if (replayed != null) return replayed;

  // Last resort: knock the canonical pins to match the standing count.
  final deck = List<bool>.filled(10, true);
  int toKnock = 10 - ctx.standing;
  for (final p in _canonicalKnockOrder) {
    if (toKnock == 0) break;
    deck[p] = false;
    toKnock--;
  }
  return deck;
}

/// Re-simulate the current frame's rolls from the server history so the deck
/// shows exactly the pins that really fell. Returns null when history is
/// incomplete or disagrees with the recorded standing count.
List<bool>? _deckByHistory(
  List<int> rolls,
  _RollContext ctx,
  List<Map<String, dynamic>> history,
  String? playerId,
) {
  if (playerId == null || ctx.rollInFrame == 0) return null;
  final frameStart = rolls.length - ctx.rollInFrame;
  var deck = List<bool>.filled(10, true);
  for (int k = frameStart; k < rolls.length; k++) {
    Map<String, dynamic>? meta;
    for (final h in history) {
      if (h['playerId'].toString() == playerId &&
          ((h['rollIndex'] as num?) ?? -1).toInt() == k) {
        meta = h;
        break;
      }
    }
    if (meta == null) return null;
    final sim = _simulateRoll(
      deck,
      ((meta['aim'] as num?) ?? 0).toDouble(),
      ((meta['curve'] as num?) ?? 0).toDouble(),
    );
    for (final knock in sim.knocks) {
      deck[knock.pin] = false;
    }
    // 10th frame: a cleared deck gets a fresh rack for the bonus roll.
    if (!deck.contains(true)) deck = List<bool>.filled(10, true);
  }
  if (deck.where((s) => s).length != ctx.standing) return null;
  return deck;
}

class BowlingScreen extends StatefulWidget {
  const BowlingScreen({super.key});

  @override
  State<BowlingScreen> createState() => _BowlingScreenState();
}

class _BowlingScreenState extends State<BowlingScreen>
    with TickerProviderStateMixin {
  final _socket = SocketService();

  double _aim = 0.0; // 방향 -1..1
  double _curve = 0.0; // 커브(훅) -1..1

  late final AnimationController _rollCtrl;
  late final AnimationController _fxCtrl;

  bool _isRolling = false;
  bool _isReplay = false; // animating the opponent's roll
  double _replayAim = 0, _replayCurve = 0;
  String? _replayEvent; // STRIKE/SPARE/GUTTER flag of the roll being replayed
  _RollSim? _activeSim;
  List<bool> _deck = List.filled(10, true);
  final Map<int, double> _fallStartT = {}; // pin -> roll progress when it fell
  final Map<int, int> _fallDir = {};
  String? _fxEvent; // STRIKE / SPARE / GUTTER
  String? _appliedRollKey; // "<playerId>:<rollIndex>" of last animated roll
  final Map<String, List<bool>> _deckCache = {};

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onSocket);
    _rollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rollCtrl.addListener(_onRollTick);
    _rollCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onRollDone();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Entering mid-game: mark the current lastRoll as seen so we don't
      // replay an old roll, then draw the deck as it stands.
      final last = _socket.bowlingState?['lastRoll'] as Map<String, dynamic>?;
      if (last != null) {
        _appliedRollKey = '${last['playerId']}:${last['rollIndex']}';
      }
      _syncDeckFromState();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    _rollCtrl.dispose();
    _fxCtrl.dispose();
    super.dispose();
  }

  // ── state sync ─────────────────────────────────────────────────────────────

  List<int> _rollsOf(Map<String, dynamic> state, String pid) {
    final list = (state['rolls'] as Map<String, dynamic>?)?[pid] as List?;
    return (list ?? const []).map((v) => (v as num).toInt()).toList();
  }

  List<Map<String, dynamic>> _historyOf(Map<String, dynamic> state) {
    final raw = state['history'] as List?;
    if (raw == null) return const [];
    return raw.map((h) => Map<String, dynamic>.from(h as Map)).toList();
  }

  void _onSocket() {
    if (!mounted) return;
    if (!_isRolling && !_maybeStartPendingReplay()) {
      _syncDeckFromState();
    }
    setState(() {});
  }

  /// Starts a replay if the server's lastRoll is an opponent roll we have not
  /// animated yet. Returns true when a replay was started. Called both on
  /// socket updates and after our own animation finishes, so an update that
  /// arrived mid-animation is played back instead of silently dropped.
  bool _maybeStartPendingReplay() {
    final state = _socket.bowlingState;
    if (state == null || _isRolling) return false;
    final last = state['lastRoll'] as Map<String, dynamic>?;
    if (last == null) return false;
    final myId = _socket.userId ?? '';
    final key = '${last['playerId']}:${last['rollIndex']}';
    if (key == _appliedRollKey) return false;
    if (last['playerId'].toString() == myId) {
      _appliedRollKey = key; // our own roll, already animated locally
      return false;
    }
    _startOpponentReplay(state, last, key);
    return true;
  }

  void _syncDeckFromState() {
    final state = _socket.bowlingState;
    if (state == null || _isRolling) return;
    final turn = state['turn']?.toString() ?? '';
    if (turn.isEmpty) return;
    final rolls = _rollsOf(state, turn);
    _deck = _deckForRolls(
      rolls,
      _deckCache[turn],
      history: _historyOf(state),
      playerId: turn,
    );
    _deckCache[turn] = List.of(_deck);
    _fallStartT.clear();
    _fallDir.clear();
  }

  void _startOpponentReplay(
    Map<String, dynamic> state,
    Map<String, dynamic> last,
    String key,
  ) {
    final pid = last['playerId'].toString();
    final rolls = _rollsOf(state, pid);
    final rollsBefore = rolls.sublist(0, math.max(0, rolls.length - 1));
    _appliedRollKey = key;
    _replayAim = ((last['aim'] as num?) ?? 0).toDouble();
    _replayCurve = ((last['curve'] as num?) ?? 0).toDouble();
    _replayEvent = last['isStrike'] == true
        ? 'STRIKE'
        : (last['isSpare'] == true
              ? 'SPARE'
              : (last['isGutter'] == true ? 'GUTTER' : null));

    _deck = _deckForRolls(
      rollsBefore,
      _deckCache[pid],
      history: _historyOf(state),
      playerId: pid,
    );
    _activeSim = _simulateRoll(_deck, _replayAim, _replayCurve);
    _fallStartT.clear();
    _fallDir.clear();
    _isReplay = true;
    _isRolling = true;
    setState(() {});
    _rollCtrl.forward(from: 0);
  }

  // ── my roll ────────────────────────────────────────────────────────────────

  bool get _isMyTurn {
    final state = _socket.bowlingState;
    final myId = _socket.userId;
    return state != null && myId != null && state['turn'] == myId;
  }

  void _throwBall() {
    final state = _socket.bowlingState;
    final myId = _socket.userId;
    if (_isRolling || state == null || myId == null || !_isMyTurn) return;

    _deck = _deckForRolls(
      _rollsOf(state, myId),
      _deckCache[myId],
      history: _historyOf(state),
      playerId: myId,
    );
    _activeSim = _simulateRoll(_deck, _aim, _curve);
    _fallStartT.clear();
    _fallDir.clear();
    _isReplay = false;
    _isRolling = true;
    setState(() {});
    _rollCtrl.forward(from: 0);
  }

  void _onRollTick() {
    final sim = _activeSim;
    if (sim == null) return;
    final t = _rollCtrl.value;
    for (final knock in sim.knocks) {
      if (t >= knock.t && !_fallStartT.containsKey(knock.pin)) {
        _fallStartT[knock.pin] = knock.t;
        _fallDir[knock.pin] = knock.dir;
      }
    }
    setState(() {});
  }

  Future<void> _onRollDone() async {
    final sim = _activeSim;
    if (sim == null) return;

    final myId = _socket.userId ?? '';
    final state = _socket.bowlingState;
    final actorId = _isReplay
        ? (state?['lastRoll']?['playerId']?.toString() ?? '')
        : myId;

    // Apply the outcome to the deck + cache.
    for (final knock in sim.knocks) {
      _deck[knock.pin] = false;
    }
    if (actorId.isNotEmpty) _deckCache[actorId] = List.of(_deck);

    // Report my roll to the server right away (before the cutscene) so the
    // opponent's replay starts as early as possible.
    if (!_isReplay && state != null) {
      _appliedRollKey = '$myId:${_rollsOf(state, myId).length}';
      _socket.rollBowling(sim.pinsDown, aim: _aim, curve: _curve);
    }

    // Cutscene
    String? event;
    if (!_isReplay && state != null) {
      final ctx = _nextRollContext(_rollsOf(state, myId));
      if (ctx != null) {
        final clearedDeck = !_deck.contains(true);
        if (clearedDeck && ctx.rollInFrame == 0) {
          event = 'STRIKE';
        } else if (clearedDeck) {
          event = 'SPARE';
        } else if (sim.pinsDown == 0) {
          event = 'GUTTER';
        }
      }
    } else if (_isReplay) {
      event = _replayEvent;
    }

    if (event != null) {
      setState(() => _fxEvent = event);
      _fxCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    if (!mounted) return;
    setState(() {
      _isRolling = false;
      _isReplay = false;
      _replayEvent = null;
      _fxEvent = null;
      _activeSim = null;
      _rollCtrl.reset();
    });
    // A roll that arrived while we were animating is replayed now instead of
    // being dropped; otherwise just redraw the deck from the latest state.
    if (!_maybeStartPendingReplay()) {
      _syncDeckFromState();
    }
    if (mounted) setState(() {});
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _socket.bowlingState;
    final myId = _socket.userId ?? '';
    final isMyTurn = _isMyTurn && !_isRolling;
    final isFinished = state?['status'] == 'finished';
    final pIds = state != null
        ? (state['rolls'] as Map<String, dynamic>).keys.toList()
        : <String>[];
    final opponentId = pIds.firstWhere((id) => id != myId, orElse: () => '');

    return GameScaffold(
      title: '볼링 🎳',
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10101F), Color(0xFF1B1230), Color(0xFF0B0B16)],
          ),
        ),
        child: SafeArea(
          child: state == null
              ? Center(
                  child: Text(
                    '게임을 준비하는 중...',
                    style: GoogleFonts.notoSans(color: Colors.white70),
                  ),
                )
              : Column(
                  children: [
                    _buildScoreSheet(state, myId, opponentId),
                    const SizedBox(height: 6),
                    _buildTurnBanner(state, isMyTurn),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _rollCtrl,
                              builder: (context, _) => CustomPaint(
                                painter: _LanePainter(
                                  deck: List.of(_deck),
                                  fallStartT: Map.of(_fallStartT),
                                  fallDir: Map.of(_fallDir),
                                  rollT: _isRolling ? _rollCtrl.value : null,
                                  aim: _isReplay ? _replayAim : _aim,
                                  curve: _isReplay ? _replayCurve : _curve,
                                  gutterT: _activeSim?.gutterT,
                                  showGuide: isMyTurn && !isFinished,
                                ),
                              ),
                            ),
                          ),
                          if (_fxEvent != null)
                            Positioned.fill(child: _buildCutscene()),
                          if (isFinished)
                            Positioned.fill(child: _buildResult(state, myId)),
                        ],
                      ),
                    ),
                    if (isMyTurn && !isFinished) _buildControls(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTurnBanner(Map<String, dynamic> state, bool isMyTurn) {
    final ctx = _nextRollContext(_rollsOf(state, state['turn'].toString()));
    final frameLabel = ctx == null
        ? ''
        : ' · ${ctx.frame + 1}프레임 ${ctx.rollInFrame + 1}구';
    final String text;
    if (_isRolling) {
      text = _isReplay ? '상대방이 굴리는 중... 🎳' : '굴러갑니다... 🎳';
    } else if (isMyTurn) {
      text = '내 차례$frameLabel — 방향과 커브를 정해 굴리세요!';
    } else {
      text = '상대방 차례$frameLabel — 투구가 실시간으로 중계돼요';
    }
    final active = isMyTurn && !_isRolling;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? Colors.amberAccent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? Colors.amberAccent : Colors.white24),
      ),
      child: Text(
        text,
        style: GoogleFonts.notoSans(
          color: active ? Colors.amberAccent : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
    );
  }

  // ── score sheet (classic X / - notation) ──────────────────────────────────

  Widget _buildScoreSheet(
    Map<String, dynamic> state,
    String myId,
    String opponentId,
  ) {
    final frames = state['frames'] as Map<String, dynamic>?;
    final scores = (state['scores'] as Map<String, dynamic>?) ?? {};

    List<Map<String, dynamic>> framesOf(String pid) {
      final raw = frames?[pid] as List?;
      if (raw == null) {
        return List.generate(
          10,
          (i) => {'r1': '', 'r2': '', 'r3': '', 'cumScore': ''},
        );
      }
      return raw.map((f) => Map<String, dynamic>.from(f as Map)).toList();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EC),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 44),
              ...List.generate(
                10,
                (i) => Expanded(
                  flex: i == 9 ? 4 : 3,
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF6B5B3E),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 34,
                child: Center(
                  child: Text(
                    'TOT',
                    style: TextStyle(
                      color: Color(0xFF6B5B3E),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _buildSheetRow(
            '나',
            framesOf(myId),
            ((scores[myId] as num?) ?? 0).toInt(),
            const Color(0xFF2563EB),
          ),
          const SizedBox(height: 3),
          _buildSheetRow(
            '상대',
            framesOf(opponentId),
            ((scores[opponentId] as num?) ?? 0).toInt(),
            const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetRow(
    String label,
    List<Map<String, dynamic>> frames,
    int total,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...List.generate(10, (i) {
          final f = i < frames.length
              ? frames[i]
              : {'r1': '', 'r2': '', 'r3': '', 'cumScore': ''};
          final isTenth = i == 9;
          return Expanded(
            flex: isTenth ? 4 : 3,
            child: Container(
              margin: const EdgeInsets.only(left: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFCDC3AC)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _sheetCell('${f['r1'] ?? ''}'),
                      _sheetCell('${f['r2'] ?? ''}', boxed: true),
                      if (isTenth) _sheetCell('${f['r3'] ?? ''}', boxed: true),
                    ],
                  ),
                  SizedBox(
                    height: 13,
                    child: Center(
                      child: Text(
                        '${f['cumScore'] ?? ''}',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFF1F2937),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Container(
          width: 34,
          margin: const EdgeInsets.only(left: 2),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$total',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: Colors.amberAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sheetCell(String v, {bool boxed = false}) {
    return Expanded(
      child: Container(
        height: 13,
        decoration: boxed
            ? const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFCDC3AC), width: 0.8),
                  bottom: BorderSide(color: Color(0xFFCDC3AC), width: 0.8),
                ),
              )
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFCDC3AC), width: 0.8),
                ),
              ),
        child: Center(
          child: Text(
            v,
            style: TextStyle(
              color: v == 'X'
                  ? const Color(0xFFDC2626)
                  : (v == '/'
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF1F2937)),
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ── controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161628),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _controlSlider(
            label: '방향',
            hintL: '◀ 왼쪽',
            hintR: '오른쪽 ▶',
            value: _aim,
            color: Colors.amberAccent,
            onChanged: (v) => setState(() => _aim = v),
          ),
          _controlSlider(
            label: '커브',
            hintL: '↰ 좌훅',
            hintR: '우훅 ↱',
            value: _curve,
            color: Colors.cyanAccent,
            onChanged: (v) => setState(() => _curve = v),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _isRolling ? null : _throwBall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '공 굴리기 🎳',
                style: GoogleFonts.notoSans(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlSlider({
    required String label,
    required String hintL,
    required String hintR,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: GoogleFonts.notoSans(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          hintL,
          style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: -1,
              max: 1,
              activeColor: color,
              inactiveColor: Colors.white12,
              onChanged: _isRolling ? null : onChanged,
            ),
          ),
        ),
        Text(
          hintR,
          style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9),
        ),
      ],
    );
  }

  // ── cutscene & result ──────────────────────────────────────────────────────

  Widget _buildCutscene() {
    final event = _fxEvent!;
    final (title, sub, color) = switch (event) {
      'STRIKE' => ('STRIKE!', '완벽한 한 방! 💥', const Color(0xFFFFC93C)),
      'SPARE' => ('SPARE!', '깔끔하게 정리! ✨', const Color(0xFF4DD8FF)),
      _ => ('GUTTER...', '아쉬워요 🧹', const Color(0xFF9CA3AF)),
    };
    return AnimatedBuilder(
      animation: _fxCtrl,
      builder: (context, _) {
        final v = _fxCtrl.value;
        final scale = event == 'GUTTER'
            ? 1.0
            : Curves.elasticOut.transform(v.clamp(0.0, 1.0));
        final fade = v < 0.85 ? 1.0 : (1 - (v - 0.85) / 0.15);
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Container(
            color: Colors.black.withValues(alpha: 0.62),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (event != 'GUTTER')
                  CustomPaint(
                    size: Size.infinite,
                    painter: _BurstPainter(progress: v, color: color),
                  ),
                Transform.scale(
                  scale: event == 'GUTTER' ? 1.0 : scale,
                  child: Transform.translate(
                    offset: event == 'GUTTER'
                        ? Offset(0, 14 * Curves.easeOut.transform(v))
                        : Offset.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.orbitron(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: color,
                            shadows: [
                              Shadow(
                                color: color.withValues(alpha: 0.8),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sub,
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult(Map<String, dynamic> state, String myId) {
    final winner = state['result']?['winner']?.toString();
    final isWin = winner == myId;
    final isDraw = winner == 'draw';
    final text = isWin ? '🏆 승리!' : (isDraw ? '🤝 무승부' : '아쉽게 패배...');
    final color = isWin
        ? const Color(0xFFFFC93C)
        : (isDraw ? Colors.white : const Color(0xFF8A93A6));
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161628),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: GoogleFonts.notoSans(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _deckCache.clear();
                  _appliedRollKey = null;
                  _socket.startBowling();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                ),
                child: Text(
                  '한 판 더!',
                  style: GoogleFonts.notoSans(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lane painter — draws the whole alley: room, lane, gutters, arrows, pins,
// guide line and the rolling ball, all in the shared lane coordinate system.
// ─────────────────────────────────────────────────────────────────────────────

class _LanePainter extends CustomPainter {
  final List<bool> deck;
  final Map<int, double> fallStartT;
  final Map<int, int> fallDir;
  final double? rollT; // null when idle
  final double aim;
  final double curve;
  final double? gutterT;
  final bool showGuide;

  _LanePainter({
    required this.deck,
    required this.fallStartT,
    required this.fallDir,
    required this.rollT,
    required this.aim,
    required this.curve,
    required this.gutterT,
    required this.showGuide,
  });

  double _yFor(Size size, double t) {
    final top = size.height * 0.075;
    final bottom = size.height * 0.985;
    return bottom - (bottom - top) * math.pow(t, 0.92);
  }

  double _halfW(Size size, double t) {
    return _lerp(size.width * 0.42, size.width * 0.145, t);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  Offset _pos(Size size, double x, double t) {
    return Offset(size.width / 2 + x * _halfW(size, t), _yFor(size, t));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintRoom(canvas, size);
    _paintLane(canvas, size);
    _paintArrows(canvas, size);
    if (showGuide) _paintGuide(canvas, size);
    _paintPins(canvas, size);
    if (rollT != null) _paintBall(canvas, size, rollT!);
  }

  void _paintRoom(Canvas canvas, Size size) {
    // Dark alley wall behind the pin deck, with neon accent strips.
    final wallRect = Rect.fromLTRB(0, 0, size.width, _yFor(size, 0.84));
    canvas.drawRect(
      wallRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1030), Color(0xFF241640)],
        ).createShader(wallRect),
    );
    final neonY = _yFor(size, 0.84) - 2;
    canvas.drawLine(
      Offset(0, neonY),
      Offset(size.width, neonY),
      Paint()
        ..color = const Color(0xFFE94FD0)
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(0, neonY - 6),
      Offset(size.width, neonY - 6),
      Paint()
        ..color = const Color(0xFF3FD8F0)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _paintLane(Canvas canvas, Size size) {
    // Gutters
    final gutterPath = Path()
      ..moveTo(_pos(size, -1.28, 0).dx, _yFor(size, 0))
      ..lineTo(_pos(size, -1.28, 1).dx, _yFor(size, 1))
      ..lineTo(_pos(size, 1.28, 1).dx, _yFor(size, 1))
      ..lineTo(_pos(size, 1.28, 0).dx, _yFor(size, 0))
      ..close();
    canvas.drawPath(gutterPath, Paint()..color = const Color(0xFF17111F));

    // Wooden lane
    final lanePath = Path()
      ..moveTo(_pos(size, -1, 0).dx, _yFor(size, 0))
      ..lineTo(_pos(size, -1, 1).dx, _yFor(size, 1))
      ..lineTo(_pos(size, 1, 1).dx, _yFor(size, 1))
      ..lineTo(_pos(size, 1, 0).dx, _yFor(size, 0))
      ..close();
    final laneRect = lanePath.getBounds();
    canvas.drawPath(
      lanePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFD9A560), Color(0xFFC08B4A), Color(0xFF8A6134)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(laneRect),
    );

    // Board seams converging to the deck
    final seam = Paint()
      ..color = const Color(0xFF9C7038).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = -0.8; x <= 0.81; x += 0.2) {
      canvas.drawLine(_pos(size, x, 0), _pos(size, x, 1), seam);
    }

    // Lane edges
    final edge = Paint()
      ..color = const Color(0xFF5A3D1E)
      ..strokeWidth = 2.5;
    canvas.drawLine(_pos(size, -1, 0), _pos(size, -1, 1), edge);
    canvas.drawLine(_pos(size, 1, 0), _pos(size, 1, 1), edge);

    // Pin deck: darker glossy area
    final deckPath = Path()
      ..moveTo(_pos(size, -1, 0.83).dx, _yFor(size, 0.83))
      ..lineTo(_pos(size, -1, 1).dx, _yFor(size, 1))
      ..lineTo(_pos(size, 1, 1).dx, _yFor(size, 1))
      ..lineTo(_pos(size, 1, 0.83).dx, _yFor(size, 0.83))
      ..close();
    canvas.drawPath(
      deckPath,
      Paint()..color = const Color(0xFF3A2A18).withValues(alpha: 0.55),
    );
  }

  void _paintArrows(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF7A4A26);
    for (double x = -0.6; x <= 0.61; x += 0.3) {
      final t = 0.34 - (x.abs() * 0.08);
      final p = _pos(size, x, t);
      final s = 6.0 * (1 - t * 0.5);
      final path = Path()
        ..moveTo(p.dx, p.dy - s * 1.6)
        ..lineTo(p.dx - s * 0.7, p.dy)
        ..lineTo(p.dx + s * 0.7, p.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintGuide(Canvas canvas, Size size) {
    for (double t = 0.06; t <= 0.86; t += 0.045) {
      final x = _trajX(aim, curve, t);
      if (x.abs() > 1.0) break;
      final p = _pos(size, x, t);
      final r = 3.2 * (1 - t * 0.55);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = const Color(0xFF3FD8F0).withValues(alpha: 0.9 - t * 0.55),
      );
    }
    // Landing shadow target at the deck entrance
    final endX = _trajX(aim, curve, 0.86);
    if (endX.abs() <= 1.0) {
      final p = _pos(size, endX, 0.86);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 26, height: 9),
        Paint()..color = const Color(0xFF3FD8F0).withValues(alpha: 0.35),
      );
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 26, height: 9),
        Paint()
          ..color = const Color(0xFF3FD8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _paintPins(Canvas canvas, Size size) {
    // Draw back row first so front pins overlap naturally.
    final order = List<int>.generate(10, (i) => i)
      ..sort((a, b) => _pinT[b].compareTo(_pinT[a]));
    for (final i in order) {
      final fallenAt = fallStartT[i];
      if (!deck[i] && fallenAt == null) continue; // already swept away

      final base = _pos(size, _pinX[i], _pinT[i]);
      final s = 1 - _pinT[i] * 0.35;
      final h = 34.0 * s;
      final w = 13.0 * s;

      double fallP = 0;
      int dir = 1;
      if (fallenAt != null) {
        dir = fallDir[i] == 0 ? (i.isEven ? 1 : -1) : (fallDir[i] ?? 1);
        fallP = rollT == null
            ? 1.0
            : ((rollT! - fallenAt) / 0.10).clamp(0.0, 1.0);
      }

      canvas.save();
      canvas.translate(base.dx, base.dy);
      if (fallP > 0) {
        final ease = Curves.easeIn.transform(fallP);
        canvas.translate(dir * 10 * ease, -4 * math.sin(ease * math.pi));
        canvas.rotate(dir * 1.5 * ease);
      }
      _drawPin(canvas, w, h, opacity: fallP > 0 ? 1 - fallP * 0.6 : 1);
      canvas.restore();
    }
  }

  void _drawPin(Canvas canvas, double w, double h, {double opacity = 1}) {
    final body = Path()
      ..moveTo(0, -h)
      ..cubicTo(w * 0.55, -h, w * 0.35, -h * 0.62, w * 0.30, -h * 0.48)
      ..cubicTo(w * 0.26, -h * 0.36, w * 0.62, -h * 0.26, w * 0.52, 0)
      ..arcToPoint(
        Offset(-w * 0.52, 0),
        radius: Radius.circular(w * 0.6),
        clockwise: true,
      )
      ..cubicTo(
        -w * 0.62,
        -h * 0.26,
        -w * 0.26,
        -h * 0.36,
        -w * 0.30,
        -h * 0.48,
      )
      ..cubicTo(-w * 0.35, -h * 0.62, -w * 0.55, -h, 0, -h)
      ..close();

    // Shadow on the deck
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 1),
        width: w * 1.5,
        height: w * 0.5,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35 * opacity),
    );

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFDFDFDF).withValues(alpha: opacity),
            Colors.white.withValues(alpha: opacity),
            const Color(0xFFB9B9B9).withValues(alpha: opacity),
          ],
        ).createShader(Rect.fromLTWH(-w, -h, w * 2, h)),
    );

    // Red neck stripes
    final stripe = Paint()
      ..color = const Color(0xFFE02D2D).withValues(alpha: opacity)
      ..strokeWidth = h * 0.055
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-w * 0.29, -h * 0.52),
      Offset(w * 0.29, -h * 0.52),
      stripe,
    );
    canvas.drawLine(
      Offset(-w * 0.27, -h * 0.44),
      Offset(w * 0.27, -h * 0.44),
      stripe,
    );
  }

  void _paintBall(Canvas canvas, Size size, double t) {
    double x;
    final gt = gutterT;
    if (gt != null && t >= gt) {
      x = _trajX(aim, curve, gt).sign * 1.14;
    } else {
      x = _trajX(aim, curve, t);
    }
    final p = _pos(size, x, t);
    final r = _lerp(24, 8.5, t);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx, p.dy + r * 0.55),
        width: r * 1.9,
        height: r * 0.55,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Lateral lean into the curve (visual only)
    final dxdt =
        _trajX(aim, curve, math.min(1, t + 0.02)) -
        _trajX(aim, curve, math.max(0, t - 0.02));
    final lean = (dxdt * 6).clamp(-0.35, 0.35);

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(lean);

    final ballRect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFF7B6B), Color(0xFFD92B2B), Color(0xFF6E0F14)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(ballRect),
    );

    // Forward-roll illusion: finger holes travel downward across the face and
    // wrap around, like the surface rolling toward the pins (not a flat spin).
    canvas.save();
    canvas.clipPath(Path()..addOval(ballRect));
    final phase = (t * 8.0) % 1.0;
    for (int k = -1; k <= 1; k++) {
      final holeY = (phase + k) * (r * 2.2);
      if (holeY.abs() > r * 1.2) continue;
      // squash holes near the edges to fake sphere curvature
      final squash = (1 - (holeY / (r * 1.3)).abs()).clamp(0.15, 1.0);
      final hole = Paint()..color = const Color(0xFF33080B);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-r * 0.22, holeY),
          width: r * 0.24,
          height: r * 0.24 * squash,
        ),
        hole,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(r * 0.16, holeY - r * 0.12 * squash),
          width: r * 0.22,
          height: r * 0.22 * squash,
        ),
        hole,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-r * 0.02, holeY + r * 0.18 * squash),
          width: r * 0.2,
          height: r * 0.2 * squash,
        ),
        hole,
      );
    }
    canvas.restore();

    // Specular highlight stays fixed (the light doesn't rotate with the ball)
    canvas.drawCircle(
      Offset(-r * 0.35, -r * 0.4),
      r * 0.22,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LanePainter old) =>
      old.rollT != rollT ||
      old.aim != aim ||
      old.curve != curve ||
      old.showGuide != showGuide ||
      !_listEq(old.deck, deck) ||
      old.fallStartT.length != fallStartT.length;

  static bool _listEq(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.55;
    final v = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final paint = Paint()
      ..color = color.withValues(alpha: (0.5 * (1 - v)).clamp(0.0, 0.5))
      ..strokeWidth = 3;
    for (int i = 0; i < 12; i++) {
      final ang = i * math.pi / 6 + v * 0.3;
      final inner = maxR * 0.25 + maxR * 0.5 * v;
      final outer = inner + maxR * 0.25;
      canvas.drawLine(
        center + Offset(math.cos(ang), math.sin(ang)) * inner,
        center + Offset(math.cos(ang), math.sin(ang)) * outer,
        paint,
      );
    }
    canvas.drawCircle(
      center,
      maxR * 0.4 * v,
      Paint()
        ..color = color.withValues(alpha: (0.25 * (1 - v)).clamp(0.0, 0.25))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}
