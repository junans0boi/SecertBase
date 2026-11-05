import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/socket_service.dart';
import '../../../widgets/game_menu.dart';
import '../../../widgets/game_scaffold.dart';
import 'tank/tank_battlefield.dart';
import 'tank/tank_controls.dart';
import 'tank/tank_data.dart';
import 'tank/tank_hud.dart';
import 'tank/tank_overlays.dart';
import 'tank/tank_painter.dart';
import 'tank/tank_playback.dart';
import 'tank/tank_sfx.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 탱크 대작전
// 모든 판정은 서버(fortress-engine.js)가 하고, 이 화면은 상태를 그리고
// shotResult.events를 재생한다. 그리기·조작부·효과음은 tank/ 폴더에 있다.
// ─────────────────────────────────────────────────────────────────────────────

class TankScreen extends StatefulWidget {
  const TankScreen({super.key});
  @override
  State<TankScreen> createState() => _TankScreenState();
}

class _TankScreenState extends State<TankScreen> with TickerProviderStateMixin {
  static const double _hudInset = 150;
  static const double _controlsInset = 205;

  final _socket = SocketService();
  final _sfx = TankSfx.instance;
  final _focusNode = FocusNode(debugLabel: 'tank');

  double _angle = 45;
  double _power = 50;
  String _weapon = 'basic';
  bool _aimInitialized = false;
  String? _pendingClass;
  bool _overview = false;

  Object? _lastShotRef;
  TankPlayback? _playback;
  late final AnimationController _playCtrl;
  double _playE = 0;
  int _cueIndex = 0;
  bool _settled = false;

  // 재생 중에는 발사 직전 상태로 그리고, 폭발 이후 새 상태를 보여준다.
  Map<String, dynamic>? _stableState;
  Map<String, dynamic>? _preShotState;
  List<Offset> _myLastTrace = const [];
  final List<TankScorch> _scorches = [];
  Object? _scorchGame;

  int _seenTimeoutSeq = 0;
  int _seenMoveSeq = 0;
  String _turnKey = '';
  bool _turnPrimed = false;
  TankBannerData? _banner;
  int _bannerSeq = 0;
  bool _suddenAnnounced = false;
  int _lastTickSecond = -1;
  String? _resultSoundKey;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _playCtrl = AnimationController(vsync: this)
      ..addListener(_onPlayTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onPlayDone();
      });
    _seenTimeoutSeq = _socket.tankTimeoutSeq;
    _seenMoveSeq = _socket.tankMoveSeq;
    _lastShotRef = _socket.tankLastShot;
    _stableState = _socket.tankState;
    _resultSoundKey = _socket.tankWinner == null ? null : _resultKey();
    _syncAimFromState();
    _socket.addListener(_onSocket);
    _sfx.init();
    // 턴 타이머 표시와 마지막 5초 경고음
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_isBattle) return;
      _timerTick();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _socket.removeListener(_onSocket);
    _playCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── state helpers ──────────────────────────────────────────────────────────

  Map<String, dynamic>? get _state => _socket.tankState;

  bool get _isBattle => _state?['phase'] == 'aiming';

  bool get _playing => _playback != null && _playCtrl.isAnimating;

  int get _myIndex {
    final players = _state?['players'] as List?;
    if (players == null) return 0;
    for (int i = 0; i < players.length; i++) {
      if ((players[i] as Map)['id'] == _socket.userId) return i;
    }
    return 0;
  }

  Map<String, dynamic>? _player(Map<String, dynamic>? state, int idx) {
    final players = state?['players'] as List?;
    if (players == null || idx < 0 || idx >= players.length) return null;
    return Map<String, dynamic>.from(players[idx] as Map);
  }

  bool get _isMyTurn {
    final state = _state;
    if (state == null || state['phase'] != 'aiming') return false;
    final turn = (state['turn'] as num?)?.toInt() ?? 0;
    return turn == _myIndex;
  }

  bool get _canAct => _isMyTurn && !_playing && _socket.tankWinner == null;

  /// 재생 중에는 발사 직전 상태를, 아니면 최신 상태를 그린다.
  Map<String, dynamic>? get _displayState {
    if (_playback != null && _preShotState != null && !_settled) {
      return _preShotState;
    }
    return _state;
  }

  String get _oppName {
    final opp = _player(_state, 1 - _myIndex);
    return _socket.presenceNicknames[opp?['id']] ?? '상대';
  }

  int? get _remainingMs {
    final deadline = (_state?['turnDeadline'] as num?)?.toInt();
    if (deadline == null) return null;
    return (deadline - DateTime.now().millisecondsSinceEpoch).clamp(
      0,
      kTankTurnMs,
    );
  }

  String _resultKey() =>
      '${_state?['gameId']}:${_socket.tankWinner}:${_socket.tankEndReason}';

  void _syncAimFromState() {
    final me = _player(_state, _myIndex);
    if (me == null) return;
    final ammo = me['ammo'] as Map?;
    if (ammo != null && !(ammo.containsKey(_weapon))) _weapon = 'basic';
    if (ammo != null) {
      final left = ammo[_weapon];
      if (left is num && left <= 0) _weapon = 'basic';
    }
    if (!_aimInitialized && me['angle'] != null) {
      _angle = (me['angle'] as num).toDouble();
      _power = (me['power'] as num?)?.toDouble() ?? 50;
      _aimInitialized = true;
    }
  }

  // ── socket ─────────────────────────────────────────────────────────────────

  void _onSocket() {
    if (!mounted) return;

    final shot = _socket.tankLastShot;
    if (shot != null && !identical(shot, _lastShotRef)) {
      _lastShotRef = shot;
      _startPlayback(shot);
    } else if (!_playing) {
      _stableState = _socket.tankState;
    }

    if (_socket.tankTimeoutSeq != _seenTimeoutSeq) {
      _seenTimeoutSeq = _socket.tankTimeoutSeq;
      final e = _socket.tankTimeoutEvent;
      if (e != null) {
        final mine = e['player'] == _socket.userId;
        final count = (e['count'] as num?)?.toInt() ?? 1;
        _snack(
          e['forfeited'] == true
              ? (mine ? '3턴 연속 시간 초과로 기권 처리됐어요' : '상대가 3턴 연속 시간을 넘겨 기권했어요')
              : (mine ? '시간 초과! 턴이 넘어갔어요 ($count/3)' : '상대 시간 초과 ($count/3)'),
        );
      }
    }

    if (_socket.tankMoveSeq != _seenMoveSeq) {
      _seenMoveSeq = _socket.tankMoveSeq;
      for (final raw in _socket.tankMoveEvents) {
        if (raw is Map && raw['type'] == 'crate') {
          final mine = (raw['owner'] as num?)?.toInt() == _myIndex;
          final item = kTankCrateNames[raw['item']] ?? '보급';
          _sfx.play(TankSound.pickup);
          _snack(mine ? '$item 획득!' : '상대가 $item을(를) 가져갔어요');
        }
      }
    }

    final state = _state;
    if (state != null) {
      if (state['gameId'] != _scorchGame) {
        _scorchGame = state['gameId'];
        _scorches.clear();
        _suddenAnnounced = false;
      }
      final key = '${state['turnNumber']}:${state['turn']}:${state['phase']}';
      if (key != _turnKey) {
        _turnKey = key;
        _syncAimFromState();
        if (state['phase'] == 'aiming' && _turnPrimed && !_playing) {
          _announceTurn();
        }
        _turnPrimed = true;
      }
      if (state['phase'] == 'select') {
        _aimInitialized = false;
        _overview = false;
      }
    }

    if (_socket.tankWinner != null && !_playing) _resultSound();
    setState(() {});
  }

  void _announceTurn() {
    final state = _state;
    if (state == null || state['phase'] != 'aiming') return;
    if (state['suddenDeath'] == true && !_suddenAnnounced) {
      _suddenAnnounced = true;
      _showBanner('서든데스!', TankUi.fireB, sub: '이제부터 피해 1.5배');
      _sfx.play(TankSound.warn);
      return;
    }
    if (_isMyTurn) {
      _showBanner('내 차례!', TankUi.me, sub: '드래그하거나 버튼으로 조준하세요');
      _sfx.play(TankSound.turnMine);
      HapticFeedback.selectionClick();
    } else {
      _showBanner('상대 차례', TankUi.enemy);
      _sfx.play(TankSound.turnOpp, volume: 0.7);
    }
  }

  void _showBanner(String text, Color color, {String? sub}) {
    _bannerSeq++;
    _banner = TankBannerData(_bannerSeq, text, color, sub: sub);
  }

  void _timerTick() {
    final remaining = _remainingMs;
    if (remaining == null || !_canAct) {
      _lastTickSecond = -1;
      return;
    }
    final seconds = (remaining / 1000).ceil();
    if (seconds <= 5 && seconds >= 1 && seconds != _lastTickSecond) {
      _lastTickSecond = seconds;
      _sfx.play(seconds <= 3 ? TankSound.warn : TankSound.tick, volume: 0.8);
    }
  }

  void _resultSound() {
    final key = _resultKey();
    if (_resultSoundKey == key) return;
    _resultSoundKey = key;
    final winner = _socket.tankWinner;
    if (winner == null) return;
    _sfx.play(winner == _socket.userId ? TankSound.win : TankSound.lose);
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1600),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ── playback ───────────────────────────────────────────────────────────────

  void _startPlayback(Map<String, dynamic> shot) {
    final pre = _stableState ?? _socket.tankState;
    final pb = TankPlayback.fromShot(shot, pre: pre);
    _preShotState = pre;
    _playback = pb;
    _playE = 0;
    _cueIndex = 0;
    _settled = false;
    if ((shot['shooter'] as num?)?.toInt() == _myIndex &&
        pb.shells.isNotEmpty) {
      _myLastTrace = pb.shells.first.path;
    }
    _playCtrl.duration = Duration(milliseconds: pb.rawTotalMs.round());
    _playCtrl.forward(from: 0);
  }

  void _onPlayTick() {
    final pb = _playback;
    if (pb == null) return;
    final raw = _playCtrl.value * pb.rawTotalMs;
    final now = pb.effective(raw);
    while (_cueIndex < pb.cues.length && pb.cues[_cueIndex].atMs <= now) {
      final cue = pb.cues[_cueIndex];
      _sfx.play(cue.sound, volume: cue.volume);
      _cueIndex++;
    }
    _playE = now;
    if (!_settled && now >= pb.settleMs) {
      _settled = true;
      setState(() {});
    }
  }

  void _onPlayDone() {
    if (!mounted) return;
    final pb = _playback;
    if (pb != null) {
      for (final b in pb.booms) {
        if (b.kind == TankBoomKind.blast ||
            b.kind == TankBoomKind.quake ||
            b.kind == TankBoomKind.drill ||
            b.kind == TankBoomKind.ko) {
          _scorches.add(TankScorch(b.col, b.radius));
        }
      }
      if (_scorches.length > 24) {
        _scorches.removeRange(0, _scorches.length - 24);
      }
    }
    setState(() {
      _playback = null;
      _preShotState = null;
      _playE = 0;
      _stableState = _socket.tankState;
    });
    if (_socket.tankWinner != null) {
      _resultSound();
    } else {
      _announceTurn();
    }
  }

  // ── actions ────────────────────────────────────────────────────────────────

  void _fire() {
    if (!_canAct) return;
    HapticFeedback.lightImpact();
    _socket.fireTank(
      angle: _angle.round(),
      power: _power.round(),
      weapon: _weapon,
    );
  }

  void _move(int delta) {
    if (!_canAct) return;
    _sfx.play(TankSound.engine, volume: 0.6);
    _socket.moveTank(delta);
  }

  void _selectWeapon(String w) {
    if (_weapon == w) return;
    _sfx.play(TankSound.click);
    setState(() => _weapon = w);
  }

  void _setAim(double angle, double power) {
    if (!_canAct) return;
    setState(() {
      _angle = angle.clamp(0, 180).toDouble();
      _power = power.clamp(1, 100).toDouble();
    });
  }

  void _nudgeAngle(double d) {
    if (!_canAct) return;
    setState(() => _angle = (_angle + d).clamp(0, 180).toDouble());
  }

  void _nudgePower(double d) {
    if (!_canAct) return;
    setState(() => _power = (_power + d).clamp(1, 100).toDouble());
  }

  void _previewClass(String id) {
    _sfx.play(TankSound.click);
    setState(() => _pendingClass = id);
  }

  void _confirmClass() {
    final id = _pendingClass;
    if (id == null) return;
    _sfx.play(TankSound.pickup);
    _socket.selectTankClass(id);
  }

  void _toggleMute() {
    final next = !_sfx.muted;
    _sfx.setMuted(next);
    if (!next) _sfx.play(TankSound.click);
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final step = HardwareKeyboard.instance.isShiftPressed ? 5.0 : 1.0;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _nudgeAngle(step);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _nudgeAngle(-step);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _nudgePower(step);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _nudgePower(-step);
    } else if (key == LogicalKeyboardKey.keyA) {
      if (event is KeyDownEvent) _move(-2);
    } else if (key == LogicalKeyboardKey.keyD) {
      if (event is KeyDownEvent) _move(2);
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter) {
      if (event is KeyDownEvent) _fire();
    } else {
      final label = key.keyLabel;
      final n = int.tryParse(label);
      if (n == null || n < 1 || n > 9) return KeyEventResult.ignored;
      final me = _player(_state, _myIndex);
      final ammo = (me?['ammo'] as Map?) ?? const {};
      final weapons = kTankWeaponOrder.where(ammo.containsKey).toList();
      if (n - 1 < weapons.length &&
          _canAct &&
          TankControls.hasAmmo(ammo[weapons[n - 1]])) {
        _selectWeapon(weapons[n - 1]);
      }
    }
    return KeyEventResult.handled;
  }

  /// 서버와 같은 물리로 예상 궤적의 앞부분만 보여준다(정확한 착탄점은 감으로).
  List<Offset> _previewPath(Map<String, dynamic> state) {
    final me = _player(state, _myIndex);
    final terrain = tankTerrainOf(state);
    if (me == null || terrain == null) return const [];
    final wind = (state['wind'] as num?)?.toDouble() ?? 0;
    final gravity =
        kTankGravity * ((state['gravityMul'] as num?)?.toDouble() ?? 1);
    final rad = _angle * math.pi / 180;
    final speed = _power * kTankSpeedScale;
    var vx = math.cos(rad) * speed;
    var vy = -math.sin(rad) * speed;
    var px = (me['col'] as num).toDouble();
    var py = (me['row'] as num).toDouble() - 1;
    final windAcc = wind * kTankWindScale;
    final pts = <Offset>[Offset(px, py)];
    for (int i = 0; i < 12000; i++) {
      vx += windAcc * kTankDt;
      vy += gravity * kTankDt;
      px += vx * kTankDt;
      py += vy * kTankDt;
      if (i % 5 == 0) pts.add(Offset(px, py));
      final col = px.round();
      final row = py.round();
      if (col < 0 || col >= kTerrainW || row >= kTerrainH) break;
      if (py >= 0 && row >= kTerrainH - terrain[col]) break;
    }
    final keep = (pts.length * 0.55).round();
    return pts.sublist(0, math.max(2, math.min(keep, pts.length)));
  }

  /// 상대 포신 각도: 조준은 비공개이므로 마지막 발사 각도를 쓴다.
  double? _opponentAngle() {
    final shot = _socket.tankLastShot;
    if (shot != null && (shot['shooter'] as num?)?.toInt() == 1 - _myIndex) {
      return (shot['angle'] as num?)?.toDouble();
    }
    return null;
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final sock = _socket;
    final menu = GameMenuButton(
      hasRestart: state != null,
      restartWaiting: sock.restartWaiting,
      onRequestRestart: () => sock.requestRestart('tank'),
      iconColor: Colors.white,
    );
    return GameMenuListener(
      gameType: 'tank',
      child: GameScaffold(
        title: '탱크 대작전',
        fullBleed: true,
        showAppBar: false,
        backgroundColor: TankUi.panelSolid,
        child: ColoredBox(
          color: TankUi.panelSolid,
          child: state == null
              ? const Center(child: CircularProgressIndicator())
              : Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: _onKey,
                  child: state['phase'] == 'select'
                      ? _buildSelect(state, menu)
                      : _buildBattle(state, menu),
                ),
        ),
      ),
    );
  }

  Widget _buildSelect(Map<String, dynamic> state, Widget menu) {
    final me = _player(state, _myIndex);
    final opp = _player(state, 1 - _myIndex);
    final locked = me?['tankClass'] != null;
    final pick = (me?['tankClass'] as String?) ?? _pendingClass;
    final oppPicked = opp?['classPicked'] == true || opp?['tankClass'] != null;
    // 배경: 이번 전장(전차는 숨김)
    final scenery = {...state, 'players': const [], 'crates': const []};
    return Stack(
      fit: StackFit.expand,
      children: [
        TankBattlefield(
          state: scenery,
          myIndex: _myIndex,
          playMs: () => 0,
          overview: true,
        ),
        TankSelectView(
          state: state,
          preview: pick,
          locked: locked,
          oppPicked: oppPicked,
          onPreview: _previewClass,
          onConfirm: _confirmClass,
        ),
        Positioned(
          top: 6,
          left: 8,
          right: 8,
          child: Row(
            children: [
              IconButton(
                tooltip: '게임 나가기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const Spacer(),
              menu,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBattle(Map<String, dynamic> state, Widget menu) {
    final display = _displayState ?? state;
    final winner = _socket.tankWinner;
    final showResult = winner != null && !_playing;
    final ended = winner != null || state['phase'] == 'result';
    final me = _player(state, _myIndex);
    final ammo = Map<String, dynamic>.from((me?['ammo'] as Map?) ?? const {});
    final canAct = _canAct;
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Stack(
      fit: StackFit.expand,
      children: [
        TankBattlefield(
          state: display,
          myIndex: _myIndex,
          playback: _playback,
          playMs: () => _playE,
          myAngle: _angle,
          myPower: _power,
          canAim: canAct && !ended,
          preview: (canAct && !ended) ? _previewPath(state) : const [],
          lastTrace: _myLastTrace,
          opponentAngle: _opponentAngle(),
          scorches: _scorches,
          oppName: _oppName,
          insetTop: _hudInset,
          insetBottom: ended ? 0 : _controlsInset,
          overview: _overview,
          onAim: _setAim,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TankHud(
            state: display,
            myIndex: _myIndex,
            myName: '나',
            oppName: _oppName,
            remainingMs: _playing ? null : _remainingMs,
            muted: _sfx.muted,
            overview: _overview,
            onBack: () => Navigator.of(context).pop(),
            onToggleMute: _toggleMute,
            onToggleOverview: () => setState(() => _overview = !_overview),
            menu: menu,
          ),
        ),
        if (!ended)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TankControls(
              ammo: ammo,
              weapon: _weapon,
              special: kTankClasses[me?['tankClass']]?.special,
              enabled: canAct,
              angle: _angle,
              power: _power,
              fuel: (me?['fuel'] as num?)?.toDouble() ?? 0,
              maxFuel: (me?['maxFuel'] as num?)?.toDouble() ?? 30,
              statusText: _playing
                  ? '포탄이 날아가는 중...'
                  : '상대 차례예요 · 바람과 지형을 살펴보세요',
              showKeyHints: wide,
              onWeapon: _selectWeapon,
              onAngle: _nudgeAngle,
              onPower: _nudgePower,
              onMove: _move,
              onFire: _fire,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: _hudInset + 20,
          child: TankTurnBanner(banner: _banner),
        ),
        if (showResult) Positioned.fill(child: _buildResult(winner)),
      ],
    );
  }

  Widget _buildResult(String winner) {
    final me = _socket.userId;
    final draw = winner == 'draw';
    final win = !draw && winner == me;
    final reasonText = switch (_socket.tankEndReason) {
      'ko' => win ? '상대 전차를 격파했어요!' : '전차가 격파됐어요',
      'mutual_ko' => '두 전차가 동시에 격파됐어요',
      'afk' => win ? '상대가 3턴 연속 시간을 넘겼어요' : '3턴 연속 시간 초과로 기권했어요',
      'time' => '제한 턴 종료 · 남은 체력 비율로 판정',
      'time_draw' => '제한 턴 종료 · 체력 비율이 같아요',
      _ => '',
    };
    final players = (_socket.tankSummary?['players'] as List?) ?? const [];
    Map<String, dynamic>? statsFor(String? id) {
      for (final p in players) {
        if (p is Map && p['id'] == id) return Map<String, dynamic>.from(p);
      }
      return null;
    }

    final oppId = _player(_state, 1 - _myIndex)?['id'] as String?;
    final series = _socket.tankSeries;
    return TankResultOverlay(
      key: ValueKey(_resultKey()),
      win: win,
      draw: draw,
      reason: reasonText,
      myWins: series[me] ?? 0,
      oppWins: series[oppId] ?? 0,
      mine: statsFor(me),
      theirs: statsFor(oppId),
      restartWaiting: _socket.restartWaiting,
      onExit: () => Navigator.of(context).pop(),
      onRematch: () => _socket.requestRestart('tank'),
    );
  }
}
