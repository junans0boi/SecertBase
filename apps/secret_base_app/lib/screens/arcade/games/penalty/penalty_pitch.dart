import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'penalty_athlete.dart';
import 'penalty_models.dart';

export 'penalty_athlete.dart' show PenaltyKit;

/// 중계 카메라 한 대의 원근 좌표계(키커 뒤쪽 높은 곳에서 골대를 보는 망원 샷).
/// 세계 좌표는 미터: x 옆(가운데 0), z 골라인에서 카메라 쪽 거리, y 높이.
/// 골대 칸·공 비행·키퍼 다이브·라인이 모두 같은 투영을 쓴다.
class PitchGeometry {
  static const camDist = 30.0;
  static const goalW = 7.32;
  static const goalH = 2.44;
  static const spotZ = 11.0;

  final Size size;
  final int cells;
  late final double cx;
  late final double f;
  late final double fh;
  late final double horizon;
  late final Rect goal;

  PitchGeometry(this.size, this.cells) {
    final w = size.width;
    final h = size.height;
    final gw = math.min(w * 0.80, h * 1.18);
    cx = w / 2;
    f = gw * camDist / goalW;
    final goalBottom = h * 0.51;
    final spotY = h * 0.75;
    fh = (spotY - goalBottom) / (1 / (camDist - spotZ) - 1 / camDist);
    horizon = goalBottom - fh / camDist;
    final gh = gw * goalH / goalW;
    goal = Rect.fromLTRB(cx - gw / 2, goalBottom - gh, cx + gw / 2, goalBottom);
  }

  /// 세계 좌표 → 화면.
  Offset project(double x, double z, [double y = 0]) {
    final d = math.max(0.6, camDist - z);
    return Offset(cx + f * x / d, horizon + (fh - f * y) / d);
  }

  /// z 거리에서 1미터가 몇 픽셀인지.
  double pxPerM(double z) => f / math.max(0.6, camDist - z);

  Offset get spot => project(0, spotZ);

  int get rows => cells == 6 ? 2 : 1;

  Rect zoneRect(int cell) {
    final col = penaltyCol(cell);
    final row = penaltyRow(cells, cell);
    final cw = goal.width / 3;
    final ch = goal.height / rows;
    return Rect.fromLTWH(goal.left + col * cw, goal.top + row * ch, cw, ch);
  }

  /// 공이 닿는 점: 3칸이면 골대 높이의 가운데보다 조금 위, 6칸이면 칸 중심.
  Offset target(int cell) {
    final r = zoneRect(cell);
    if (cells == 6) return r.center;
    return Offset(r.center.dx, goal.top + goal.height * 0.42);
  }

  /// [target]을 골라인 위 세계 좌표(x, y)로.
  (double, double) targetWorld(int cell) {
    final p = target(cell);
    final x = (p.dx - cx) * camDist / f;
    final y = (fh - (p.dy - horizon) * camDist) / f;
    return (x, y);
  }

  /// 키커가 서 있는 곳(세계 x, z)과 몸 크기 보정. 작은 화면에서는 골대를 덜 가리게 줄인다.
  static const kickerRest = Offset(-1.75, 13.8);
  static const kickerPlant = Offset(-0.5, 11.35);

  double get kickerScale {
    // 공 옆에 섰을 때 머리가 골문 아래쪽을 거의 가리지 않을 만큼.
    final feet = project(kickerPlant.dx, kickerPlant.dy).dy;
    final natural = 1.8 * pxPerM(kickerPlant.dy);
    final maxH = feet - (goal.bottom - goal.height * 0.04);
    return (maxH / natural).clamp(0.5, 1.0);
  }
}

/// 골대·관중석·잔디·선수를 그리고, 골대 위에 탭할 칸을 깐다.
/// [progress](0→1)가 돌면 [playback] 킥을 재생한다(도움닫기→킥→비행→다이브→반응).
class PenaltyPitch extends StatelessWidget {
  final GameTheme theme;
  final int cells;
  final PenaltyKit kicker;
  final PenaltyKit keeper;
  final PenaltyRound? playback;
  final Animation<double> progress;
  final Animation<double> idle;
  final int? selected;
  final bool zonesEnabled;
  final bool iAmKicker;

  /// 화면 폭보다 좁게 놓였을 때(데스크톱) 양옆을 배경에 녹인다.
  final bool fadeSides;
  final ValueChanged<int>? onZoneTap;
  final VoidCallback? onSkip;

  const PenaltyPitch({
    super.key,
    required this.theme,
    required this.cells,
    required this.kicker,
    required this.keeper,
    required this.progress,
    required this.idle,
    required this.iAmKicker,
    this.playback,
    this.selected,
    this.zonesEnabled = false,
    this.fadeSides = false,
    this.onZoneTap,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final g = PitchGeometry(size, cells);
        final playing = playback != null;
        Widget scene = RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: _PitchPainter(
              geometry: g,
              theme: theme,
              kicker: kicker,
              keeper: keeper,
              playback: playback,
              progress: progress,
              idle: idle,
              selected: playing ? null : selected,
              iAmKicker: iAmKicker,
            ),
          ),
        );
        // 위·아래(데스크톱이면 양옆도)를 배경으로 부드럽게 녹여 화면 전체가 한 경기장처럼.
        scene = ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0, 0.07, 0.94, 1],
          ).createShader(r),
          child: scene,
        );
        if (fadeSides) {
          scene = ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              colors: [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: [0, 0.08, 0.92, 1],
            ).createShader(r),
            child: scene,
          );
        }
        return Stack(
          key: const Key('penalty_pitch'),
          children: [
            Positioned.fill(child: scene),
            if (!playing)
              for (int c = 0; c < cells; c++)
                () {
                  // 누르는 영역은 골대 바깥쪽 가장자리로 조금 넓혀 작은 화면에서도 44px 이상.
                  final cell = g.zoneRect(c);
                  final col = penaltyCol(c);
                  final row = penaltyRow(cells, c);
                  const ext = 10.0;
                  final hit = Rect.fromLTRB(
                    cell.left - (col == 0 ? ext : 0),
                    cell.top - (row == 0 ? ext : 0),
                    cell.right + (col == 2 ? ext : 0),
                    cell.bottom + (row == g.rows - 1 ? ext : 0),
                  );
                  final visual = cell.deflate(2);
                  final t = g.target(c);
                  return Positioned.fromRect(
                    rect: hit,
                    child: _Zone(
                      key: Key('penalty_zone_$c'),
                      label: penaltyCellName(cells, c),
                      selected: selected == c,
                      enabled: zonesEnabled,
                      color: theme.accent,
                      iAmKicker: iAmKicker,
                      visual: visual.shift(-hit.topLeft),
                      aim: Offset(
                        (t.dx - visual.left) / visual.width,
                        (t.dy - visual.top) / visual.height,
                      ),
                      onTap: zonesEnabled ? () => onZoneTap?.call(c) : null,
                    ),
                  );
                }(),
            if (playing)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: '연출 건너뛰기',
                  child: GestureDetector(
                    key: const Key('penalty_skip'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onSkip,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 골대 위 칸 하나. 고르면 라임색 조준경이 뜬다.
class _Zone extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final Color color;
  final bool iAmKicker;

  /// 조준점(칸 안 상대 위치 0~1).
  final Offset aim;

  /// 누르는 영역 안에서 칸이 그려지는 자리.
  final Rect visual;
  final VoidCallback? onTap;

  const _Zone({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.iAmKicker,
    required this.aim,
    required this.visual,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$label 칸',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [Positioned.fromRect(rect: visual, child: _cell())],
        ),
      ),
    );
  }

  Widget _cell() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: selected
            ? color.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: enabled ? 0.035 : 0),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: enabled ? 0.2 : 0),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween(begin: 1.6, end: 1.0).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: selected
            ? CustomPaint(
                key: const ValueKey('reticle'),
                size: Size.infinite,
                painter: _ReticlePainter(
                  color: color,
                  aim: aim,
                  keeper: !iAmKicker,
                ),
              )
            : const SizedBox.expand(key: ValueKey('empty')),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  final Offset aim;
  final bool keeper;

  _ReticlePainter({
    required this.color,
    required this.aim,
    required this.keeper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    // 모서리 괄호.
    final l = math.min(size.width, size.height) * 0.2;
    const i = 5.0;
    for (final c in [
      (Offset(i, i), 1.0, 1.0),
      (Offset(size.width - i, i), -1.0, 1.0),
      (Offset(i, size.height - i), 1.0, -1.0),
      (Offset(size.width - i, size.height - i), -1.0, -1.0),
    ]) {
      final p = c.$1;
      canvas.drawLine(p, p + Offset(l * c.$2, 0), line);
      canvas.drawLine(p, p + Offset(0, l * c.$3), line);
    }
    final center = Offset(aim.dx * size.width, aim.dy * size.height);
    final r = math.min(size.width, size.height) * 0.24;
    canvas.drawCircle(
      center,
      r * 1.8,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.8)),
    );
    canvas.drawCircle(center, r, line);
    if (keeper) {
      // 장갑 모양(손바닥 + 손가락 넷).
      final glove = Paint()..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center + Offset(0, r * 0.18),
            width: r * 0.9,
            height: r * 0.72,
          ),
          Radius.circular(r * 0.24),
        ),
        glove,
      );
      for (int k = 0; k < 4; k++) {
        final x = center.dx - r * 0.34 + k * r * 0.227;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x - r * 0.09,
              center.dy - r * 0.55,
              r * 0.18,
              r * 0.6,
            ),
            Radius.circular(r * 0.09),
          ),
          glove,
        );
      }
    } else {
      final tick = r * 0.45;
      canvas.drawLine(
        center + Offset(0, -r - tick * 0.4),
        center + Offset(0, -r + tick),
        line,
      );
      canvas.drawLine(
        center + Offset(0, r + tick * 0.4),
        center + Offset(0, r - tick),
        line,
      );
      canvas.drawLine(
        center + Offset(-r - tick * 0.4, 0),
        center + Offset(-r + tick, 0),
        line,
      );
      canvas.drawLine(
        center + Offset(r + tick * 0.4, 0),
        center + Offset(r - tick, 0),
        line,
      );
      canvas.drawCircle(center, 2.6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) =>
      old.color != color || old.aim != aim || old.keeper != keeper;
}

// 연출 구간(0~1, 전체 2초).
const _runEnd = 0.24;
const _kickAt = 0.26;
const _flightEnd = 0.71; // 0.26→0.71 = 0.9초 비행
const _diveStart = 0.30;
const _diveEnd = 0.6;
const _landEnd = 0.84;

/// 공이 골대에 닿는 순간(소리·반응 타이밍을 화면과 맞춘다).
const kPenaltyImpactAt = _flightEnd;
const kPenaltyKickAt = _kickAt;

class _PitchPainter extends CustomPainter {
  final PitchGeometry geometry;
  final GameTheme theme;
  final PenaltyKit kicker;
  final PenaltyKit keeper;
  final PenaltyRound? playback;
  final Animation<double> progress;
  final Animation<double> idle;
  final int? selected;
  final bool iAmKicker;

  _PitchPainter({
    required this.geometry,
    required this.theme,
    required this.kicker,
    required this.keeper,
    required this.playback,
    required this.progress,
    required this.idle,
    required this.selected,
    required this.iAmKicker,
  }) : super(repaint: Listenable.merge([progress, idle]));

  static const _ballR = 0.16;
  static const _netEx = 2.2;
  static const _boardsZ = -7.5;

  static final Map<String, ui.Picture> _pictures = {};

  double get t => playback == null ? 0 : progress.value;

  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  PitchGeometry get g => geometry;

  // ── 캐시된 정적 레이어 ──────────────────────────────────────────────────

  ui.Picture _picture(String layer, void Function(Canvas) draw) {
    final key =
        '$layer|${g.size.width.toStringAsFixed(1)}x${g.size.height.toStringAsFixed(1)}|${theme.id}';
    final hit = _pictures[key];
    if (hit != null) return hit;
    // 창 크기가 여러 번 바뀌면 오래된 것을 버린다(이번 프레임에 이미 그린 것일 수 있어 dispose는 GC에 맡긴다).
    if (_pictures.length > 18) _pictures.clear();
    final rec = ui.PictureRecorder();
    draw(Canvas(rec));
    return _pictures[key] = rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pb = playback;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 카메라: 비행 중에는 골대 쪽으로 살짝 당기고, 맞는 순간 흔들린다.
    var push = 0.0;
    var shake = Offset.zero;
    if (pb != null) {
      push =
          Curves.easeInOut.transform(_seg(_kickAt, _flightEnd)) *
          (1 - Curves.easeInOut.transform(_seg(0.88, 1.0)));
      final k = _seg(_flightEnd, _flightEnd + 0.15);
      if (k > 0 && k < 1) {
        final amp = (pb.isGoal ? 5.5 : 3.5) * (1 - k);
        shake = Offset(math.sin(k * 52) * amp, math.cos(k * 41) * amp * 0.6);
      }
    }
    final focus = Offset(g.cx, g.goal.center.dy);
    canvas.translate(focus.dx + shake.dx, focus.dy + shake.dy);
    canvas.scale(1 + 0.08 * push);
    canvas.translate(-focus.dx, -focus.dy);

    canvas.drawPicture(_picture('bg', _background));
    _crowdLife(canvas, size);

    final keeperState = _keeperState();
    final kickerState = _kickerState();
    final ball = _ballState();

    _shadows(canvas, keeperState.ground, keeperState.height, keeperState.lift);
    _shadows(canvas, kickerState.ground, kickerState.height, 0);
    _ballShadow(canvas, ball);

    // 그물(골이면 출렁임).
    final ripple = pb != null && pb.isGoal ? _seg(_flightEnd + 0.02, 1.0) : 0.0;
    if (ripple > 0 && ripple < 1) {
      _net(canvas, ripple: ripple, impact: ball.netImpact);
    } else {
      canvas.drawPicture(_picture('net', (c) => _net(c)));
    }
    if (ball.behindLine) _ball(canvas, ball);
    canvas.drawPicture(_picture('posts', _posts));

    _athlete(canvas, keeperState, keeper, front: true, isKeeper: true);
    if (selected != null && !iAmKicker) _keeperAim(canvas, keeperState);

    if (!ball.behindLine) {
      if (ball.trail != null) _trail(canvas, ball);
      _ball(canvas, ball);
    }
    if (selected != null && iAmKicker) _kickerAim(canvas, ball.center);
    _athlete(canvas, kickerState, kicker, front: false, isKeeper: false);

    if (pb != null && !pb.isGoal) _parry(canvas, pb);
    canvas.restore();
  }

  // ── 배경 ────────────────────────────────────────────────────────────────

  void _background(Canvas canvas) {
    final w = g.size.width;
    final h = g.size.height;
    final boardsTop = g.project(0, _boardsZ, 1.0).dy;
    final boardsBottom = g.project(0, _boardsZ).dy;

    // 밤하늘.
    final sky = Rect.fromLTWH(0, 0, w, boardsTop + 2);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF030713), Color(0xFF0A1633)],
        ).createShader(sky),
    );

    // 관중석: 계단식 층 + 통로 + 관중 불빛. 왼쪽은 내 팀, 오른쪽은 상대 팀 응원석.
    final roof = math.max(6.0, h * 0.05);
    final standTop = roof;
    final standBottom = boardsTop;
    final tiers = math.max(6, ((standBottom - standTop) / 9).round());
    for (int i = 0; i < tiers; i++) {
      final y0 = standTop + (standBottom - standTop) * i / tiers;
      final y1 = standTop + (standBottom - standTop) * (i + 1) / tiers;
      final k = i / tiers;
      canvas.drawRect(
        Rect.fromLTRB(0, y0, w, y1),
        Paint()
          ..color = Color.lerp(
            i.isEven ? const Color(0xFF0B1430) : const Color(0xFF09112A),
            i.isEven ? const Color(0xFF142046) : const Color(0xFF111B3D),
            k,
          )!,
      );
    }
    // 통로(아래로 갈수록 살짝 벌어진다).
    final aisle = Paint()
      ..strokeWidth = 1.2
      ..color = const Color(0x22A9BEE8);
    for (int i = -3; i <= 3; i++) {
      final xTop = g.cx + i * w * 0.2;
      final xBottom = g.cx + i * w * 0.23;
      canvas.drawLine(
        Offset(xTop, standTop),
        Offset(xBottom, standBottom),
        aisle,
      );
    }
    final rnd = math.Random(41);
    final rows = math.max(8, ((standBottom - standTop) / 4.2).round());
    for (int row = 0; row < rows; row++) {
      final k = row / rows;
      final y = standTop + 3 + (standBottom - standTop - 6) * k;
      final step = 3.6 + k * 2.4;
      final r = 0.7 + k * 0.7;
      for (double x = rnd.nextDouble() * step; x < w; x += step) {
        final v = rnd.nextDouble();
        if (v < 0.12) continue;
        final side = x / w;
        final Color c;
        if (v > 0.985) {
          c = const Color(0xEEFFFFFF);
        } else if (side < 0.32 && v > 0.45) {
          c = theme.me.withValues(alpha: 0.35 + 0.35 * k);
        } else if (side > 0.68 && v > 0.45) {
          c = theme.opponent.withValues(alpha: 0.35 + 0.35 * k);
        } else {
          c = Color.lerp(
            const Color(0xFF2A3658),
            const Color(0xFF6B7899),
            rnd.nextDouble() * (0.4 + k * 0.6),
          )!.withValues(alpha: 0.75);
        }
        canvas.drawCircle(
          Offset(x + rnd.nextDouble() * 1.2, y + rnd.nextDouble() * 1.6),
          r,
          Paint()..color = c,
        );
      }
    }
    // 지붕 처마 + 처마 밑 조명 점.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, roof),
      Paint()..color = const Color(0xFF02050C),
    );
    canvas.drawLine(
      Offset(0, roof),
      Offset(w, roof),
      Paint()
        ..strokeWidth = 1.2
        ..color = const Color(0x55A9C4FF),
    );
    for (double x = 8; x < w; x += 22) {
      canvas.drawCircle(
        Offset(x, roof - 1.5),
        0.9,
        Paint()..color = const Color(0xAAE6F0FF),
      );
    }

    // LED 광고판(글자 없이 추상 무늬).
    final boards = Rect.fromLTRB(0, boardsTop, w, boardsBottom);
    canvas.drawRect(boards, Paint()..color = const Color(0xFF07101F));
    final segW = math.max(60.0, w * 0.21);
    int idx = 0;
    for (double x = -segW * 0.35; x < w; x += segW, idx++) {
      final seg = Rect.fromLTWH(
        x + 1,
        boards.top + 1,
        segW - 2,
        boards.height - 2,
      );
      canvas.save();
      canvas.clipRect(seg);
      switch (idx % 3) {
        case 0:
          canvas.drawRect(seg, Paint()..color = const Color(0xFF0C1A3A));
          final chev = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, seg.height * 0.14)
            ..color = theme.accent;
          for (
            double cxv = seg.left + seg.height * 0.6;
            cxv < seg.right;
            cxv += seg.height * 0.75
          ) {
            canvas.drawPath(
              Path()
                ..moveTo(cxv, seg.top + seg.height * 0.22)
                ..lineTo(cxv + seg.height * 0.3, seg.center.dy)
                ..lineTo(cxv, seg.bottom - seg.height * 0.22),
              chev,
            );
          }
        case 1:
          canvas.drawRect(
            seg,
            Paint()
              ..shader = LinearGradient(
                colors: [theme.accent, const Color(0xFF39D6C6)],
              ).createShader(seg),
          );
          final stripe = Paint()..color = const Color(0x33061020);
          for (
            double sx = seg.left - seg.height;
            sx < seg.right;
            sx += seg.height * 0.5
          ) {
            canvas.drawPath(
              Path()
                ..moveTo(sx, seg.bottom)
                ..lineTo(sx + seg.height * 0.25, seg.bottom)
                ..lineTo(sx + seg.height * 0.75, seg.top)
                ..lineTo(sx + seg.height * 0.5, seg.top)
                ..close(),
              stripe,
            );
          }
        default:
          canvas.drawRect(seg, Paint()..color = const Color(0xFF0A1428));
          final line = Paint()..color = const Color(0xD9FFFFFF);
          final lh = math.max(1.2, seg.height * 0.13);
          canvas.drawRect(
            Rect.fromLTWH(
              seg.left + seg.width * 0.12,
              seg.center.dy - lh * 1.6,
              seg.width * 0.5,
              lh,
            ),
            line,
          );
          canvas.drawRect(
            Rect.fromLTWH(
              seg.left + seg.width * 0.12,
              seg.center.dy + lh * 0.6,
              seg.width * 0.32,
              lh,
            ),
            line..color = const Color(0x99FFFFFF),
          );
          final ring = Offset(seg.left + seg.width * 0.8, seg.center.dy);
          canvas.drawCircle(
            ring,
            seg.height * 0.26,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, seg.height * 0.08)
              ..color = theme.accent,
          );
      }
      canvas.restore();
    }
    canvas.drawRect(boards, Paint()..color = const Color(0x4D050B18));
    canvas.drawLine(
      Offset(0, boards.top),
      Offset(w, boards.top),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x40FFFFFF),
    );

    // 잔디: 골라인과 나란한 깎은 줄무늬(원근).
    final grass = Rect.fromLTRB(0, boardsBottom, w, h);
    canvas.drawRect(grass, Paint()..color = const Color(0xFF1E7337));
    const stripeM = 2.6;
    int band = 0;
    for (
      double z = _boardsZ;
      z < PitchGeometry.camDist - 1;
      z += stripeM, band++
    ) {
      final y0 = g.project(0, z).dy;
      final y1 = math.min(h, g.project(0, z + stripeM).dy);
      if (y0 > h) break;
      if (band.isOdd) {
        canvas.drawRect(
          Rect.fromLTRB(0, y0, w, y1),
          Paint()..color = const Color(0xFF247F3E),
        );
      }
    }
    // 잔디 결.
    final grain = math.Random(7);
    final grainPaint = Paint();
    final count = (w * (h - boardsBottom) / 70).round();
    for (int i = 0; i < count; i++) {
      final y = boardsBottom + grain.nextDouble() * (h - boardsBottom);
      grainPaint.color = grain.nextBool()
          ? const Color(0x10FFFFFF)
          : const Color(0x12000000);
      canvas.drawRect(
        Rect.fromLTWH(grain.nextDouble() * w, y, 1, 1 + (y / h) * 1.5),
        grainPaint,
      );
    }
    // 조명이 모이는 골문 앞은 밝게, 가장자리는 어둡게.
    canvas.drawRect(
      grass,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            0,
            (g.goal.bottom - grass.center.dy) / (grass.height / 2) * 0.6,
          ),
          radius: 0.95,
          colors: const [
            Color(0x2EE8FFE8),
            Color(0x00E8FFE8),
            Color(0x66000814),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(grass),
    );
    // 광고판 불빛이 잔디에 번진다.
    final glow = Rect.fromLTRB(
      0,
      boardsBottom,
      w,
      boardsBottom + (g.goal.bottom - boardsBottom) * 2.2,
    );
    canvas.drawRect(
      glow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.accent.withValues(alpha: 0.10),
            theme.accent.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );

    _lines(canvas);
    _goalShadow(canvas);
    _floodlights(canvas);
  }

  void _lines(Canvas canvas) {
    final w = g.size.width;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xE6F4F8FF);
    void seg(double x0, double z0, double x1, double z1) {
      final zm = (z0 + z1) / 2;
      paint.strokeWidth = (0.12 * g.pxPerM(zm) * 0.55).clamp(1.2, 3.2);
      canvas.drawLine(g.project(x0, z0), g.project(x1, z1), paint);
    }

    // 골라인(화면 끝까지).
    final half = (w / 2 + 40) * PitchGeometry.camDist / g.f;
    seg(-half, 0, half, 0);
    // 골 에어리어(5.5m).
    seg(-9.16, 0, -9.16, 5.5);
    seg(9.16, 0, 9.16, 5.5);
    seg(-9.16, 5.5, 9.16, 5.5);
    // 페널티 박스(16.5m).
    seg(-20.16, 0, -20.16, 16.5);
    seg(20.16, 0, 20.16, 16.5);
    final nearHalf = (w / 2 + 40) * (PitchGeometry.camDist - 16.5) / g.f;
    seg(-nearHalf, 16.5, nearHalf, 16.5);
    // 페널티 스폿.
    final s = g.spot;
    final r = 0.16 * g.pxPerM(PitchGeometry.spotZ);
    canvas.drawOval(
      Rect.fromCenter(center: s, width: r * 2, height: r * 0.8),
      Paint()..color = const Color(0xF2FFFFFF),
    );
  }

  void _goalShadow(Canvas canvas) {
    // 뒤쪽 조명탑이 골대 그림자를 카메라 쪽으로 드리운다.
    const hw = PitchGeometry.goalW / 2;
    final shade = Paint()
      ..color = const Color(0x38000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final postW = math.max(2.0, 0.12 * g.pxPerM(0));
    for (final x in [-hw, hw]) {
      final a = g.project(x, 0);
      final b = g.project(x * 1.12, 2.6);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0x40000000)
          ..strokeWidth = postW
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
    final bar = Path()
      ..moveTo(g.project(-hw, 0).dx, g.project(-hw, 0).dy)
      ..lineTo(g.project(hw, 0).dx, g.project(hw, 0).dy)
      ..lineTo(g.project(hw * 1.12, 2.6).dx, g.project(hw * 1.12, 2.6).dy)
      ..lineTo(g.project(-hw * 1.12, 2.6).dx, g.project(-hw * 1.12, 2.6).dy)
      ..close();
    canvas.drawPath(bar, Paint()..color = const Color(0x16000000));
    canvas.drawLine(
      g.project(-hw * 1.12, 2.6),
      g.project(hw * 1.12, 2.6),
      shade..strokeWidth = postW * 0.8,
    );
  }

  void _floodlights(Canvas canvas) {
    final w = g.size.width;
    final h = g.size.height;
    final y = math.max(14.0, h * 0.075);
    for (final left in [true, false]) {
      final c = Offset(left ? w * 0.1 : w * 0.9, y);
      // 빛줄기.
      final beam = Path()
        ..moveTo(c.dx - 8, c.dy)
        ..lineTo(c.dx + 8, c.dy)
        ..lineTo(left ? g.cx + w * 0.18 : g.cx + w * 0.02, g.goal.bottom)
        ..lineTo(left ? g.cx - w * 0.02 : g.cx - w * 0.18, g.goal.bottom)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0x1CDDE9FF), Color(0x00DDE9FF)],
          ).createShader(Rect.fromLTRB(0, c.dy, w, g.goal.bottom)),
      );
      // 빛 번짐.
      _glow(canvas, c, w * 0.42, const Color(0x40B8D2FF));
      _glow(canvas, c, w * 0.12, const Color(0x99EAF2FF));
      // 조명 판넬(전구 격자).
      final bw = math.max(26.0, w * 0.1);
      final bh = bw * 0.42;
      final panel = Rect.fromCenter(center: c, width: bw, height: bh);
      canvas.drawRRect(
        RRect.fromRectAndRadius(panel.inflate(1.5), const Radius.circular(2)),
        Paint()..color = const Color(0xFF1A2236),
      );
      for (int r = 0; r < 2; r++) {
        for (int k = 0; k < 5; k++) {
          final cell = Offset(
            panel.left + panel.width * (k + 0.5) / 5,
            panel.top + panel.height * (r + 0.5) / 2,
          );
          canvas.drawCircle(
            cell,
            bh * 0.2,
            Paint()..color = const Color(0xFFF7FBFF),
          );
        }
      }
      // 가로 렌즈 플레어.
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, 0.03);
      _glow(canvas, Offset.zero, w * 0.6, const Color(0x66DCE8FF));
      canvas.restore();
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  /// 관중석의 반짝임(휴대폰 플래시)과 골 순간의 카메라 플래시.
  void _crowdLife(Canvas canvas, Size size) {
    final boardsTop = g.project(0, _boardsZ, 1.0).dy;
    final top = math.max(6.0, size.height * 0.05);
    final rnd = math.Random(77);
    final phase = idle.value;
    final paint = Paint();
    for (int i = 0; i < 26; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = top + rnd.nextDouble() * (boardsTop - top);
      final speed = 1 + rnd.nextInt(2);
      final v = math.sin((phase * speed + rnd.nextDouble()) * math.pi * 2);
      final a = math.pow(math.max(0.0, v), 10).toDouble();
      if (a < 0.02) continue;
      paint.color = Colors.white.withValues(alpha: a * 0.9);
      canvas.drawCircle(Offset(x, y), 1.1, paint);
    }
    final pb = playback;
    if (pb == null) return;
    final react = _seg(_flightEnd, 1.0);
    if (react <= 0) return;
    final strength = pb.isGoal ? 1.0 : 0.35;
    // 득점한 쪽 응원석이 들썩인다(색 번짐).
    final color = kicker.color;
    final wash = Rect.fromLTRB(0, top, size.width, boardsTop);
    canvas.drawRect(
      wash,
      Paint()
        ..color = (pb.isGoal ? color : Colors.white).withValues(
          alpha: 0.13 * strength * math.sin(react * math.pi),
        ),
    );
    final fr = math.Random(pb.round * 13 + pb.kickerDir);
    final n = pb.isGoal ? 46 : 14;
    for (int i = 0; i < n; i++) {
      final at = fr.nextDouble() * 0.8;
      final x = fr.nextDouble() * size.width;
      final y = top + fr.nextDouble() * (boardsTop - top);
      final d = react - at;
      if (d < 0) continue;
      final a = math.exp(-d * 26);
      if (a < 0.03) continue;
      _glow(canvas, Offset(x, y), 5 + a * 4, Colors.white.withValues(alpha: a));
    }
  }

  // ── 골대 ────────────────────────────────────────────────────────────────

  /// 그물 꼭짓점(깊이를 살짝 과장해 입체감을 준다).
  ({
    Offset fl0,
    Offset fl1,
    Offset fr0,
    Offset fr1,
    Offset bl0,
    Offset bl1,
    Offset br0,
    Offset br1,
  })
  _frame() {
    const hw = PitchGeometry.goalW / 2;
    const gh = PitchGeometry.goalH;
    return (
      fl0: g.project(-hw, 0),
      fl1: g.project(-hw, 0, gh),
      fr0: g.project(hw, 0),
      fr1: g.project(hw, 0, gh),
      bl0: g.project(-hw, -2.0 * _netEx),
      bl1: g.project(-hw, -1.0 * _netEx, gh * 0.94),
      br0: g.project(hw, -2.0 * _netEx),
      br1: g.project(hw, -1.0 * _netEx, gh * 0.94),
    );
  }

  void _net(Canvas canvas, {double ripple = 0, Offset? impact}) {
    final fr = _frame();
    final vp = Offset(g.cx, g.horizon);
    Offset bend(Offset p) {
      if (ripple <= 0 || impact == null) return p;
      final d = (p - impact).distance;
      final fall = math.exp(-d / (g.goal.width * 0.16));
      final env =
          math.sin(math.min(1.0, ripple * 3) * math.pi / 2) * (1 - ripple);
      final wave = math.sin(ripple * math.pi * 5 - d * 0.09);
      final dir = d == 0 ? Offset.zero : (p - impact) / d;
      final back = vp - p;
      final bl = back.distance == 0 ? Offset.zero : back / back.distance;
      return p + dir * (5 * fall * wave * env) + bl * (10 * fall * env);
    }

    Offset bilerp(Offset a, Offset b, Offset c, Offset d, double u, double v) {
      // a(위왼) b(위오) c(아래오) d(아래왼)
      final top = Offset.lerp(a, b, u)!;
      final bottom = Offset.lerp(d, c, u)!;
      return Offset.lerp(top, bottom, v)!;
    }

    void panel(
      Offset a,
      Offset b,
      Offset c,
      Offset d,
      int nu,
      int nv,
      double alpha,
      Color fill,
    ) {
      final outline = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
      canvas.drawPath(outline, Paint()..color = fill);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.white.withValues(alpha: alpha);
      for (int i = 0; i <= nu; i++) {
        final path = Path();
        for (int k = 0; k <= nv; k++) {
          final q = bend(bilerp(a, b, c, d, i / nu, k / nv));
          k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(path, p);
      }
      for (int k = 0; k <= nv; k++) {
        final path = Path();
        for (int i = 0; i <= nu; i++) {
          final q = bend(bilerp(a, b, c, d, i / nu, k / nv));
          i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(path, p);
      }
    }

    final dense = g.goal.width > 220;
    final nu = dense ? 26 : 18;
    final nv = dense ? 11 : 8;
    // 뒤 그물, 옆 그물, 지붕 그물.
    panel(
      fr.bl1,
      fr.br1,
      fr.br0,
      fr.bl0,
      nu,
      nv,
      0.26,
      const Color(0x2A04101C),
    );
    panel(fr.fl1, fr.bl1, fr.bl0, fr.fl0, 7, nv, 0.32, const Color(0x1404101C));
    panel(fr.br1, fr.fr1, fr.fr0, fr.br0, 7, nv, 0.32, const Color(0x1404101C));
    panel(fr.fl1, fr.fr1, fr.br1, fr.bl1, nu, 3, 0.4, const Color(0x10FFFFFF));
    // 뒤쪽 받침대.
    final support = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, g.pxPerM(-2) * 0.05)
      ..color = const Color(0x99C9D3E3);
    canvas.drawLine(fr.bl1, fr.bl0, support);
    canvas.drawLine(fr.br1, fr.br0, support);
    canvas.drawLine(fr.bl0, fr.br0, support);
    canvas.drawLine(fr.fl1, fr.bl1, support);
    canvas.drawLine(fr.fr1, fr.br1, support);
  }

  void _posts(Canvas canvas) {
    final fr = _frame();
    final pw = math.max(3.0, 0.13 * g.pxPerM(0));
    final shade = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    // 아래 그림자 한 겹(입체감).
    canvas.drawRect(
      Rect.fromLTRB(
        fr.fl1.dx - pw / 2 + 1.5,
        fr.fl1.dy - pw / 2 + 2,
        fr.fr1.dx + pw / 2 + 1.5,
        fr.fl1.dy + pw / 2 + 2,
      ),
      shade,
    );
    for (final p in [fr.fl0, fr.fr0]) {
      final r = Rect.fromLTRB(
        p.dx - pw / 2,
        fr.fl1.dy - pw / 2,
        p.dx + pw / 2,
        p.dy,
      );
      canvas.drawRect(r.shift(const Offset(1.5, 0)), shade);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          r,
          topLeft: Radius.circular(pw / 2),
          topRight: Radius.circular(pw / 2),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF2F5FA), Color(0xFFB4BFCF)],
            stops: [0, 0.45, 1],
          ).createShader(r),
      );
    }
    final bar = Rect.fromLTRB(
      fr.fl1.dx - pw / 2,
      fr.fl1.dy - pw / 2,
      fr.fr1.dx + pw / 2,
      fr.fl1.dy + pw / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(pw / 2)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF2F5FA), Color(0xFFB4BFCF)],
          stops: [0, 0.45, 1],
        ).createShader(bar),
    );
    // 골대 밑동이 잔디에 닿는 곳.
    for (final p in [fr.fl0, fr.fr0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: p + const Offset(0, 1),
          width: pw * 2.2,
          height: pw * 0.7,
        ),
        Paint()..color = const Color(0x44000000),
      );
    }
  }

  // ── 선수 ────────────────────────────────────────────────────────────────

  _Figure _keeperState() {
    final home = g.project(0, 0.5);
    final hpx = 1.88 * g.pxPerM(0.5);
    final pb = playback;
    final phase = idle.value * math.pi * 2;
    if (pb == null) {
      // 좌우로 잔걸음.
      final sway = math.sin(phase) * hpx * 0.07;
      final bob = math.sin(phase * 2).abs() * hpx * 0.012;
      return _Figure(
        pose: KeeperPoses.ready,
        pelvis: home + Offset(sway, -hpx * 0.46 - bob),
        pelvisLocal: KeeperPoses.ready[AthletePose.pelvis],
        height: hpx,
        ground: home + Offset(sway, 0),
      );
    }
    final load = Curves.easeOut.transform(_seg(0, _diveStart));
    final d = Curves.easeOutCubic.transform(_seg(_diveStart, _diveEnd));
    final land = Curves.easeInOut.transform(_seg(_diveEnd, _landEnd));
    final (tx, ty) = g.targetWorld(pb.keeperDir);
    final target = g.project(tx, 0.5, ty);
    final col = penaltyCol(pb.keeperDir);
    final side = (col - 1).toDouble();
    final pelvisHome = home + Offset(0, -hpx * 0.42);
    final readyPose = KeeperPoses.ready.lerp(KeeperPoses.set, load);
    if (side == 0) {
      final low = g.cells == 6 && penaltyRow(g.cells, pb.keeperDir) == 1;
      final high = g.cells == 6 && !low;
      final endPose = low
          ? KeeperPoses.blockLow
          : high
          ? KeeperPoses.jump
          : KeeperPoses.catchBall;
      final handsLocal = Offset.lerp(
        endPose[AthletePose.haL],
        endPose[AthletePose.haR],
        0.5,
      )!;
      final reach = (endPose[AthletePose.pelvis] - handsLocal).dy * hpx;
      var endPelvis = Offset(target.dx, target.dy + reach);
      if (!high) {
        endPelvis = Offset(
          target.dx,
          math.max(
            endPelvis.dy,
            home.dy + endPose[AthletePose.pelvis].dy * hpx,
          ),
        );
      }
      final back = high ? land : 0.0;
      final pelvis = Offset.lerp(
        Offset.lerp(pelvisHome, endPelvis, d)!,
        pelvisHome,
        back,
      )!;
      final lift = math.max(
        0.0,
        home.dy + endPose[AthletePose.pelvis].dy * hpx - pelvis.dy,
      );
      return _Figure(
        pose: readyPose.lerp(endPose, d).lerp(KeeperPoses.ready, back * 0.6),
        pelvis: pelvis,
        pelvisLocal: Offset.lerp(
          readyPose[AthletePose.pelvis],
          endPose[AthletePose.pelvis],
          d,
        )!,
        height: hpx,
        ground: Offset(pelvis.dx, home.dy),
        lift: lift,
      );
    }
    // 옆 다이브: 몸을 쭉 펴고 기울여 장갑이 칸 중심에 닿는다.
    final row = g.cells == 6 ? penaltyRow(g.cells, pb.keeperDir) : -1;
    final theta =
        side *
        (row == 0
            ? 1.0
            : row == 1
            ? 1.48
            : 1.22);
    final stretch = side > 0
        ? KeeperPoses.stretch
        : KeeperPoses.stretch.mirrored();
    final lying = side > 0 ? KeeperPoses.lying : KeeperPoses.lying.mirrored();
    final handsLocal = Offset.lerp(
      stretch[AthletePose.haL],
      stretch[AthletePose.haR],
      0.5,
    )!;
    final arm = (handsLocal - stretch[AthletePose.pelvis]) * hpx;
    Offset rot(Offset v, double a) => Offset(
      v.dx * math.cos(a) - v.dy * math.sin(a),
      v.dx * math.sin(a) + v.dy * math.cos(a),
    );
    final endPelvis = target - rot(arm, theta);
    final hop = -math.sin(d * math.pi) * hpx * (row == 1 ? 0.05 : 0.14);
    var pelvis = Offset.lerp(pelvisHome, endPelvis, d)! + Offset(0, hop);
    var angle = theta * d;
    var pose = readyPose.lerp(stretch, d);
    if (land > 0) {
      final lieAngle = side * (math.pi / 2 + 0.08);
      final lieAt = Offset(
        endPelvis.dx + side * hpx * 0.08,
        home.dy - hpx * 0.1,
      );
      pelvis = Offset.lerp(pelvis, lieAt, land)!;
      angle = angle + (lieAngle - angle) * land;
      pose = pose.lerp(lying, land);
    }
    return _Figure(
      pose: pose,
      pelvis: pelvis,
      pelvisLocal: pose[AthletePose.pelvis],
      height: hpx,
      angle: angle,
      ground: Offset(pelvis.dx, home.dy),
      lift: math.max(0.0, home.dy - hpx * 0.1 - pelvis.dy),
    );
  }

  _Figure _kickerState() {
    final scale = g.kickerScale;
    final pb = playback;
    final phase = idle.value * math.pi * 2;
    Offset at(Offset world) => g.project(world.dx, world.dy);
    double heightAt(double z) => 1.8 * g.pxPerM(z) * scale;
    if (pb == null) {
      final ground = at(PitchGeometry.kickerRest);
      final hpx = heightAt(PitchGeometry.kickerRest.dy);
      final breathe = math.sin(phase) * hpx * 0.006;
      return _Figure(
        pose: KickerPoses.ready,
        pelvis: ground + Offset(0, -hpx * 0.5 + breathe),
        pelvisLocal: KickerPoses.ready[AthletePose.pelvis],
        height: hpx,
        ground: ground,
      );
    }
    final run = _seg(0, _runEnd);
    final world = Offset.lerp(
      PitchGeometry.kickerRest,
      PitchGeometry.kickerPlant,
      Curves.easeIn.transform(run),
    )!;
    final ground = at(world);
    final hpx = heightAt(world.dy);
    AthletePose pose;
    var bounce = 0.0;
    if (t < _runEnd - 0.04) {
      final cycle = run * 3.2;
      final k = (math.sin(cycle * math.pi * 2) + 1) / 2;
      pose = KickerPoses.run1.lerp(KickerPoses.run2, k);
      bounce = math.sin(cycle * math.pi * 4).abs() * 0.025;
    } else if (t < _kickAt) {
      pose = KickerPoses.run2.lerp(
        KickerPoses.plant,
        _seg(_runEnd - 0.04, _kickAt - 0.005),
      );
    } else if (t < _kickAt + 0.1) {
      final k = _seg(_kickAt - 0.005, _kickAt + 0.1);
      pose = k < 0.25
          ? KickerPoses.plant.lerp(KickerPoses.strike, k / 0.25)
          : KickerPoses.strike.lerp(KickerPoses.follow, (k - 0.25) / 0.75);
    } else if (t < _flightEnd) {
      pose = KickerPoses.follow.lerp(
        KickerPoses.ready,
        Curves.easeOut.transform(_seg(_kickAt + 0.1, _flightEnd)),
      );
    } else {
      final end = pb.isGoal ? KickerPoses.celebrate : KickerPoses.despair;
      final k = Curves.easeOut.transform(_seg(_flightEnd, _flightEnd + 0.08));
      pose = KickerPoses.ready.lerp(end, k);
      if (pb.isGoal) {
        bounce = math.sin(_seg(_flightEnd, 1) * math.pi * 3).abs() * 0.05 * k;
      }
    }
    return _Figure(
      pose: pose,
      pelvis: ground + Offset(0, (pose[AthletePose.pelvis].dy - bounce) * hpx),
      pelvisLocal: pose[AthletePose.pelvis],
      height: hpx,
      ground: ground,
      lift: bounce * hpx,
    );
  }

  void _athlete(
    Canvas canvas,
    _Figure f,
    PenaltyKit kit, {
    required bool front,
    required bool isKeeper,
  }) {
    canvas.save();
    canvas.translate(f.pelvis.dx, f.pelvis.dy);
    canvas.rotate(f.angle);
    canvas.scale(f.height);
    canvas.translate(-f.pelvisLocal.dx, -f.pelvisLocal.dy);
    AthletePainter.paint(
      canvas,
      f.pose,
      kit,
      front: front,
      keeper: isKeeper,
      numberStyle: theme.display(size: 100),
    );
    canvas.restore();
  }

  /// 발밑 접지 그림자 + 조명탑 네 개가 만드는 X자 그림자.
  void _shadows(Canvas canvas, Offset ground, double hpx, double lift) {
    final fade = (1 - lift / (hpx * 0.8)).clamp(0.25, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: ground,
        width: hpx * 0.42 * (0.7 + 0.3 * fade),
        height: hpx * 0.07,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42 * fade)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1, hpx * 0.012),
        ),
    );
    for (final a in [-0.75, 0.75, -2.3, 2.3]) {
      canvas.save();
      canvas.translate(ground.dx, ground.dy);
      canvas.scale(1, 0.32);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromLTWH(-hpx * 0.06, 0, hpx * 0.12, hpx * 0.7),
        Paint()
          ..color = Colors.black.withValues(
            alpha: (a.abs() < 1 ? 0.13 : 0.07) * fade,
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            math.max(1, hpx * 0.02),
          ),
      );
      canvas.restore();
    }
  }

  // ── 공 ──────────────────────────────────────────────────────────────────

  _Ball _ballState() {
    final pb = playback;
    const start = (x: 0.0, y: _ballR, z: PitchGeometry.spotZ);
    _Ball make(
      double x,
      double y,
      double z,
      double spin, {
      bool behind = false,
      List<Offset>? trail,
      Offset? netImpact,
    }) {
      return _Ball(
        center: g.project(x, z, y),
        radius: _ballR * g.pxPerM(z),
        ground: g.project(x, z),
        height: y,
        spin: spin,
        behindLine: behind,
        trail: trail,
        netImpact: netImpact,
      );
    }

    if (pb == null || t < _kickAt) return make(start.x, start.y, start.z, 0);
    final (tx, ty) = g.targetWorld(pb.kickerDir);
    final col = penaltyCol(pb.kickerDir);
    final swerve = col == 1 ? 0.0 : (col - 1) * -0.55;
    (double, double, double) flight(double s) {
      final u = 1 - math.pow(1 - s, 1.5).toDouble();
      final x = start.x + (tx - start.x) * u + math.sin(u * math.pi) * swerve;
      final y = start.y + (ty - start.y) * u + math.sin(u * math.pi) * 0.55;
      final z = start.z * (1 - u);
      return (x, y, z);
    }

    final s = _seg(_kickAt, _flightEnd);
    if (t <= _flightEnd) {
      final (x, y, z) = flight(s);
      final trail = <Offset>[
        for (int i = 1; i <= 6; i++)
          () {
            final (px, py, pz) = flight(math.max(0, s - i * 0.035));
            return g.project(px, pz, py);
          }(),
      ];
      return make(x, y, z, s * 16, trail: trail);
    }
    if (pb.isGoal) {
      // 그물 뒤까지 들어갔다가 떨어진다.
      final backZ = -(1.0 + (1 - ty / PitchGeometry.goalH)) * _netEx * 0.92;
      final a = Curves.easeOutCubic.transform(
        _seg(_flightEnd, _flightEnd + 0.07),
      );
      final drop = Curves.easeIn.transform(_seg(_flightEnd + 0.07, 0.95));
      final z = backZ * a;
      final y = ty + (_ballR - ty) * drop;
      final impact = g.project(tx, backZ, ty);
      return make(tx, y, z, 16 + a * 3, behind: true, netImpact: impact);
    }
    // 막힘: 가운데면 품에 안고, 옆이면 쳐 낸다.
    if (col == 1) {
      return make(tx, ty, 0.5, 16);
    }
    final b = _seg(_flightEnd, 0.96);
    final side = (col - 1).toDouble();
    final e = Curves.easeOut.transform(b);
    final x = tx + side * 2.6 * e;
    final z = 0.4 + 4.2 * e;
    final y = math.max(
      _ballR,
      ty + (_ballR - ty) * b + math.sin(b * math.pi) * 1.4,
    );
    return make(x, y, z, 16 + b * 10);
  }

  void _ballShadow(Canvas canvas, _Ball b) {
    final r = b.radius;
    final lift = (b.height / 2.5).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: b.ground,
        width: r * 2.4 * (1 - 0.4 * lift),
        height: r * 0.7 * (1 - 0.4 * lift),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45 * (1 - 0.6 * lift))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.8, r * 0.25),
        ),
    );
  }

  void _trail(Canvas canvas, _Ball b) {
    final pts = [b.center, ...b.trail!];
    for (int i = 0; i < pts.length - 1; i++) {
      final k = 1 - i / pts.length;
      canvas.drawLine(
        pts[i],
        pts[i + 1],
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = b.radius * 1.6 * k
          ..color = Colors.white.withValues(alpha: 0.16 * k),
      );
    }
  }

  void _ball(Canvas canvas, _Ball b) {
    final c = b.center;
    final r = math.max(2.5, b.radius);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.45),
          radius: 1.0,
          colors: [Colors.white, Color(0xFFE7ECF3), Color(0xFF9AA6B8)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(b.spin);
    final patch = Paint()..color = const Color(0xFF1B2233);
    Path pent(Offset o, double s, double rot) {
      final p = Path();
      for (int i = 0; i < 5; i++) {
        final a = rot - math.pi / 2 + i * math.pi * 2 / 5;
        final q = o + Offset(math.cos(a), math.sin(a)) * s;
        i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
      }
      return p..close();
    }

    canvas.drawPath(pent(Offset.zero, r * 0.34, 0), patch);
    for (int i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 5 + math.pi / 5;
      canvas.drawPath(
        pent(Offset(math.cos(a), math.sin(a)) * r * 0.98, r * 0.3, a + math.pi),
        patch,
      );
    }
    canvas.restore();
    // 반사광.
    canvas.drawCircle(
      c + Offset(-r * 0.35, -r * 0.38),
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  void _parry(Canvas canvas, PenaltyRound pb) {
    final k = _seg(_flightEnd - 0.01, _flightEnd + 0.12);
    if (k <= 0 || k >= 1) return;
    final (tx, ty) = g.targetWorld(pb.kickerDir);
    final c = g.project(tx, 0.5, ty);
    final r = g.goal.height * (0.18 + 0.35 * k);
    _glow(canvas, c, r * 1.3, theme.accent.withValues(alpha: 0.55 * (1 - k)));
    final ray = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2 * (1 - k) + 0.6
      ..color = Colors.white.withValues(alpha: 1 - k);
    for (int i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10 + 0.2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * r * 0.45,
        c + dir * r * (i.isEven ? 1.0 : 0.75),
        ray,
      );
    }
  }

  // ── 조준선 ──────────────────────────────────────────────────────────────

  void _kickerAim(Canvas canvas, Offset ball) {
    final target = g.target(selected!);
    final ctrl = Offset(
      (ball.dx + target.dx) / 2,
      math.min(ball.dy, target.dy) - g.goal.height * 0.35,
    );
    _dottedCurve(canvas, ball, ctrl, target, from: 0.08, to: 0.9);
  }

  void _keeperAim(Canvas canvas, _Figure f) {
    final target = g.target(selected!);
    final start = f.pelvis + Offset(0, -f.height * 0.25);
    final ctrl = Offset(
      (start.dx + target.dx) / 2,
      math.min(start.dy, target.dy) - f.height * 0.2,
    );
    _dottedCurve(canvas, start, ctrl, target, from: 0.15, to: 0.8);
  }

  void _dottedCurve(
    Canvas canvas,
    Offset a,
    Offset c,
    Offset b, {
    required double from,
    required double to,
  }) {
    const n = 14;
    final shift = idle.value * 6 % 1;
    final paint = Paint()..color = theme.accent;
    for (int i = 0; i < n; i++) {
      final s = from + (to - from) * ((i + shift) / n);
      final u = 1 - s;
      final p = a * (u * u) + c * (2 * u * s) + b * (s * s);
      final fade = math.sin(((i + shift) / n) * math.pi);
      paint.color = theme.accent.withValues(alpha: 0.25 + 0.7 * fade);
      canvas.drawCircle(p, 1.4 + 1.6 * (1 - s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) =>
      old.playback != playback ||
      old.geometry.size != geometry.size ||
      old.geometry.cells != geometry.cells ||
      old.kicker != kicker ||
      old.keeper != keeper ||
      old.selected != selected ||
      old.iAmKicker != iAmKicker;
}

class _Figure {
  final AthletePose pose;
  final Offset pelvis;
  final Offset pelvisLocal;
  final double height;
  final double angle;
  final Offset ground;
  final double lift;

  const _Figure({
    required this.pose,
    required this.pelvis,
    required this.pelvisLocal,
    required this.height,
    required this.ground,
    this.angle = 0,
    this.lift = 0,
  });
}

class _Ball {
  final Offset center;
  final double radius;
  final Offset ground;
  final double height;
  final double spin;
  final bool behindLine;
  final List<Offset>? trail;
  final Offset? netImpact;

  const _Ball({
    required this.center,
    required this.radius,
    required this.ground,
    required this.height,
    required this.spin,
    this.behindLine = false,
    this.trail,
    this.netImpact,
  });
}
