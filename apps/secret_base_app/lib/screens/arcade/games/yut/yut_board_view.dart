import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'yut_figures.dart';
import 'yut_models.dart';
import 'yut_palette.dart';

/// 판 위 칸 좌표(0..1). 대기(0)와 참먹이(20)는 같은 오른쪽 아래 모서리.
/// 말은 오른쪽 아래에서 시계 반대 방향으로(오른쪽 → 위 → 왼쪽 → 아래) 한 바퀴 돈다.
class YutBoardGeometry {
  YutBoardGeometry._();

  static Offset logical(int pos) {
    if (pos == 0 || pos == 20) return const Offset(1, 1);
    if (pos >= 1 && pos <= 5) return Offset(1, 1 - pos * 0.2);
    if (pos >= 6 && pos <= 10) return Offset(1 - (pos - 5) * 0.2, 0);
    if (pos >= 11 && pos <= 15) return Offset(0, (pos - 10) * 0.2);
    if (pos >= 16 && pos <= 19) return Offset((pos - 15) * 0.2, 1);
    return switch (pos) {
      21 => const Offset(0.75, 0.25),
      22 => const Offset(0.6, 0.4),
      23 => const Offset(0.5, 0.5),
      24 => const Offset(0.25, 0.25),
      25 => const Offset(0.4, 0.4),
      26 => const Offset(0.6, 0.6),
      27 => const Offset(0.75, 0.75),
      28 => const Offset(0.4, 0.6),
      29 => const Offset(0.25, 0.75),
      _ => const Offset(1, 1),
    };
  }

  /// 흙길로 이어지는 칸 쌍(바깥 길 + 지름길 네 갈래).
  static const List<List<int>> edges = [
    [20, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [4, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [8, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [12, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [16, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [5, 21],
    [21, 22],
    [22, 23],
    [10, 24],
    [24, 25],
    [25, 23],
    [23, 26],
    [26, 27],
    [27, 20],
    [23, 28],
    [28, 29],
    [29, 15],
  ];

  static const corners = [5, 10, 15, 20, 23];

  /// 다섯 자리의 색 이름(청·적·백·흑·황). 낮·밤 팔레트에서 윗면/옆면 색을 찾는다.
  static String stationColor(int pos) => switch (pos) {
    5 => 'blue',
    10 => 'red',
    15 => 'white',
    20 => 'black',
    23 => 'yellow',
    _ => 'white',
  };

  // 2.5D 타일: 위가 살짝 좁은 사다리꼴(판 한 변 S에 대한 비율).
  static const double tileTop = 0.05;
  static const double tileBottom = 0.885;
  static const double topHalf = 0.452;
  static const double bottomHalf = 0.488;
  static const double thickness = 0.045;

  /// 칸 위치(타일 안 비율 → 화면). 위쪽일수록 조금 좁고 작게 보인다.
  static Offset point(int pos, double side) {
    final l = logical(pos);
    final v = 0.13 + l.dy * 0.74;
    final u = 0.095 + l.dx * 0.81;
    final y = side * (tileTop + v * (tileBottom - tileTop));
    final half = side * (topHalf + (bottomHalf - topHalf) * v);
    return Offset(side * 0.5 + (u - 0.5) * 2 * half, y);
  }

  /// 말·칸의 원근 크기(위 0.96 → 아래 1.0).
  static double scaleAt(int pos) =>
      0.96 + 0.04 * (0.13 + logical(pos).dy * 0.74);
}

enum YutEffectKind { capture, stack, block }

/// 판 위에 잠깐 터지는 연출(잡기 별 터짐·업기 금빛 고리·방어 푸른 방패).
@immutable
class YutBoardEffect {
  final YutEffectKind kind;
  final int position;

  const YutBoardEffect(this.kind, this.position);
}

/// 말이 지나가는 동안 판이 그리는 움직임(서버 move.path를 따라 칸마다 폴짝).
@immutable
class YutMoveAnim {
  final String player;
  final YutMoveInfo info;

  const YutMoveAnim(this.player, this.info);
}

/// 풀밭 위에 올린 윷판 + 서 있는 말 + 목적지 미리보기.
///
/// 규칙을 계산하지 않는다: 어디에 누구 말이 있는지(view)와 서버가 준 후보(preview)만 그린다.
class YutBoardView extends StatefulWidget {
  final YutView view;
  final String? me;

  /// 이동 후보를 내가 지금 고를 수 있는 말 번호(대표 말 번호) 집합.
  final Set<int> selectable;
  final int? selectedPieceId;

  /// 고른 칩·말의 목적지 후보(하나, 갈림길이면 둘). 비면 미리보기 없음.
  final List<YutLegalMove> preview;
  final YutLegalMove? chosen;
  final ValueChanged<int> onTapPiece;
  final ValueChanged<YutLegalMove> onTapDestination;
  final Color Function(String player) colorOf;
  final YutFigureSpec Function(String player) specOf;

  final YutMoveAnim? moveAnim;
  final Animation<double>? moveProgress;
  final YutBoardEffect? effect;
  final Animation<double>? effectProgress;

  const YutBoardView({
    super.key,
    required this.view,
    required this.me,
    required this.selectable,
    required this.selectedPieceId,
    required this.preview,
    required this.chosen,
    required this.onTapPiece,
    required this.onTapDestination,
    required this.colorOf,
    required this.specOf,
    this.moveAnim,
    this.moveProgress,
    this.effect,
    this.effectProgress,
  });

  @override
  State<YutBoardView> createState() => _YutBoardViewState();
}

class _YutBoardViewState extends State<YutBoardView>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  late final AnimationController _brush = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Object? _brushKey;

  @override
  void dispose() {
    _pulse.dispose();
    _idle.dispose();
    _brush.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant YutBoardView old) {
    super.didUpdateWidget(old);
    final key = widget.chosen == null
        ? null
        : '${widget.chosen!.moveIndex}:${widget.chosen!.pieceId}:${widget.chosen!.to}';
    if (key != _brushKey) {
      _brushKey = key;
      if (key != null) _brush.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight);
        final pal = YutPalette.of(context);
        Offset pt(int pos) => YutBoardGeometry.point(pos, side);
        final figH = side * 0.17;
        final tokens = _tokens(pt, figH);
        // 아래 줄 말이 위 줄 말 앞에 오도록 y 순으로 그린다.
        tokens.sort((a, b) => a.at.dy.compareTo(b.at.dy));
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const ValueKey('yut_board_surface'),
                      painter: _BoardPainter(pal),
                    ),
                  ),
                ),
                // 고른 이동의 경로 미리보기.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulse, _brush]),
                      builder: (context, _) => CustomPaint(
                        painter: _PathPreviewPainter(
                          preview: widget.preview,
                          chosen: widget.chosen,
                          point: pt,
                          brush: Curves.easeOut.transform(_brush.value),
                          accent: pal.acc,
                          danger: const Color(0xFFE5483B),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.effect != null && widget.effectProgress != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: widget.effectProgress!,
                        builder: (context, _) => CustomPaint(
                          painter: _EffectPainter(
                            effect: widget.effect!,
                            center: pt(widget.effect!.position),
                            t: widget.effectProgress!.value,
                            unit: side,
                            accent: pal.acc,
                          ),
                        ),
                      ),
                    ),
                  ),
                // 목적지 링은 말 뒤에(잡을 상대 말이 가려지지 않게), 누르는 자리는 말 위에.
                for (final m in widget.preview)
                  _destination(m, pt, figH, ringOnly: true),
                for (final tk in tokens) _positionedToken(tk, figH),
                for (final m in widget.preview) _destination(m, pt, figH),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 말 배치 ────────────────────────────────────────────────────────────
  List<_Tok> _tokens(Offset Function(int) pt, double figH) {
    final v = widget.view;
    final anim = widget.moveAnim;
    final progress = widget.moveProgress?.value ?? 1.0;
    final animating = anim != null && progress < 1;
    final out = <_Tok>[];
    for (final player in v.players) {
      final byPos = <int, List<YutPiece>>{};
      for (final p in v.piecesOf(player)) {
        if (!p.onBoard) continue;
        byPos.putIfAbsent(p.position, () => []).add(p);
      }
      for (final e in byPos.entries) {
        final ids = e.value.map((p) => p.id).toList();
        final movingNow =
            animating &&
            anim.player == player &&
            anim.info.pieceIds.any(ids.contains);
        if (movingNow) continue;
        out.add(_Tok(player: player, ids: ids, at: pt(e.key), position: e.key));
      }
    }
    if (animating) {
      final info = anim.info;
      final path = info.path.isEmpty ? [info.from, info.to] : info.path;
      final points = [for (final p in path) pt(p)];
      final f = Curves.easeInOut.transform(progress) * (points.length - 1);
      final i = f.floor().clamp(0, points.length - 1);
      final j = math.min(i + 1, points.length - 1);
      final frac = f - i;
      final pos = Offset.lerp(points[i], points[j], frac)!;
      final hop = i == j ? 0.0 : math.sin(frac * math.pi) * figH * 0.32;
      out.add(
        _Tok(
          player: anim.player,
          ids: info.pieceIds,
          at: pos - Offset(0, hop),
          position: info.to,
          moving: true,
          shrink: info.finish
              ? (progress > 0.82 ? 1 - (progress - 0.82) / 0.18 : 1)
              : 1,
        ),
      );
      // 잡힌 말은 터지는 순간까지 그 자리에 둔다.
      if (info.didCapture && info.capturedPlayer != null && progress < 0.96) {
        out.add(
          _Tok(
            player: info.capturedPlayer!,
            ids: info.captured,
            at: pt(info.to),
            position: info.to,
            fading: true,
          ),
        );
      }
    }
    // 같은 칸에 다른 편 말이 겹치면 살짝 벌린다(참먹이 등).
    final seen = <int, int>{};
    for (var k = 0; k < out.length; k++) {
      final t = out[k];
      if (t.moving) continue;
      final n = seen[t.position] ?? 0;
      seen[t.position] = n + 1;
      if (n > 0) {
        out[k] = t.shifted(Offset(figH * 0.5 * (n.isOdd ? 1 : -1), 0));
      }
    }
    return out;
  }

  Widget _positionedToken(_Tok tk, double figH) {
    final mine = tk.player == widget.me;
    final pick = tk.ids.first;
    final canPick =
        mine &&
        !tk.moving &&
        !tk.fading &&
        tk.ids.any(widget.selectable.contains);
    final selected =
        mine &&
        widget.selectedPieceId != null &&
        tk.ids.contains(widget.selectedPieceId);
    final scale = tk.shrink.clamp(0.0, 1.0);
    final fh = figH * YutBoardGeometry.scaleAt(tk.position);
    final pal = YutPalette.of(context);
    final fig = YutFigure(
      height: fh,
      team: widget.colorOf(tk.player),
      spec: widget.specOf(tk.player),
      count: tk.ids.length,
      selected: selected,
      idle: _idle,
      phase: (tk.position * 0.137 + (mine ? 0 : 0.5)) % 1.0,
      glow: canPick && !selected,
      dimmed: tk.fading,
    );
    final hitW = math.max(fig.width, 48.0);
    final hitH = math.max(fh, 48.0);
    // 발(원판 가운데)이 칸 중심에 오도록 맞춘다.
    final left = tk.at.dx - hitW / 2;
    final top = tk.at.dy - (hitH - fig.anchorFromBottom);
    return Positioned(
      left: left,
      top: top,
      width: hitW,
      height: hitH,
      child: Semantics(
        button: canPick,
        label:
            '${mine ? '내' : '상대'} 말 ${tk.ids.length}개, ${yutSquareName(tk.position) ?? '${tk.position}번 칸'}',
        child: GestureDetector(
          key: ValueKey('yut_token_${tk.player}_$pick'),
          behavior: HitTestBehavior.opaque,
          onTap: canPick ? () => widget.onTapPiece(pick) : null,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Transform.scale(
                scale:
                    scale *
                    (canPick && !selected ? 1 + 0.04 * _pulse.value : 1),
                alignment: Alignment.bottomCenter,
                child: child,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  fig,
                  if (selected)
                    Positioned(
                      top: -9,
                      child: CustomPaint(
                        size: const Size(16, 10),
                        painter: _PointerPainter(pal.acc),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(
    YutLegalMove m,
    Offset Function(int) pt,
    double figH, {
    bool ringOnly = false,
  }) {
    final at = pt(m.to);
    final hit = math.max(figH * 0.8, 48.0);
    final isChosen =
        widget.chosen != null &&
        widget.chosen!.to == m.to &&
        widget.chosen!.backdoDir == m.backdoDir;
    final fork = widget.preview.length > 1;
    final from = m.path.length >= 2
        ? pt(m.path[m.path.length - 2])
        : pt(m.from);
    final angle = math.atan2(at.dy - from.dy, at.dx - from.dx);
    final label = m.finish
        ? '도착'
        : m.captures > 0
        ? '× 잡기'
        : m.stacks > 0
        ? '업기'
        : null;
    final desc = m.finish
        ? '참먹이로 골인'
        : '${yutSquareName(m.to) ?? '${m.to}번 칸'}으로 옮기기${m.captures > 0 ? ', 상대 말 잡기' : ''}';
    final danger = m.captures > 0;
    final pal = YutPalette.of(context);
    final ringColor = danger ? const Color(0xFFE5483B) : pal.acc;
    if (ringOnly) {
      // 칸 둘레의 링(말 뒤). 잡기면 붉은 두 겹 링 + 발밑 붉은 빛.
      return Positioned(
        left: at.dx - hit / 2,
        top: at.dy - hit / 2,
        width: hit,
        height: hit,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final k = 0.5 + 0.5 * _pulse.value;
              final d = hit * (0.8 + 0.12 * k);
              return Center(
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ringColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: ringColor,
                      width: isChosen || danger ? 3 : 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ringColor.withValues(alpha: 0.55 * k),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    // 누르는 자리(말 위, 투명) + 갈림길 화살표 + 머리 위 깃발.
    final flagTop = hit * 0.5 + 2;
    return Positioned(
      left: at.dx - hit / 2,
      top: at.dy - hit / 2,
      width: hit,
      height: hit,
      child: Semantics(
        button: true,
        label: desc,
        child: GestureDetector(
          key: ValueKey('yut_dest_${m.to}_${m.backdoDir ?? 'f'}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTapDestination(m),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (fork)
                Transform.rotate(
                  angle: angle,
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              if (label != null)
                Positioned(
                  top: flagTop,
                  child: _FlagLabel(text: label, danger: danger),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tok {
  final String player;
  final List<int> ids;
  final Offset at;
  final int position;
  final bool moving;
  final bool fading;
  final double shrink;

  const _Tok({
    required this.player,
    required this.ids,
    required this.at,
    required this.position,
    this.moving = false,
    this.fading = false,
    this.shrink = 1,
  });

  _Tok shifted(Offset by) => _Tok(
    player: player,
    ids: ids,
    at: at + by,
    position: position,
    moving: moving,
    fading: fading,
    shrink: shrink,
  );
}

class _FlagLabel extends StatelessWidget {
  final String text;
  final bool danger;

  const _FlagLabel({required this.text, required this.danger});

  @override
  Widget build(BuildContext context) {
    final pal = YutPalette.of(context);
    final base = danger ? const Color(0xFFE5483B) : pal.acc;
    final edge = danger ? const Color(0xFFA82C22) : pal.acc2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 3))],
      ),
      child: Text(
        text,
        style: pal.display(
          size: 15,
          color: danger ? Colors.white : pal.onAcc,
          height: 1.2,
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  final Color color;

  _PointerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) => old.color != color;
}

// ── 판 그림 ──────────────────────────────────────────────────────────────

/// 둥근 모서리 다각형(꼭짓점을 안쪽으로 당긴 뒤 같은 색 선으로 굵게 둘러 만든다).
void _fillRounded(Canvas canvas, List<Offset> pts, double radius, Paint paint) {
  final c = Offset(
    pts.fold<double>(0, (a, b) => a + b.dx) / pts.length,
    pts.fold<double>(0, (a, b) => a + b.dy) / pts.length,
  );
  final inset = [
    for (final p in pts)
      p + (c - p) / (c - p).distance * math.min(radius, (c - p).distance * 0.5),
  ];
  final path = Path()..addPolygon(inset, true);
  canvas.drawPath(path, paint..style = PaintingStyle.fill);
  canvas.drawPath(
    path,
    Paint()
      ..shader = paint.shader
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 2
      ..strokeJoin = StrokeJoin.round,
  );
}

class _BoardPainter extends CustomPainter {
  final YutPalette p;

  _BoardPainter(this.p);

  Offset _pt(int pos, double s) => YutBoardGeometry.point(pos, s);

  List<Offset> _quad(double s, double inset, double dy) {
    final top = s * YutBoardGeometry.tileTop + inset;
    final bottom = s * YutBoardGeometry.tileBottom - inset;
    return [
      Offset(s * (0.5 - YutBoardGeometry.topHalf) + inset, top + dy),
      Offset(s * (0.5 + YutBoardGeometry.topHalf) - inset, top + dy),
      Offset(s * (0.5 + YutBoardGeometry.bottomHalf) - inset, bottom + dy),
      Offset(s * (0.5 - YutBoardGeometry.bottomHalf) + inset, bottom + dy),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final thick = s * YutBoardGeometry.thickness;
    final r = s * 0.06;
    // 바닥 그림자(타일 아래로 길게 번짐).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * YutBoardGeometry.tileBottom + thick * 1.4),
        width: s * 0.92,
        height: s * 0.07,
      ),
      Paint()
        ..color = p.shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.035),
    );
    // 옆면 두께(두 겹).
    _fillRounded(canvas, _quad(s, 0, thick), r, Paint()..color = p.tileSide2);
    _fillRounded(
      canvas,
      _quad(s, 0, thick * 0.55),
      r,
      Paint()..color = p.tileSide,
    );
    // 윗면: 테두리 → 바탕.
    _fillRounded(canvas, _quad(s, 0, 0), r, Paint()..color = p.tileRim);
    _fillRounded(
      canvas,
      _quad(s, s * 0.016, 0),
      r * 0.8,
      Paint()..color = p.tileField,
    );
    // 안쪽 점선.
    final dash = Path()..addPolygon(_quad(s, s * 0.045, 0), true);
    for (final m in dash.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(
          m.extractPath(d, math.min(m.length, d + 4.5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = p.tileInner,
        );
      }
    }
    // 길: 바깥 길 + 지름길(굵은 둥근 선 + 윗결 하이라이트).
    final loop = Path();
    final order = [
      20,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
    ];
    loop.moveTo(_pt(order.first, s).dx, _pt(order.first, s).dy);
    for (final q in order.skip(1)) {
      loop.lineTo(_pt(q, s).dx, _pt(q, s).dy);
    }
    loop.close();
    final diag = Path();
    for (final e in YutBoardGeometry.edges) {
      if (e.any((q) => q >= 21) || e.contains(23)) {
        diag
          ..moveTo(_pt(e[0], s).dx, _pt(e[0], s).dy)
          ..lineTo(_pt(e[1], s).dx, _pt(e[1], s).dy);
      }
    }
    for (final path in [diag, loop]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = s * 0.014
          ..color = p.tileLine,
      );
      canvas.drawPath(
        path.shift(Offset(0, -s * 0.003)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.004
          ..color = p.tileLineHl.withValues(alpha: p.night ? 0.5 : 0.8),
      );
    }
    // 일반 칸: 납작한 흰 알(옆면 아래로).
    for (int q = 1; q <= 29; q++) {
      if (YutBoardGeometry.corners.contains(q)) continue;
      final c = _pt(q, s);
      final sc = YutBoardGeometry.scaleAt(q);
      final w = s * (q >= 21 ? 0.062 : 0.068) * sc;
      final h = w * 0.74;
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, h * 0.28), width: w, height: h),
        Paint()..color = p.pegSide,
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: h),
        Paint()..color = p.pegTop,
      );
    }
    // 다섯 자리: 큰 알 + 이름(옆면 두께).
    for (final q in YutBoardGeometry.corners) {
      _station(canvas, s, q);
    }
    // 출발·도착 안내.
    final tp = TextPainter(
      text: TextSpan(
        text: '출발 · 도착',
        style: p.body(
          size: 12,
          color: p.sub.withValues(alpha: 0.85),
          weight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(s * 0.955 - tp.width, s * (YutBoardGeometry.tileBottom + 0.05)),
    );
  }

  void _station(Canvas canvas, double s, int pos) {
    final c = _pt(pos, s);
    final sc = YutBoardGeometry.scaleAt(pos);
    final w = s * 0.2 * sc;
    final h = w * 0.74;
    final colors = p.station[YutBoardGeometry.stationColor(pos)]!;
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, h * 0.2 + 3),
        width: w * 1.02,
        height: h,
      ),
      Paint()
        ..color = p.shadow.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, h * 0.26), width: w, height: h),
      Paint()..color = colors.$2,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w, height: h),
      Paint()..color = colors.$1,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: yutSquareName(pos) ?? '',
        style: p.display(
          size: math.max(13.0, s * 0.046),
          color: p.stationLabel,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => old.p != p;
}

/// 고른 이동 경로: 흐르는 점선 대신 앞에서부터 그어지는 굵은 선.
class _PathPreviewPainter extends CustomPainter {
  final List<YutLegalMove> preview;
  final YutLegalMove? chosen;
  final Offset Function(int) point;
  final double brush;
  final Color accent;
  final Color danger;

  _PathPreviewPainter({
    required this.preview,
    required this.chosen,
    required this.point,
    required this.brush,
    required this.accent,
    required this.danger,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in preview) {
      final isChosen =
          chosen != null &&
          chosen!.to == m.to &&
          chosen!.backdoDir == m.backdoDir;
      if (preview.length > 1 && !isChosen) continue;
      final pts = [for (final q in m.path) point(q)];
      if (pts.length < 2) continue;
      final total = <double>[0];
      for (int i = 1; i < pts.length; i++) {
        total.add(total.last + (pts[i] - pts[i - 1]).distance);
      }
      final upTo = total.last * brush;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        if (total[i] <= upTo) {
          path.lineTo(pts[i].dx, pts[i].dy);
        } else {
          final seg = total[i] - total[i - 1];
          final k = seg == 0 ? 0.0 : (upTo - total[i - 1]) / seg;
          final q = Offset.lerp(pts[i - 1], pts[i], k.clamp(0.0, 1.0))!;
          path.lineTo(q.dx, q.dy);
          break;
        }
      }
      final color = m.captures > 0 ? danger : accent;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = size.width * 0.03
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = size.width * 0.013
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PathPreviewPainter old) => true;
}

/// 잡기 터짐(불꽃 + 점) · 업기/방어 고리.
class _EffectPainter extends CustomPainter {
  final YutBoardEffect effect;
  final Offset center;
  final double t;
  final double unit;
  final Color accent;

  _EffectPainter({
    required this.effect,
    required this.center,
    required this.t,
    required this.unit,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect.kind) {
      case YutEffectKind.capture:
        _burst(canvas);
      case YutEffectKind.stack:
        _ring(canvas, const Color(0xFFFFC93C));
      case YutEffectKind.block:
        _ring(canvas, const Color(0xFF4F8CFF));
    }
  }

  void _burst(Canvas canvas) {
    final grow = Curves.easeOutCubic.transform((t * 1.5).clamp(0.0, 1.0));
    final fade = t < 0.45 ? 1.0 : (1 - (t - 0.45) / 0.55).clamp(0.0, 1.0);
    final ray = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 0.011
      ..color = accent.withValues(alpha: fade);
    const n = 10;
    for (int i = 0; i < n; i++) {
      final a = i / n * math.pi * 2 + 0.2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + d * unit * (0.05 + 0.04 * grow),
        center + d * unit * (0.07 + 0.1 * grow),
        ray,
      );
    }
    for (int i = 0; i < 8; i++) {
      final a = i / 8 * math.pi * 2 + 0.55;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * unit * (0.07 + 0.12 * grow),
        unit * 0.009 * (1 - 0.4 * grow),
        Paint()..color = const Color(0xFFFFC93C).withValues(alpha: fade),
      );
    }
    canvas.drawCircle(
      center,
      unit * (0.05 + 0.1 * grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.01 * (1 - grow * 0.5)
        ..color = accent.withValues(alpha: 0.8 * fade),
    );
  }

  void _ring(Canvas canvas, Color color) {
    final k = Curves.easeOut.transform(t.clamp(0.0, 1.0));
    final fade = (1 - t).clamp(0.0, 1.0);
    for (int i = 0; i < 2; i++) {
      final kk = (k - i * 0.18).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        unit * (0.05 + 0.1 * kk),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.01 * (1 - kk * 0.6)
          ..color = color.withValues(alpha: 0.9 * fade * (1 - i * 0.35)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) =>
      old.t != t || old.effect != effect || old.center != center;
}
