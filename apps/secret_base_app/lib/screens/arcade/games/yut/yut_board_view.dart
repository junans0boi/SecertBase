import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'yut_figures.dart';
import 'yut_models.dart';

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

  /// 모서리 동전 안쪽 색(오방색 표시).
  static Color cornerColor(int pos) => switch (pos) {
    5 => Obangsaek.blue,
    10 => Obangsaek.red,
    15 => Obangsaek.white,
    20 => Obangsaek.black,
    23 => Obangsaek.yellow,
    _ => Obangsaek.black,
  };

  // 판 안에서 격자가 놓이는 자리(판 한 변 S에 대한 비율). 말이 머리 위로 솟아도
  // 판 밖으로 나가지 않게 위쪽에 여유를 둔다.
  static const double gridLeft = 0.10;
  static const double gridWidth = 0.80;
  static const double gridTop = 0.195;
  static const double gridHeight = 0.665;

  static Offset point(int pos, double side) {
    final l = logical(pos);
    return Offset(
      side * (gridLeft + l.dx * gridWidth),
      side * (gridTop + l.dy * gridHeight),
    );
  }
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
        Offset pt(int pos) => YutBoardGeometry.point(pos, side);
        final figH = side * 0.165;
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
                      painter: _BoardPainter(),
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
                          ),
                        ),
                      ),
                    ),
                  ),
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
    final fig = YutFigure(
      height: figH,
      team: widget.colorOf(tk.player),
      spec: widget.specOf(tk.player),
      count: tk.ids.length,
      selected: selected,
      idle: _idle,
      phase: (tk.position * 0.137 + (mine ? 0 : 0.5)) % 1.0,
      glow: false,
      dimmed: tk.fading,
    );
    final hitW = math.max(fig.width, 48.0);
    final hitH = math.max(figH, 48.0);
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
              child: canPick && !selected
                  ? _PickGlow(pulse: _pulse, child: fig)
                  : fig,
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(YutLegalMove m, Offset Function(int) pt, double figH) {
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
        ? '잡기'
        : m.stacks > 0
        ? '업기'
        : null;
    final desc = m.finish
        ? '참먹이로 골인'
        : '${yutSquareName(m.to) ?? '${m.to}번 칸'}으로 옮기기${m.captures > 0 ? ', 상대 말 잡기' : ''}';
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
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final k = 0.5 + 0.5 * _pulse.value;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: hit * (0.78 + 0.12 * k),
                    height: hit * (0.78 + 0.12 * k),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isChosen
                            ? const Color(0xFFEF4F2B)
                            : const Color(0xFFFFB000),
                        width: isChosen ? 3.4 : 2.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFE066,
                          ).withValues(alpha: 0.85 * k),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  if (fork)
                    Transform.rotate(
                      angle: angle,
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 26,
                        color: Color(0xFF263A2A),
                      ),
                    ),
                  if (label != null)
                    Positioned(
                      top: -hit * 0.4,
                      child: _FlagLabel(
                        text: label,
                        color: m.captures > 0
                            ? const Color(0xFFE5534B)
                            : const Color(0xFF2F82DE),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 고를 수 있는 말 뒤에서 깜빡이는 노란 빛.
class _PickGlow extends StatelessWidget {
  final Animation<double> pulse;
  final Widget child;

  const _PickGlow({required this.pulse, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFFFE066,
            ).withValues(alpha: 0.28 + 0.3 * pulse.value),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
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
  final Color color;

  const _FlagLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Text(
        text,
        style: GoogleFonts.jua(fontSize: 13, color: Colors.white, height: 1.1),
      ),
    );
  }
}

// ── 판 그림 ──────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  Offset _pt(int pos, double s) => YutBoardGeometry.point(pos, s);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final face = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.02, s * 0.07, s * 0.96, s * 0.865),
      Radius.circular(s * 0.075),
    );
    final thick = s * 0.052;
    final sideRect = face.shift(Offset(0, thick));
    // 바닥 그림자.
    canvas.drawRRect(
      sideRect.shift(Offset(0, s * 0.012)).inflate(s * 0.008),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );
    // 옆면: 흙(두께) 위에 풀 가장자리.
    canvas.drawRRect(
      sideRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9C6B3C), Color(0xFF6B4524)],
        ).createShader(sideRect.outerRect),
    );
    final soil = Paint()
      ..color = const Color(0x40301A08)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(14);
    for (int i = 0; i < 26; i++) {
      final x = face.left + face.width * (0.06 + rnd.nextDouble() * 0.88);
      final y = face.bottom + thick * (0.25 + rnd.nextDouble() * 0.6);
      canvas.drawLine(Offset(x, y), Offset(x + s * 0.02, y), soil);
    }
    // 윗면: 잔디.
    canvas.drawRRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9AE05F), Color(0xFF66BC46)],
        ).createShader(face.outerRect),
    );
    canvas.save();
    canvas.clipRRect(face);
    // 잔디 결(깎은 줄무늬).
    for (int i = 0; i < 9; i++) {
      if (i.isOdd) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          face.left,
          face.top + face.height * i / 9,
          face.width,
          face.height / 9,
        ),
        Paint()..color = const Color(0x14FFFFFF),
      );
    }
    final blade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    for (int i = 0; i < 150; i++) {
      final x = face.left + rnd.nextDouble() * face.width;
      final y = face.top + rnd.nextDouble() * face.height;
      blade.color = rnd.nextBool()
          ? const Color(0x3326561E)
          : const Color(0x33E6FFB0);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 1.5, y - 4 - rnd.nextDouble() * 4),
        blade,
      );
    }
    canvas.restore();
    // 윗면 테두리: 어두운 풀 + 안쪽 밝은 선.
    canvas.drawRRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = const Color(0xFF3F8F34),
    );
    canvas.drawRRect(
      face.deflate(s * 0.012),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x66FFFFFF),
    );

    // 흙길: 바깥 길 + 지름길.
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
    for (final p in order.skip(1)) {
      loop.lineTo(_pt(p, s).dx, _pt(p, s).dy);
    }
    loop.close();
    final diag = Path();
    for (final e in YutBoardGeometry.edges) {
      if (e.any((p) => p >= 21) || e.contains(23)) {
        diag
          ..moveTo(_pt(e[0], s).dx, _pt(e[0], s).dy)
          ..lineTo(_pt(e[1], s).dx, _pt(e[1], s).dy);
      }
    }
    void road(Path path, double w) {
      Paint p(double width, Color c) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = c;
      canvas.drawPath(path, p(w * 1.25, const Color(0x55704A20)));
      canvas.drawPath(path, p(w, const Color(0xFFC79A5B)));
      canvas.drawPath(path, p(w * 0.78, const Color(0xFFE2BE82)));
      canvas.drawPath(path, p(w * 0.28, const Color(0x40FFFFFF)));
    }

    road(diag, s * 0.048);
    road(loop, s * 0.056);

    // 풀꽃·잎: 길과 칸에서 떨어진 자리에만.
    final spots = <Offset>[for (int p = 0; p <= 29; p++) _pt(p, s)];
    bool free(Offset o) {
      for (final p in spots) {
        if ((p - o).distance < s * 0.07) return false;
      }
      for (final e in YutBoardGeometry.edges) {
        final a = _pt(e[0], s), b = _pt(e[1], s);
        final ab = b - a;
        final t =
            (((o - a).dx * ab.dx + (o - a).dy * ab.dy) /
                    (ab.dx * ab.dx + ab.dy * ab.dy))
                .clamp(0.0, 1.0);
        if ((a + ab * t - o).distance < s * 0.05) return false;
      }
      return true;
    }

    final fr = math.Random(31);
    var placed = 0;
    for (int tries = 0; tries < 400 && placed < 14; tries++) {
      final o = Offset(
        face.left + s * 0.04 + fr.nextDouble() * (face.width - s * 0.08),
        face.top + s * 0.04 + fr.nextDouble() * (face.height - s * 0.08),
      );
      if (!free(o)) continue;
      placed++;
      if (placed.isEven) {
        _flower(
          canvas,
          o,
          s * 0.016,
          placed % 4 == 0 ? const Color(0xFFFFE066) : Colors.white,
          const Color(0xFFFFB000),
        );
      } else if (placed % 3 == 0) {
        _flower(
          canvas,
          o,
          s * 0.014,
          const Color(0xFFFF9EC0),
          const Color(0xFFFFF3B0),
        );
      } else {
        _tuft(canvas, o, s * 0.02);
      }
    }

    // 칸: 일반 칸은 금 동전, 모서리·방은 큰 동전 + 오방색 안쪽 + 이름.
    for (int p = 1; p <= 29; p++) {
      if (YutBoardGeometry.corners.contains(p)) continue;
      _coin(canvas, _pt(p, s), s * (p >= 21 ? 0.03 : 0.036));
    }
    for (final p in YutBoardGeometry.corners) {
      _bigCoin(canvas, s, p);
    }
  }

  void _flower(Canvas canvas, Offset c, double r, Color petal, Color center) {
    for (int i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r,
        r * 0.8,
        Paint()..color = petal,
      );
    }
    canvas.drawCircle(c, r * 0.65, Paint()..color = center);
  }

  void _tuft(Canvas canvas, Offset c, double r) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.28
      ..color = const Color(0xFF2F7F2A);
    for (final dx in [-0.5, 0.0, 0.5]) {
      canvas.drawLine(
        c,
        c + Offset(dx * r * 1.2, -r * (dx == 0 ? 1.5 : 1.1)),
        p,
      );
    }
  }

  void _coin(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c.translate(0.8, 2),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Color(0xFFFFE98A), Color(0xFFE2A91F)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..color = const Color(0xFFB07A10),
    );
    canvas.drawCircle(
      c,
      r * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x88FFF6C8),
    );
    // 동전 가운데 × 무늬.
    final x = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.2
      ..color = const Color(0xFFB07A10);
    final k = r * 0.3;
    canvas.drawLine(c.translate(-k, -k), c.translate(k, k), x);
    canvas.drawLine(c.translate(-k, k), c.translate(k, -k), x);
  }

  void _bigCoin(Canvas canvas, double s, int pos) {
    final c = _pt(pos, s);
    final r = s * 0.074;
    final color = YutBoardGeometry.cornerColor(pos);
    canvas.drawCircle(
      c.translate(1.2, 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Color(0xFFFFE98A), Color(0xFFE2A91F)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.011
        ..color = const Color(0xFFB07A10),
    );
    // 오방색 안쪽 원판.
    final ir = r * 0.78;
    canvas.drawCircle(
      c,
      ir,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [Color.lerp(color, Colors.white, 0.28)!, color],
        ).createShader(Rect.fromCircle(center: c, radius: ir)),
    );
    canvas.drawCircle(
      c,
      ir,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF6B4A10),
    );
    final dark = color.computeLuminance() < 0.4;
    final label = yutSquareName(pos) ?? '';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.jua(
          fontSize: math.max(12.0, s * 0.036),
          color: dark ? Colors.white : const Color(0xFF263A2A),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => false;
}

/// 고른 이동 경로를 한 줄로 그어 가는 미리보기.
class _PathPreviewPainter extends CustomPainter {
  final List<YutLegalMove> preview;
  final YutLegalMove? chosen;
  final Offset Function(int) point;
  final double brush;

  _PathPreviewPainter({
    required this.preview,
    required this.chosen,
    required this.point,
    required this.brush,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in preview) {
      final isChosen =
          chosen != null &&
          chosen!.to == m.to &&
          chosen!.backdoDir == m.backdoDir;
      if (preview.length > 1 && !isChosen) continue;
      final pts = [for (final p in m.path) point(p)];
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
          final p = Offset.lerp(pts[i - 1], pts[i], k.clamp(0.0, 1.0))!;
          path.lineTo(p.dx, p.dy);
          break;
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = size.width * 0.03
          ..color = Colors.white.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = size.width * 0.014
          ..color = const Color(0xFFEF4F2B),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PathPreviewPainter old) => true;
}

/// 잡기 별 터짐 · 업기 금빛 고리 · 방어 푸른 방패 고리.
class _EffectPainter extends CustomPainter {
  final YutBoardEffect effect;
  final Offset center;
  final double t;
  final double unit;

  _EffectPainter({
    required this.effect,
    required this.center,
    required this.t,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect.kind) {
      case YutEffectKind.capture:
        _burst(canvas);
      case YutEffectKind.stack:
        _ring(canvas, const Color(0xFFFFC93C));
      case YutEffectKind.block:
        _ring(canvas, const Color(0xFF2F82DE));
    }
  }

  void _burst(Canvas canvas) {
    final grow = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final fade = t < 0.55 ? 1.0 : (1 - (t - 0.55) / 0.45).clamp(0.0, 1.0);
    // 번쩍이는 별 모양 + 사방으로 튀는 조각 + 먼지 고리.
    final star = Path();
    const spikes = 10;
    final outer = unit * (0.05 + 0.1 * grow);
    final inner = outer * 0.5;
    for (int i = 0; i < spikes * 2; i++) {
      final a = i * math.pi / spikes - math.pi / 2;
      final r = i.isEven ? outer : inner;
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()..color = const Color(0xFFFFD23D).withValues(alpha: 0.95 * fade),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.01
        ..color = const Color(0xFFEF4F2B).withValues(alpha: fade),
    );
    final rnd = math.Random(77);
    for (int i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2 + rnd.nextDouble() * 0.3;
      final reach = unit * (0.1 + rnd.nextDouble() * 0.1) * grow;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * reach,
        unit * (0.008 + rnd.nextDouble() * 0.014) * (1 - 0.4 * grow),
        Paint()
          ..color = (i.isEven ? const Color(0xFFEF4F2B) : Colors.white)
              .withValues(alpha: fade),
      );
    }
    canvas.drawCircle(
      center,
      unit * (0.06 + 0.12 * grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.012 * (1 - grow * 0.6)
        ..color = Colors.white.withValues(alpha: 0.8 * fade),
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
          ..strokeWidth = unit * 0.014 * (1 - kk * 0.6)
          ..color = color.withValues(alpha: 0.9 * fade * (1 - i * 0.35)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) =>
      old.t != t || old.effect != effect || old.center != center;
}
