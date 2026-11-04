import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../core/main_design.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_menu.dart';
import '../../../widgets/game_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 탱크 대작전 2.0
// 모든 판정은 서버(fortress-engine.js)가 하고, 이 화면은 상태를 그리고
// shotResult.events를 순서대로 재생한다. 아래 상수는 서버와 같아야 한다.
// ─────────────────────────────────────────────────────────────────────────────

const int kTerrainW = 100;
const int kTerrainH = 40;
const double _kSpeedScale = 0.35;
const double _kGravity = 12.0;
const double _kWindScale = 1.5;
const double _kDt = 0.02;
const int _kTurnMs = 30000;

class _TankClassInfo {
  final String name;
  final int hp;
  final int fuel;
  final String special;
  final String desc;
  final IconData icon;
  const _TankClassInfo(
    this.name,
    this.hp,
    this.fuel,
    this.special,
    this.desc,
    this.icon,
  );
}

const Map<String, _TankClassInfo> _kClasses = {
  'rhino': _TankClassInfo(
    '코뿔소',
    130,
    24,
    'quake',
    '두꺼운 장갑으로 받는 피해 10% 감소.\n전용탄: 지진탄(넓은 범위 파괴)',
    Icons.shield_rounded,
  ),
  'falcon': _TankClassInfo(
    '매',
    90,
    45,
    'shotgun',
    '가벼운 차체로 이동 연료 절반.\n전용탄: 산탄(5발 부채꼴)',
    Icons.air_rounded,
  ),
  'mole': _TankClassInfo(
    '땅굴이',
    105,
    30,
    'drill',
    '낙하 피해를 받지 않아요.\n전용탄: 드릴탄(땅을 뚫고 폭발)',
    Icons.construction_rounded,
  ),
  'turtle': _TankClassInfo(
    '거북',
    115,
    28,
    'wall',
    '내 턴마다 HP 3 회복.\n전용탄: 방벽탄(흙 언덕 생성)',
    Icons.spa_rounded,
  ),
};

const Map<String, String> _kWeaponNames = {
  'basic': '기본탄',
  'heavy': '대형탄',
  'triple': '3연발탄',
  'cluster': '집속탄',
  'teleport': '순간이동탄',
  'quake': '지진탄',
  'shotgun': '산탄',
  'drill': '드릴탄',
  'wall': '방벽탄',
};

const List<String> _kWeaponOrder = [
  'basic',
  'heavy',
  'triple',
  'cluster',
  'teleport',
  'quake',
  'shotgun',
  'drill',
  'wall',
];

const Map<String, String> _kCrateNames = {
  'repair': '수리 키트',
  'power': '화력 강화',
  'shield': '보호막',
  'fuel': '연료 통',
  'ammo': '탄약 상자',
};

class _ThemeLook {
  final String name;
  final List<Color> sky;
  final Color ground;
  final Color groundTop;
  final Color far;
  final Color near;
  final bool stars;
  const _ThemeLook(
    this.name,
    this.sky,
    this.ground,
    this.groundTop,
    this.far,
    this.near,
    this.stars,
  );
}

const Map<String, _ThemeLook> _kThemes = {
  'meadow': _ThemeLook(
    '초원',
    [Color(0xFF7EC8F2), Color(0xFFD9F1FF)],
    Color(0xFF4E8A3A),
    Color(0xFF7BC25B),
    Color(0xFFB7D9C5),
    Color(0xFF8FC4A0),
    false,
  ),
  'desert': _ThemeLook(
    '사막',
    [Color(0xFFF6A55A), Color(0xFFFFE2B0)],
    Color(0xFFC98D4B),
    Color(0xFFE9B873),
    Color(0xFFE8C08E),
    Color(0xFFD9A46C),
    false,
  ),
  'snow': _ThemeLook(
    '설원',
    [Color(0xFF9DB7D6), Color(0xFFEAF2FB)],
    Color(0xFFB9C7D6),
    Color(0xFFFFFFFF),
    Color(0xFFD5E0EC),
    Color(0xFFC2D1E2),
    false,
  ),
  'moon': _ThemeLook(
    '달',
    [Color(0xFF0E0B24), Color(0xFF2E2A55)],
    Color(0xFF6E6E80),
    Color(0xFFA9A9BA),
    Color(0xFF3A3762),
    Color(0xFF4B4878),
    true,
  ),
};

// ── 재생(playback) 모델 ──────────────────────────────────────────────────────

class _Shell {
  final List<Offset> path;
  final int stage;
  const _Shell(this.path, this.stage);
}

class _Boom {
  final double col;
  final double row;
  final double radius;
  final int stage;
  final bool mound;
  const _Boom(this.col, this.row, this.radius, this.stage, this.mound);
}

class _Popup {
  final int target; // player index, -1이면 좌표 사용
  final String text;
  final Color color;
  final int stage;
  final double col;
  final double row;
  const _Popup(
    this.target,
    this.text,
    this.color,
    this.stage, {
    this.col = 0,
    this.row = 0,
  });
}

class _Playback {
  final List<_Shell> shells;
  final List<_Boom> booms;
  final List<_Popup> popups;
  final List<double> stageStartMs; // 각 단계 비행 시작
  final List<double> stageFlightMs; // 각 단계 비행 시간
  final double totalMs;
  final double shakePower;
  const _Playback({
    required this.shells,
    required this.booms,
    required this.popups,
    required this.stageStartMs,
    required this.stageFlightMs,
    required this.totalMs,
    required this.shakePower,
  });

  static const double boomMs = 650;

  /// 단계 s의 폭발 시작 시각(ms)
  double boomStart(int s) => stageStartMs[s] + stageFlightMs[s];

  /// 서버 shotResult.events로 재생 타임라인을 만든다.
  factory _Playback.fromShot(Map<String, dynamic> shot) {
    final events = (shot['events'] as List?) ?? const [];
    final shells = <_Shell>[];
    final booms = <_Boom>[];
    final popups = <_Popup>[];
    double shake = 0;
    int maxStage = 0;
    for (final raw in events) {
      if (raw is! Map) continue;
      final e = Map<String, dynamic>.from(raw);
      final stage = (e['stage'] as num?)?.toInt() ?? 0;
      if (stage > maxStage) maxStage = stage;
      switch (e['type']) {
        case 'shell':
          final pts = ((e['path'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (p) => Offset(
                  (p['x'] as num).toDouble(),
                  (p['y'] as num).toDouble(),
                ),
              )
              .toList();
          if (pts.length >= 2) shells.add(_Shell(pts, stage));
          break;
        case 'blast':
          booms.add(
            _Boom(
              (e['col'] as num).toDouble(),
              (e['row'] as num).toDouble(),
              (e['r'] as num?)?.toDouble() ?? 3,
              stage,
              false,
            ),
          );
          break;
        case 'mound':
          booms.add(
            _Boom(
              (e['col'] as num).toDouble(),
              kTerrainH / 2,
              (e['r'] as num?)?.toDouble() ?? 4,
              stage,
              true,
            ),
          );
          break;
        case 'damage':
          final amount = (e['amount'] as num?)?.toInt() ?? 0;
          final direct = e['direct'] == true;
          shake = math.max(shake, amount.toDouble());
          popups.add(
            _Popup(
              (e['target'] as num).toInt(),
              direct ? '직격! -$amount' : '-$amount',
              direct ? const Color(0xFFFF3D3D) : const Color(0xFFFF7A3D),
              stage,
            ),
          );
          break;
        case 'shield':
          popups.add(
            _Popup(
              (e['target'] as num).toInt(),
              '보호막 ${(e['absorbed'] as num?)?.toInt() ?? 0} 흡수',
              const Color(0xFF59C3FF),
              stage,
            ),
          );
          break;
        case 'crate':
          popups.add(
            _Popup(
              (e['owner'] as num?)?.toInt() ?? 0,
              '${_kCrateNames[e['item']] ?? '보급'} 획득!',
              const Color(0xFFFFC23D),
              maxStage,
            ),
          );
          break;
        case 'fall':
          final dmg = (e['damage'] as num?)?.toInt() ?? 0;
          if (dmg > 0) {
            popups.add(
              _Popup(
                (e['target'] as num).toInt(),
                '낙하 -$dmg',
                const Color(0xFFB07CFF),
                maxStage,
              ),
            );
          }
          break;
        case 'teleport':
          popups.add(
            _Popup(
              (e['target'] as num).toInt(),
              '순간이동!',
              const Color(0xFF8E7CFF),
              stage,
            ),
          );
          break;
        case 'sudden_death':
          popups.add(
            const _Popup(
              -1,
              '서든데스! 피해 1.5배',
              Color(0xFFFF4D6D),
              0,
              col: kTerrainW / 2,
              row: 8,
            ),
          );
          break;
        default:
          break;
      }
    }
    final stageStart = <double>[];
    final stageFlight = <double>[];
    double cursor = 0;
    for (int s = 0; s <= maxStage; s++) {
      final stageShells = shells.where((sh) => sh.stage == s);
      final longest = stageShells.fold<int>(
        0,
        (m, sh) => math.max(m, sh.path.length),
      );
      final double flight = longest == 0
          ? 0.0
          : (longest * (s == 0 ? 15.0 : 11.0)).clamp(450.0, 2400.0).toDouble();
      stageStart.add(cursor);
      stageFlight.add(flight);
      cursor += flight + boomMs;
    }
    return _Playback(
      shells: shells,
      booms: booms,
      popups: popups,
      stageStartMs: stageStart,
      stageFlightMs: stageFlight,
      totalMs: cursor + 500,
      shakePower: shake,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class TankScreen extends StatefulWidget {
  const TankScreen({super.key});
  @override
  State<TankScreen> createState() => _TankScreenState();
}

class _TankScreenState extends State<TankScreen> with TickerProviderStateMixin {
  final _socket = SocketService();

  double _angle = 45;
  double _power = 50;
  String _weapon = 'basic';
  bool _aimInitialized = false;
  String? _pendingClass;

  Object? _lastShotRef;
  _Playback? _playback;
  late final AnimationController _playCtrl;
  final Set<int> _hapticStages = {};

  // 재생 중에는 발사 직전 상태로 그리고, 폭발 이후 새 상태를 보여준다.
  Map<String, dynamic>? _stableState;
  Map<String, dynamic>? _preShotState;
  List<Offset> _myLastTrace = const [];

  int _seenTimeoutSeq = 0;
  int _seenMoveSeq = 0;
  String _turnKey = '';
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
    _syncAimFromState();
    _socket.addListener(_onSocket);
    // 턴 타이머 표시용 갱신
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _isBattle) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _socket.removeListener(_onSocket);
    _playCtrl.dispose();
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
    if (players == null || idx >= players.length) return null;
    return Map<String, dynamic>.from(players[idx] as Map);
  }

  bool get _isMyTurn {
    final state = _state;
    if (state == null || state['phase'] != 'aiming') return false;
    final turn = (state['turn'] as num?)?.toInt() ?? 0;
    return turn == _myIndex;
  }

  /// 재생 중에는 발사 직전 상태를, 아니면 최신 상태를 그린다.
  Map<String, dynamic>? get _displayState {
    final pb = _playback;
    if (pb != null && _preShotState != null) {
      final now = _playCtrl.value * pb.totalMs;
      final lastStage = pb.stageStartMs.length - 1;
      if (now < pb.boomStart(lastStage) + _Playback.boomMs * 0.5) {
        return _preShotState;
      }
    }
    return _state;
  }

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
          final item = _kCrateNames[raw['item']] ?? '보급';
          _snack(mine ? '$item 획득!' : '상대가 $item을(를) 가져갔어요');
        }
      }
    }

    // 새 턴이 시작되면 무기 상태를 다시 확인한다.
    final state = _state;
    if (state != null) {
      final key = '${state['turnNumber']}:${state['turn']}:${state['phase']}';
      if (key != _turnKey) {
        _turnKey = key;
        _syncAimFromState();
        if (state['phase'] == 'aiming' && _isMyTurn) {
          HapticFeedback.selectionClick();
        }
      }
      if (state['phase'] == 'select') {
        _aimInitialized = false;
      }
    }
    setState(() {});
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
    final pb = _Playback.fromShot(shot);
    _preShotState = _stableState ?? _socket.tankState;
    _playback = pb;
    _hapticStages.clear();
    if ((shot['shooter'] as num?)?.toInt() == _myIndex &&
        pb.shells.isNotEmpty) {
      _myLastTrace = pb.shells.first.path;
    }
    _playCtrl.duration = Duration(milliseconds: pb.totalMs.round());
    _playCtrl.forward(from: 0);
  }

  void _onPlayTick() {
    final pb = _playback;
    if (pb == null) return;
    final now = _playCtrl.value * pb.totalMs;
    for (int s = 0; s < pb.stageStartMs.length; s++) {
      if (now >= pb.boomStart(s) && !_hapticStages.contains(s)) {
        _hapticStages.add(s);
        if (pb.booms.any((b) => b.stage == s)) {
          if (pb.shakePower >= 30) {
            HapticFeedback.heavyImpact();
          } else {
            HapticFeedback.mediumImpact();
          }
        }
      }
    }
    setState(() {});
  }

  void _onPlayDone() {
    if (!mounted) return;
    setState(() {
      _playback = null;
      _preShotState = null;
      _stableState = _socket.tankState;
    });
  }

  // ── actions ────────────────────────────────────────────────────────────────

  void _fire() {
    if (!_isMyTurn || _playing) return;
    HapticFeedback.lightImpact();
    _socket.fireTank(
      angle: _angle.round(),
      power: _power.round(),
      weapon: _weapon,
    );
  }

  void _move(int delta) {
    if (!_isMyTurn || _playing) return;
    _socket.moveTank(delta);
  }

  void _pickClass(String id) {
    setState(() => _pendingClass = id);
    _socket.selectTankClass(id);
  }

  void _nudgeAngle(double d) =>
      setState(() => _angle = (_angle + d).clamp(0, 180).toDouble());

  void _nudgePower(double d) =>
      setState(() => _power = (_power + d).clamp(1, 100).toDouble());

  /// 서버와 같은 물리로 예상 궤적의 앞부분만 보여준다(정확한 착탄점은 감으로).
  List<Offset> _previewPath(Map<String, dynamic> state) {
    final me = _player(state, _myIndex);
    if (me == null) return const [];
    final terrain = (state['terrain'] as List).cast<num>();
    final wind = (state['wind'] as num?)?.toDouble() ?? 0;
    final gravity =
        _kGravity * ((state['gravityMul'] as num?)?.toDouble() ?? 1);
    final rad = _angle * math.pi / 180;
    final speed = _power * _kSpeedScale;
    var vx = math.cos(rad) * speed;
    var vy = -math.sin(rad) * speed;
    var px = (me['col'] as num).toDouble();
    var py = (me['row'] as num).toDouble() - 1;
    final windAcc = wind * _kWindScale;
    final pts = <Offset>[Offset(px, py)];
    for (int i = 0; i < 12000; i++) {
      vx += windAcc * _kDt;
      vy += gravity * _kDt;
      px += vx * _kDt;
      py += vy * _kDt;
      if (i % 5 == 0) pts.add(Offset(px, py));
      final col = px.round();
      final row = py.round();
      if (col < 0 || col >= kTerrainW || row >= kTerrainH) break;
      if (py >= 0 && row >= kTerrainH - terrain[col]) break;
    }
    final keep = (pts.length * 0.55).round();
    return pts.sublist(0, math.max(2, math.min(keep, pts.length)));
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final sock = _socket;
    return GameMenuListener(
      gameType: 'tank',
      child: GameScaffold(
        title: '탱크 대작전',
        fullBleed: true,
        actions: [
          GameMenuButton(
            hasRestart: state != null,
            restartWaiting: sock.restartWaiting,
            onRequestRestart: () => sock.requestRestart('tank'),
          ),
        ],
        child: state == null
            ? const Center(child: CircularProgressIndicator())
            : state['phase'] == 'select'
            ? _buildSelect(state)
            : _buildBattle(state),
      ),
    );
  }

  // ── 전차 선택 ───────────────────────────────────────────────────────────────

  Widget _buildSelect(Map<String, dynamic> state) {
    final me = _player(state, _myIndex);
    final opp = _player(state, 1 - _myIndex);
    final myPick = (me?['tankClass'] as String?) ?? _pendingClass;
    final oppPicked = opp?['classPicked'] == true || opp?['tankClass'] != null;
    final themeId = state['theme'] as String? ?? 'meadow';
    final look = _kThemes[themeId] ?? _kThemes['meadow']!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: look.sky,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              '전차를 고르세요',
              textAlign: TextAlign.center,
              style: mainTitle(
                size: 26,
                color: look.stars ? Colors.white : kMainInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '전장: ${look.name}${themeId == 'moon'
                  ? ' · 중력이 약하고 바람이 없어요'
                  : themeId == 'snow'
                  ? ' · 바람이 강해요'
                  : themeId == 'desert'
                  ? ' · 언덕이 높고 바람이 세요'
                  : ''}',
              textAlign: TextAlign.center,
              style: mainBody(
                size: 13,
                color: look.stars ? Colors.white70 : kMainSub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              oppPicked ? '상대가 선택을 마쳤어요' : '상대가 고르는 중이에요',
              textAlign: TextAlign.center,
              style: mainBody(
                size: 12,
                color: look.stars ? Colors.white60 : kMainMuted,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in _kClasses.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ClassCard(
                  id: entry.key,
                  info: entry.value,
                  selected: myPick == entry.key,
                  locked: me?['tankClass'] != null,
                  onTap: me?['tankClass'] != null
                      ? null
                      : () => _pickClass(entry.key),
                ),
              ),
            if (me?['tankClass'] != null)
              Text(
                '선택 완료! 상대를 기다리고 있어요',
                textAlign: TextAlign.center,
                style: mainBody(
                  size: 13,
                  color: look.stars ? Colors.white : kMainInk,
                  weight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 전투 ───────────────────────────────────────────────────────────────────

  Widget _buildBattle(Map<String, dynamic> state) {
    final display = _displayState ?? state;
    final winner = _socket.tankWinner;
    final showResult = winner != null && !_playing;
    final ended = winner != null || state['phase'] == 'result';
    return Column(
      children: [
        _buildHud(display),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (ctx, constraints) => CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _BattlefieldPainter(
                    state: display,
                    myIndex: _myIndex,
                    myAngle: _angle,
                    playback: _playback,
                    playMs: _playback == null
                        ? 0
                        : _playCtrl.value * _playback!.totalMs,
                    preview: (!ended && _isMyTurn && !_playing)
                        ? _previewPath(state)
                        : const [],
                    lastTrace: _myLastTrace,
                    opponentAngle: _opponentAngle(),
                  ),
                ),
              ),
              if (showResult) _buildResultOverlay(winner),
            ],
          ),
        ),
        if (!ended) _buildControls(state),
      ],
    );
  }

  /// 상대 포신 각도: 조준은 비공개이므로 마지막 발사 각도를 쓴다.
  double? _opponentAngle() {
    final shot = _socket.tankLastShot;
    if (shot != null && (shot['shooter'] as num?)?.toInt() == 1 - _myIndex) {
      return (shot['angle'] as num?)?.toDouble();
    }
    return null;
  }

  Widget _buildHud(Map<String, dynamic> state) {
    final me = _player(state, _myIndex);
    final opp = _player(state, 1 - _myIndex);
    final turn = (state['turn'] as num?)?.toInt() ?? 0;
    final turnNumber = (state['turnNumber'] as num?)?.toInt() ?? 0;
    final wind = (state['wind'] as num?)?.toDouble() ?? 0;
    final suddenDeath = state['suddenDeath'] == true;
    final deadline = (state['turnDeadline'] as num?)?.toInt();
    final remaining = deadline == null
        ? null
        : (deadline - DateTime.now().millisecondsSinceEpoch).clamp(0, _kTurnMs);
    final nick = _socket.presenceNicknames;
    return Container(
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: _PlayerPanel(
              name: '나',
              player: me,
              active: turn == _myIndex && state['phase'] == 'aiming',
              mine: true,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WindGauge(wind: wind),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (remaining != null && state['phase'] == 'aiming')
                      _TimerRing(remainingMs: remaining.toInt()),
                    const SizedBox(width: 4),
                    Text(
                      '${turnNumber + 1}턴',
                      style: mainBody(size: 10, color: kMainMuted),
                    ),
                  ],
                ),
                if (suddenDeath)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: kMainRose,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '서든데스',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _PlayerPanel(
              name: nick[opp?['id']] ?? '상대',
              player: opp,
              active: turn == 1 - _myIndex && state['phase'] == 'aiming',
              mine: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(Map<String, dynamic> state) {
    final myTurn = _isMyTurn && !_playing;
    final me = _player(state, _myIndex);
    final fuel = (me?['fuel'] as num?)?.toDouble() ?? 0;
    final maxFuel = (me?['maxFuel'] as num?)?.toDouble() ?? 30;
    final ammo = (me?['ammo'] as Map?) ?? const {};
    final myClass = _kClasses[me?['tankClass']];
    final weapons = _kWeaponOrder.where(ammo.containsKey).toList();

    return Container(
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final w in weapons)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _WeaponChip(
                      label: _kWeaponNames[w] ?? w,
                      count: _ammoLabel(ammo[w]),
                      selected: _weapon == w,
                      special: myClass?.special == w,
                      enabled: myTurn && _hasAmmo(ammo[w]),
                      onTap: (myTurn && _hasAmmo(ammo[w]))
                          ? () => setState(() => _weapon = w)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          _AimRow(
            label: '각도',
            value: _angle,
            min: 0,
            max: 180,
            unit: '°',
            enabled: myTurn,
            onChanged: (v) => setState(() => _angle = v),
            onNudge: _nudgeAngle,
          ),
          _AimRow(
            label: '파워',
            value: _power,
            min: 1,
            max: 100,
            unit: '',
            enabled: myTurn,
            onChanged: (v) => setState(() => _power = v),
            onNudge: _nudgePower,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: myTurn ? () => _move(-2) : null,
                tooltip: '왼쪽으로 이동',
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxFuel <= 0
                            ? 0
                            : (fuel / maxFuel).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: kMainLine,
                        valueColor: const AlwaysStoppedAnimation(kMainSky),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '연료 ${fuel.floor()}/${maxFuel.round()}',
                      style: mainBody(size: 10, color: kMainMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: myTurn ? () => _move(2) : null,
                tooltip: '오른쪽으로 이동',
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text(
                    '발사!',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myTurn ? kMainRose : kMainMuted,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: myTurn ? _fire : null,
                ),
              ),
            ],
          ),
          if (!myTurn)
            Text(
              _playing ? '포탄이 날아가는 중...' : '상대방 턴이에요. 바람과 지형을 살펴보세요',
              style: mainBody(size: 11, color: kMainMuted),
            ),
        ],
      ),
    );
  }

  static bool _hasAmmo(dynamic raw) => raw is num && raw > 0;

  static String _ammoLabel(dynamic raw) {
    if (raw is! num) return '0';
    return raw >= 900 ? '∞' : '${raw.toInt()}';
  }

  // ── 결과 ───────────────────────────────────────────────────────────────────

  Widget _buildResultOverlay(String winner) {
    final me = _socket.userId;
    final draw = winner == 'draw';
    final win = !draw && winner == me;
    final reason = _socket.tankEndReason;
    final reasonText = switch (reason) {
      'ko' => win ? '상대 전차를 격파했어요!' : '전차가 격파됐어요',
      'mutual_ko' => '두 전차가 동시에 격파됐어요',
      'afk' => win ? '상대가 3턴 연속 시간을 넘겼어요' : '3턴 연속 시간 초과로 기권했어요',
      'time' => '제한 턴 종료 · 남은 체력 비율로 판정',
      'time_draw' => '제한 턴 종료 · 체력 비율이 같아요',
      _ => '',
    };
    final summary = _socket.tankSummary;
    final players = (summary?['players'] as List?) ?? const [];
    Map<String, dynamic>? statsFor(String? id) {
      for (final p in players) {
        if (p is Map && p['id'] == id) return Map<String, dynamic>.from(p);
      }
      return null;
    }

    final oppId = _player(_state, 1 - _myIndex)?['id'] as String?;
    final mine = statsFor(me);
    final theirs = statsFor(oppId);
    final series = _socket.tankSeries;
    final myWins = series[me] ?? 0;
    final oppWins = series[oppId] ?? 0;
    final color = draw ? kMainSky : (win ? kMainHoney : kMainRose);

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                draw ? '무승부' : (win ? '승리!' : '패배...'),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              if (reasonText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  reasonText,
                  textAlign: TextAlign.center,
                  style: mainBody(size: 13, color: kMainSub),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '시리즈  나 $myWins : $oppWins 상대',
                style: mainBody(
                  size: 15,
                  color: kMainInk,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _StatsTable(mine: mine, theirs: theirs),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('나가기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMainRose,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _socket.restartWaiting
                          ? null
                          : () => _socket.requestRestart('tank'),
                      child: Text(
                        _socket.restartWaiting ? '상대 응답 대기 중' : '재대결',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 하위 위젯 ────────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  final String id;
  final _TankClassInfo info;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  const _ClassCard({
    required this.id,
    required this.info,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? kMainRose : kMainLine;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: selected ? 1 : 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent, width: selected ? 2.4 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: kMainRoseSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(info.icon, color: kMainRose, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(info.name, style: mainTitle(size: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'HP ${info.hp} · 연료 ${info.fuel}',
                        style: mainBody(size: 11, color: kMainMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(info.desc, style: mainBody(size: 12, color: kMainSub)),
                ],
              ),
            ),
            if (selected)
              Icon(
                locked ? Icons.lock_rounded : Icons.check_circle_rounded,
                color: kMainRose,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  final String name;
  final Map<String, dynamic>? player;
  final bool active;
  final bool mine;

  const _PlayerPanel({
    required this.name,
    required this.player,
    required this.active,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    final hp = (player?['hp'] as num?)?.toInt() ?? 0;
    final maxHp = math.max(1, (player?['maxHp'] as num?)?.toInt() ?? 100);
    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    final buffs = (player?['buffs'] as Map?) ?? const {};
    final cls = _kClasses[player?['tankClass']];
    final barColor = ratio > 0.5
        ? kMainSage
        : ratio > 0.25
        ? kMainHoney
        : kMainError;
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: kMainRose,
                ),
              ),
            Flexible(
              child: Text(
                cls == null ? name : '$name · ${cls.name}',
                overflow: TextOverflow.ellipsis,
                style: mainBody(
                  size: 11,
                  color: active ? kMainInk : kMainSub,
                  weight: active ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: kMainLine,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$hp/$maxHp', style: mainBody(size: 10, color: kMainMuted)),
            if (buffs['power'] == true)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 13,
                  color: Color(0xFFFF7A3D),
                ),
              ),
            if (buffs['shield'] == true)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.shield_moon_rounded,
                  size: 13,
                  color: Color(0xFF59C3FF),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WindGauge extends StatelessWidget {
  final double wind;
  const _WindGauge({required this.wind});

  @override
  Widget build(BuildContext context) {
    final strength = wind.abs().clamp(0.0, 2.0) / 2.0;
    final right = wind >= 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          wind.abs() < 0.05
              ? '바람 없음'
              : '바람 ${right ? '→' : '←'} ${wind.abs().toStringAsFixed(1)}',
          style: mainBody(size: 10, color: kMainSub, weight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 84,
          height: 6,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: kMainLine,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: right ? 0 : strength,
                            heightFactor: 1,
                            child: Container(color: kMainSky),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: right ? strength : 0,
                            heightFactor: 1,
                            child: Container(color: kMainSky),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimerRing extends StatelessWidget {
  final int remainingMs;
  const _TimerRing({required this.remainingMs});

  @override
  Widget build(BuildContext context) {
    final ratio = (remainingMs / _kTurnMs).clamp(0.0, 1.0);
    final seconds = (remainingMs / 1000).ceil();
    final color = seconds <= 5 ? kMainError : kMainRose;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: ratio,
            strokeWidth: 3,
            backgroundColor: kMainLine,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '$seconds',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AimRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onNudge;

  const _AimRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.enabled,
    required this.onChanged,
    required this.onNudge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(label, style: mainBody(size: 11, color: kMainMuted)),
        ),
        _NudgeButton(
          icon: Icons.remove_rounded,
          onTap: enabled ? () => onNudge(-1) : null,
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
        _NudgeButton(
          icon: Icons.add_rounded,
          onTap: enabled ? () => onNudge(1) : null,
        ),
        SizedBox(
          width: 38,
          child: Text(
            '${value.round()}$unit',
            textAlign: TextAlign.right,
            style: mainBody(size: 12, color: kMainInk, weight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NudgeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap == null ? kMainLine : kMainRoseSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? kMainMuted : kMainRose,
        ),
      ),
    );
  }
}

class _WeaponChip extends StatelessWidget {
  final String label;
  final String count;
  final bool selected;
  final bool special;
  final bool enabled;
  final VoidCallback? onTap;

  const _WeaponChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.special,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = special ? kMainLilac : kMainHoney;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? base : kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? base : base.withValues(alpha: 0.35),
            width: special ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              special ? '★ $label' : label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : enabled
                    ? kMainInk
                    : kMainMuted,
              ),
            ),
            Text(
              count,
              style: TextStyle(
                fontSize: 9,
                color: selected ? Colors.white70 : kMainMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  final Map<String, dynamic>? mine;
  final Map<String, dynamic>? theirs;
  const _StatsTable({required this.mine, required this.theirs});

  int _stat(Map<String, dynamic>? p, String key) {
    final stats = p?['stats'] as Map?;
    return (stats?[key] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String)>[
      (
        '가한 피해',
        '${_stat(mine, 'damageDealt')}',
        '${_stat(theirs, 'damageDealt')}',
      ),
      (
        '명중률',
        '${(mine?['accuracy'] as num?)?.toInt() ?? 0}%',
        '${(theirs?['accuracy'] as num?)?.toInt() ?? 0}%',
      ),
      ('직격', '${_stat(mine, 'directHits')}', '${_stat(theirs, 'directHits')}'),
      ('최대 한 방', '${_stat(mine, 'maxHit')}', '${_stat(theirs, 'maxHit')}'),
      ('보급 획득', '${_stat(mine, 'crates')}', '${_stat(theirs, 'crates')}'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 64,
                child: Text(
                  '나',
                  textAlign: TextAlign.center,
                  style: mainBody(size: 11, color: kMainMuted),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '상대',
                  textAlign: TextAlign.center,
                  style: mainBody(size: 11, color: kMainMuted),
                ),
              ),
            ],
          ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.$1,
                      style: mainBody(size: 12, color: kMainSub),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      r.$2,
                      textAlign: TextAlign.center,
                      style: mainBody(
                        size: 13,
                        color: kMainInk,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      r.$3,
                      textAlign: TextAlign.center,
                      style: mainBody(size: 13, color: kMainSub),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── CustomPainter ────────────────────────────────────────────────────────────

class _BattlefieldPainter extends CustomPainter {
  final Map<String, dynamic> state;
  final int myIndex;
  final double myAngle;
  final _Playback? playback;
  final double playMs;
  final List<Offset> preview;
  final List<Offset> lastTrace;
  final double? opponentAngle;

  const _BattlefieldPainter({
    required this.state,
    required this.myIndex,
    required this.myAngle,
    required this.playback,
    required this.playMs,
    required this.preview,
    required this.lastTrace,
    required this.opponentAngle,
  });

  _ThemeLook get _look =>
      _kThemes[state['theme'] as String? ?? 'meadow'] ?? _kThemes['meadow']!;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / kTerrainW;
    final ch = size.height / kTerrainH;
    final look = _look;

    // 화면 흔들림: 폭발 직후 짧게
    final pb = playback;
    double shakeX = 0, shakeY = 0;
    if (pb != null) {
      for (int s = 0; s < pb.stageStartMs.length; s++) {
        final t = playMs - pb.boomStart(s);
        if (t >= 0 && t < 320 && pb.booms.any((b) => b.stage == s)) {
          final amp = (pb.shakePower / 12).clamp(1.0, 6.0) * (1 - t / 320);
          shakeX = math.sin(t / 18) * amp;
          shakeY = math.cos(t / 23) * amp * 0.6;
        }
      }
    }

    canvas.save();
    canvas.translate(shakeX, shakeY);

    // 하늘
    final skyRect = Rect.fromLTWH(-10, -10, size.width + 20, size.height + 20);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: look.sky,
        ).createShader(skyRect),
    );
    if (look.stars) {
      final rand = math.Random(7);
      final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
      for (int i = 0; i < 60; i++) {
        canvas.drawCircle(
          Offset(
            rand.nextDouble() * size.width,
            rand.nextDouble() * size.height * 0.55,
          ),
          rand.nextDouble() * 1.2 + 0.3,
          star,
        );
      }
    }

    // 원경 산 2겹
    _drawRidge(canvas, size, look.far, 0.42, 11, 0.9);
    _drawRidge(canvas, size, look.near, 0.55, 17, 2.3);

    // 지형
    final terrain = ((state['terrain'] as List?) ?? const []).cast<num>();
    if (terrain.length == kTerrainW) {
      final ground = Path()..moveTo(0, size.height);
      for (int x = 0; x < kTerrainW; x++) {
        final top = (kTerrainH - terrain[x]) * ch;
        ground.lineTo(x * cw, top);
        ground.lineTo((x + 1) * cw, top);
      }
      ground
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(ground, Paint()..color = look.ground);
      final edge = Paint()
        ..color = look.groundTop
        ..strokeWidth = math.max(2, ch * 0.45)
        ..style = PaintingStyle.stroke;
      final topLine = Path();
      for (int x = 0; x < kTerrainW; x++) {
        final top = (kTerrainH - terrain[x]) * ch;
        if (x == 0) {
          topLine.moveTo(0, top);
        } else {
          topLine.lineTo(x * cw, top);
        }
        topLine.lineTo((x + 1) * cw, top);
      }
      canvas.drawPath(topLine, edge);
    }

    // 보급 상자(낙하산)
    for (final raw in (state['crates'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final cx = (raw['col'] as num).toDouble() * cw;
      final cy = (raw['row'] as num).toDouble() * ch;
      _drawCrate(canvas, Offset(cx, cy), cw, ch);
    }

    // 직전 내 포탄 궤적(희미하게)
    if (lastTrace.length >= 2) {
      final p = Paint()..color = Colors.white.withValues(alpha: 0.28);
      for (int i = 0; i < lastTrace.length; i += 3) {
        canvas.drawCircle(
          Offset(lastTrace[i].dx * cw, lastTrace[i].dy * ch),
          1.1,
          p,
        );
      }
    }

    // 조준 미리보기
    if (preview.length >= 2) {
      for (int i = 0; i < preview.length; i += 2) {
        final fade = 1.0 - (i / preview.length) * 0.75;
        canvas.drawCircle(
          Offset(preview[i].dx * cw, preview[i].dy * ch),
          1.8,
          Paint()..color = Colors.white.withValues(alpha: 0.75 * fade),
        );
      }
    }

    // 전차
    final players = (state['players'] as List?) ?? const [];
    for (int i = 0; i < players.length; i++) {
      final p = Map<String, dynamic>.from(players[i] as Map);
      final angle = i == myIndex
          ? myAngle
          : (opponentAngle ?? (p['facingRight'] == true ? 45.0 : 135.0));
      _drawTank(
        canvas,
        Offset(
          (p['col'] as num).toDouble() * cw,
          (p['row'] as num).toDouble() * ch,
        ),
        cw,
        ch,
        i == myIndex,
        p['tankClass'] as String?,
        angle,
        (p['buffs'] as Map?)?['shield'] == true,
        ((p['hp'] as num?) ?? 0) <= 0,
      );
    }

    // 재생: 포탄 · 폭발 · 팝업
    if (pb != null) _paintPlayback(canvas, pb, cw, ch, players);

    canvas.restore();
  }

  void _drawRidge(
    Canvas canvas,
    Size size,
    Color color,
    double baseRatio,
    int seed,
    double freq,
  ) {
    final rand = math.Random(seed);
    final phase = rand.nextDouble() * math.pi * 2;
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += size.width / 40) {
      final t = x / size.width;
      final y =
          size.height * baseRatio +
          math.sin(t * math.pi * freq + phase) * size.height * 0.06 +
          math.sin(t * math.pi * freq * 2.7) * size.height * 0.025;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.8));
  }

  void _drawCrate(Canvas canvas, Offset bottom, double cw, double ch) {
    final w = cw * 2.4;
    final h = ch * 1.4;
    final box = Rect.fromCenter(
      center: Offset(bottom.dx, bottom.dy - h * 0.15),
      width: w,
      height: h,
    );
    // 낙하산
    final canopy = Rect.fromCenter(
      center: Offset(bottom.dx, box.top - h * 1.4),
      width: w * 2,
      height: h * 1.6,
    );
    canvas.drawArc(
      canopy,
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFF8FB1).withValues(alpha: 0.85),
    );
    final cord = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas.drawLine(canopy.centerLeft, box.topLeft, cord);
    canvas.drawLine(canopy.centerRight, box.topRight, cord);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(2)),
      Paint()..color = const Color(0xFFC88A3A),
    );
    canvas.drawLine(
      box.topLeft,
      box.bottomRight,
      Paint()
        ..color = const Color(0xFF8A5A1E)
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      box.topRight,
      box.bottomLeft,
      Paint()
        ..color = const Color(0xFF8A5A1E)
        ..strokeWidth = 1.2,
    );
  }

  void _drawTank(
    Canvas canvas,
    Offset pos,
    double cw,
    double ch,
    bool mine,
    String? cls,
    double angle,
    bool shielded,
    bool destroyed,
  ) {
    final base = mine ? const Color(0xFF3DAA6D) : const Color(0xFFE05555);
    final color = destroyed ? const Color(0xFF555555) : base;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final body = Paint()..color = color;

    final bodyW = switch (cls) {
      'rhino' => cw * 4.0,
      'falcon' => cw * 3.0,
      _ => cw * 3.4,
    };
    final bodyH = switch (cls) {
      'rhino' => ch * 1.3,
      'falcon' => ch * 0.9,
      _ => ch * 1.1,
    };

    // 궤도
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pos.dx, pos.dy + ch * 0.7),
          width: bodyW + cw * 0.8,
          height: ch * 0.6,
        ),
        Radius.circular(ch * 0.3),
      ),
      Paint()..color = dark,
    );
    // 차체
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: bodyW, height: bodyH),
        Radius.circular(ch * 0.35),
      ),
      body,
    );

    final turret = Offset(pos.dx, pos.dy - bodyH * 0.45);
    switch (cls) {
      case 'turtle':
        canvas.drawArc(
          Rect.fromCenter(center: turret, width: cw * 3.0, height: ch * 2.0),
          math.pi,
          math.pi,
          true,
          Paint()..color = Color.lerp(color, Colors.white, 0.15)!,
        );
        break;
      case 'mole':
        final dir = (angle <= 90) ? 1.0 : -1.0;
        final nose = Path()
          ..moveTo(pos.dx + dir * bodyW * 0.5, pos.dy - bodyH * 0.4)
          ..lineTo(pos.dx + dir * (bodyW * 0.5 + cw * 1.2), pos.dy)
          ..lineTo(pos.dx + dir * bodyW * 0.5, pos.dy + bodyH * 0.4)
          ..close();
        canvas.drawPath(nose, Paint()..color = const Color(0xFFB0B0B8));
        canvas.drawCircle(turret, cw * 1.0, body);
        break;
      case 'rhino':
        canvas.drawCircle(turret, cw * 1.3, body);
        break;
      case 'falcon':
        final fin = Path()
          ..moveTo(pos.dx - bodyW * 0.45, pos.dy - bodyH * 0.4)
          ..lineTo(pos.dx - bodyW * 0.15, pos.dy - bodyH * 1.3)
          ..lineTo(pos.dx, pos.dy - bodyH * 0.4)
          ..close();
        canvas.drawPath(fin, Paint()..color = dark);
        canvas.drawCircle(turret, cw * 0.9, body);
        break;
      default:
        canvas.drawCircle(turret, cw * 1.1, body);
    }

    // 포신
    final rad = -angle * math.pi / 180.0;
    final len = cw * (cls == 'rhino' ? 2.8 : 2.4);
    canvas.drawLine(
      turret,
      Offset(turret.dx + math.cos(rad) * len, turret.dy + math.sin(rad) * len),
      Paint()
        ..color = dark
        ..strokeWidth = cw * (cls == 'rhino' ? 1.1 : 0.85)
        ..strokeCap = StrokeCap.round,
    );

    if (shielded && !destroyed) {
      canvas.drawCircle(
        Offset(pos.dx, pos.dy - ch * 0.2),
        cw * 3.2,
        Paint()
          ..color = const Color(0xFF59C3FF).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (mine) {
      // 내 전차 표시 삼각형
      final tip = Offset(pos.dx, pos.dy - bodyH - ch * 2.2);
      final marker = Path()
        ..moveTo(tip.dx - cw * 0.8, tip.dy - ch * 0.7)
        ..lineTo(tip.dx + cw * 0.8, tip.dy - ch * 0.7)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      canvas.drawPath(
        marker,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  void _paintPlayback(
    Canvas canvas,
    _Playback pb,
    double cw,
    double ch,
    List players,
  ) {
    // 포탄
    for (final shell in pb.shells) {
      final s = shell.stage;
      if (s >= pb.stageStartMs.length) continue;
      final start = pb.stageStartMs[s];
      final flight = pb.stageFlightMs[s];
      final t = flight <= 0 ? 1.0 : ((playMs - start) / flight);
      if (t < 0 || t > 1) continue;
      final pts = shell.path;
      final head = (t * (pts.length - 1)).round().clamp(0, pts.length - 1);
      const trail = 12;
      for (int i = math.max(0, head - trail); i < head; i++) {
        final fade = 1.0 - (head - i) / trail;
        canvas.drawCircle(
          Offset(pts[i].dx * cw, pts[i].dy * ch),
          1.1 + fade * 1.5,
          Paint()..color = Colors.orangeAccent.withValues(alpha: 0.55 * fade),
        );
      }
      final hp = Offset(pts[head].dx * cw, pts[head].dy * ch);
      canvas.drawCircle(
        hp,
        6,
        Paint()..color = Colors.orange.withValues(alpha: 0.35),
      );
      canvas.drawCircle(hp, 3.2, Paint()..color = Colors.yellowAccent);
      canvas.drawCircle(hp, 1.5, Paint()..color = Colors.white);
    }

    // 폭발 / 방벽
    for (final b in pb.booms) {
      if (b.stage >= pb.stageStartMs.length) continue;
      final t = (playMs - pb.boomStart(b.stage)) / _Playback.boomMs;
      if (t < 0 || t > 1) continue;
      final center = Offset(b.col * cw, b.row * ch);
      if (b.mound) {
        canvas.drawCircle(
          Offset(b.col * cw, center.dy),
          b.radius * cw * (0.5 + t),
          Paint()
            ..color = const Color(0xFFC9A26B).withValues(alpha: (1 - t) * 0.6),
        );
        continue;
      }
      final alpha = (1 - t).clamp(0.0, 1.0);
      final radius = b.radius * cw * (0.6 + t * 1.6);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.deepOrange.withValues(alpha: alpha * 0.75),
      );
      canvas.drawCircle(
        center,
        radius * 0.6,
        Paint()..color = Colors.orangeAccent.withValues(alpha: alpha * 0.85),
      );
      canvas.drawCircle(
        center,
        radius * 0.28,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
      );
      // 파편 입자
      final rand = math.Random((b.col * 31 + b.row * 7).round());
      final debris = Paint()
        ..color = const Color(0xFF6B4A2B).withValues(alpha: alpha);
      for (int i = 0; i < 14; i++) {
        final dir = rand.nextDouble() * math.pi * 2;
        final speed = (0.6 + rand.nextDouble()) * b.radius * cw * 1.8;
        final dx = math.cos(dir) * speed * t;
        final dy = math.sin(dir) * speed * t + 40 * t * t; // 중력
        canvas.drawCircle(
          center.translate(dx, dy),
          1.4 + rand.nextDouble() * 1.6,
          debris,
        );
      }
    }

    // 팝업(피해 숫자 등): 해당 단계 폭발 시작부터 1.1초간 떠오른다
    for (final popup in pb.popups) {
      if (popup.stage >= pb.stageStartMs.length) continue;
      final t = (playMs - pb.boomStart(popup.stage)) / 1100;
      if (t < 0 || t > 1) continue;
      Offset anchor;
      if (popup.target >= 0 && popup.target < players.length) {
        final p = players[popup.target] as Map;
        anchor = Offset(
          (p['col'] as num).toDouble() * cw,
          (p['row'] as num).toDouble() * ch - ch * 3.2,
        );
      } else {
        anchor = Offset(popup.col * cw, popup.row * ch);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            color: popup.color.withValues(alpha: (1 - t * 0.8).clamp(0.0, 1.0)),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(anchor.dx - tp.width / 2, anchor.dy - 24 * t));
    }
  }

  @override
  bool shouldRepaint(_BattlefieldPainter old) => true;
}
