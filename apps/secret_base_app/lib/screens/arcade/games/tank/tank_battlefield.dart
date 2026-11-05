import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'tank_camera.dart';
import 'tank_painter.dart';
import 'tank_playback.dart';

/// 전장 위젯: 카메라 추적, 날씨·연기 애니메이션, 끌어서 조준을 맡는다.
/// 매 프레임 이 위젯만 다시 그리고, 바깥 HUD·조작부는 다시 만들지 않는다.
class TankBattlefield extends StatefulWidget {
  final Map<String, dynamic> state;
  final int myIndex;
  final TankPlayback? playback;

  /// 현재 재생 유효 시간(ms)을 돌려준다.
  final double Function() playMs;
  final double myAngle;
  final double myPower;

  /// 내 차례이고 재생 중이 아님.
  final bool canAim;
  final List<Offset> preview;
  final List<Offset> lastTrace;
  final double? opponentAngle;
  final List<TankScorch> scorches;
  final String myName;
  final String oppName;
  final double insetTop;
  final double insetBottom;
  final bool overview;
  final void Function(double angle, double power)? onAim;

  /// 미니맵·화면 밖 전차 표시(전투 화면).
  final bool showGuides;
  final VoidCallback? onMinimapTap;

  const TankBattlefield({
    super.key,
    required this.state,
    required this.myIndex,
    required this.playMs,
    this.playback,
    this.myAngle = 45,
    this.myPower = 50,
    this.canAim = false,
    this.preview = const [],
    this.lastTrace = const [],
    this.opponentAngle,
    this.scorches = const [],
    this.myName = '나',
    this.oppName = '상대',
    this.insetTop = 0,
    this.insetBottom = 0,
    this.overview = false,
    this.onAim,
    this.showGuides = false,
    this.onMinimapTap,
  });

  @override
  State<TankBattlefield> createState() => _TankBattlefieldState();
}

class _TankBattlefieldState extends State<TankBattlefield>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  TankView? _view;
  Size _size = Size.zero;
  final Map<String, double> _crateDrops = {};
  final Set<String> _seenCrates = {};
  bool _cratesPrimed = false;
  Offset? _drag;

  /// 게임을 시작하면 잠시 전장 전체를 보여준 뒤 확대한다.
  double _introUntil = -1;
  Object? _introGame;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    _time += dt;
    _trackCrates();
    _checkIntro();
    if (_size.width > 0 && _size.height > 0) {
      final target = _targetView();
      final speed = widget.playback != null ? 6.5 : 3.2;
      final current = _view;
      _view = current == null
          ? target
          : current.lerpTo(target, TankCamera.smoothing(dt, speed: speed));
    }
    if (mounted) setState(() {});
  }

  TankView _targetView() => TankCamera.target(
    size: _size,
    insetTop: widget.insetTop,
    insetBottom: widget.insetBottom,
    focus: _focus(),
    overview:
        widget.overview || (widget.playback == null && _time < _introUntil),
  );

  void _checkIntro() {
    final st = widget.state;
    if (st['phase'] != 'aiming') return;
    // 서버 상태에 gameId가 없을 수 있어 지형 seed로 판을 구분한다.
    final game = st['gameId'] ?? st['seed'];
    if (game == _introGame) return;
    _introGame = game;
    final turnNumber = (st['turnNumber'] as num?)?.toInt() ?? 0;
    if (turnNumber <= 1) _introUntil = _time + 2.6;
  }

  void _trackCrates() {
    final crates = (widget.state['crates'] as List?) ?? const [];
    for (final raw in crates) {
      if (raw is! Map) continue;
      // 서버의 보급 상자 id는 'c1' 같은 문자열이다.
      final id = raw['id']?.toString();
      if (id == null || _seenCrates.contains(id)) continue;
      _seenCrates.add(id);
      // 화면을 연 순간 이미 있던 상자는 떨어지는 연출 없이 둔다.
      if (_cratesPrimed) _crateDrops[id] = _time;
    }
    _cratesPrimed = true;
  }

  Offset _playerPos(List players, int i) {
    final p = players[i] as Map;
    return Offset((p['col'] as num).toDouble(), (p['row'] as num).toDouble());
  }

  Offset _focus() {
    final st = widget.state;
    final players = (st['players'] as List?) ?? const [];
    final pb = widget.playback;
    if (pb != null && players.length > pb.shooter) {
      final t = widget.playMs();
      for (int s = pb.stageCount - 1; s >= 0; s--) {
        final start = pb.stageStartMs[s];
        final flight = pb.stageFlightMs[s];
        if (flight <= 0 || t < start || t > start + flight) continue;
        TankShellTrack? track;
        for (final sh in pb.shells) {
          if (sh.stage != s) continue;
          if (track == null || sh.path.length > track.path.length) track = sh;
        }
        if (track == null) break;
        final k = (t - start) / flight;
        final head = (k * (track.path.length - 1)).round().clamp(
          0,
          track.path.length - 1,
        );
        final p = track.path[head];
        // 아주 높이 뜬 포탄은 끝까지 따라가지 않고 위쪽 화살표로 알려준다.
        return Offset(p.dx, math.max(p.dy, -14));
      }
      if (pb.stageCount == 0 || t < pb.stageStartMs.first) {
        return _playerPos(players, pb.shooter);
      }
      TankBoom? latest;
      double latestAt = -1;
      for (final b in pb.booms) {
        final at = pb.boomAt(b);
        if (at <= t && at >= latestAt) {
          latest = b;
          latestAt = at;
        }
      }
      if (latest != null) return Offset(latest.col, latest.row);
      return _playerPos(players, pb.shooter);
    }
    if (players.length < 2) return const Offset(50, 20);
    final a = _playerPos(players, 0);
    final b = _playerPos(players, 1);
    if (st['phase'] == 'aiming') {
      final turn = ((st['turn'] as num?)?.toInt() ?? 0).clamp(0, 1);
      final active = turn == 0 ? a : b;
      final other = turn == 0 ? b : a;
      final dir = other.dx >= active.dx ? 1.0 : -1.0;
      return Offset(active.dx + dir * 12, active.dy - 3);
    }
    return Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 2);
  }

  void _dragTo(Offset local, TankView view) {
    final players = (widget.state['players'] as List?) ?? const [];
    if (widget.myIndex >= players.length) return;
    final me = _playerPos(players, widget.myIndex);
    final turret = view.toScreen(me.dx, me.dy + 0.5 - 1.9);
    final d = local - turret;
    var angle = math.atan2(-d.dy, d.dx) * 180 / math.pi;
    if (angle < 0) angle = d.dx >= 0 ? 0.0 : 180.0;
    final reach = math.max(80.0, math.min(_size.width, _size.height) * 0.42);
    final power = (d.distance / reach * 100).clamp(1.0, 100.0);
    widget.onAim?.call(angle.roundToDouble(), power.roundToDouble());
    setState(() => _drag = local);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final view = _view ?? _targetView();
        final pb = widget.playback;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.canAim
              ? (d) => _dragTo(d.localPosition, view)
              : null,
          onPanUpdate: widget.canAim
              ? (d) => _dragTo(d.localPosition, view)
              : null,
          onTapUp: widget.onMinimapTap == null
              ? null
              : (d) {
                  final rect = TankBattlefieldPainter.minimapRect(
                    _size,
                    widget.insetTop,
                  );
                  if (rect.inflate(6).contains(d.localPosition)) {
                    widget.onMinimapTap!();
                  }
                },
          onPanEnd: (_) => setState(() => _drag = null),
          onPanCancel: () => setState(() => _drag = null),
          child: CustomPaint(
            size: _size,
            painter: TankBattlefieldPainter(
              TankScene(
                state: widget.state,
                myIndex: widget.myIndex,
                view: view,
                time: _time,
                playback: pb,
                playMs: pb == null ? 0 : widget.playMs(),
                myAngle: widget.myAngle,
                myPower: widget.myPower,
                aiming: widget.canAim,
                preview: widget.preview,
                lastTrace: widget.lastTrace,
                opponentAngle: widget.opponentAngle,
                scorches: widget.scorches,
                crateDrops: _crateDrops,
                myName: widget.myName,
                oppName: widget.oppName,
                dragPoint: widget.canAim ? _drag : null,
                insetTop: widget.insetTop,
                insetBottom: widget.insetBottom,
                showGuides: widget.showGuides,
              ),
            ),
          ),
        );
      },
    );
  }
}
