import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'yut_models.dart';
import 'yut_pieces.dart';

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

  /// 먹선으로 이어지는 칸 쌍(바깥 길 + 지름길 네 갈래).
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

  static Color cornerColor(int pos) => switch (pos) {
    5 => Obangsaek.blue,
    10 => Obangsaek.red,
    15 => Obangsaek.white,
    20 => Obangsaek.black,
    23 => Obangsaek.yellow,
    _ => Obangsaek.black,
  };
}

enum YutEffectKind { capture, stack, block }

/// 판 위에 잠깐 터지는 연출(먹물 번짐·업기 금빛 고리·방어 푸른 방패).
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

/// 한지 위에 먹선으로 그린 윷판 + 말 + 목적지 미리보기.
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
  final String Function(String player) characterOf;
  final String? Function(String player) skinOf;

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
    required this.characterOf,
    required this.skinOf,
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
  late final AnimationController _brush = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Object? _brushKey;

  @override
  void dispose() {
    _pulse.dispose();
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
        final pad = side * 0.085;
        final inner = side - pad * 2;
        Offset pt(int pos) {
          final l = YutBoardGeometry.logical(pos);
          return Offset(pad + l.dx * inner, pad + l.dy * inner);
        }

        final tokenSize = side * 0.118;
        final tokens = _tokens(pt, tokenSize);
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
                      painter: _BoardPainter(pad: pad, inner: inner),
                    ),
                  ),
                ),
                // 고른 이동의 붓 경로 미리보기.
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
                          pulse: _pulse.value,
                        ),
                      ),
                    ),
                  ),
                ),
                // 연출(먹물·고리·방패).
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
                for (final tk in tokens) _positionedToken(tk, tokenSize),
                // 목적지 표지(탭하면 고르기/확정).
                for (final m in widget.preview) _destination(m, pt, tokenSize),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 말 배치 ────────────────────────────────────────────────────────────
  List<_Tok> _tokens(Offset Function(int) pt, double size) {
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
      final hop = i == j ? 0.0 : math.sin(frac * math.pi) * size * 0.28;
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
      // 잡힌 말은 먹물이 번질 때까지 그 자리에 둔다.
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
      if (n > 0) out[k] = t.shifted(Offset(size * 0.5 * (n.isOdd ? 1 : -1), 0));
    }
    return out;
  }

  Widget _positionedToken(_Tok tk, double size) {
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
    final hit = math.max(size, 48.0);
    final scale = tk.shrink.clamp(0.0, 1.0);
    final body = AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => YutToken(
        size: size,
        color: widget.colorOf(tk.player),
        character: widget.characterOf(tk.player),
        skinEmoji: widget.skinOf(tk.player),
        count: tk.ids.length,
        selected: selected,
        glow: canPick && !selected && _pulse.value > 0.5,
        dimmed: tk.fading,
      ),
    );
    return Positioned(
      left: tk.at.dx - hit / 2,
      top: tk.at.dy - hit / 2,
      width: hit,
      height: hit,
      child: Semantics(
        button: canPick,
        label:
            '${mine ? '내' : '상대'} 말 ${tk.ids.length}개, ${yutSquareName(tk.position) ?? '${tk.position}번 칸'}',
        child: GestureDetector(
          key: ValueKey('yut_token_${tk.player}_$pick'),
          behavior: HitTestBehavior.opaque,
          onTap: canPick ? () => widget.onTapPiece(pick) : null,
          child: Center(
            child: Transform.scale(scale: scale, child: body),
          ),
        ),
      ),
    );
  }

  Widget _destination(
    YutLegalMove m,
    Offset Function(int) pt,
    double tokenSize,
  ) {
    final at = pt(m.to);
    final hit = math.max(tokenSize, 48.0);
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
                      color: Obangsaek.yellow.withValues(alpha: 0.28),
                      border: Border.all(
                        color: isChosen ? Obangsaek.red : Obangsaek.yellow,
                        width: isChosen ? 3 : 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Obangsaek.yellow.withValues(alpha: 0.7 * k),
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
                        size: 24,
                        color: Obangsaek.black,
                      ),
                    ),
                  if (label != null)
                    Positioned(
                      top: -hit * 0.42,
                      child: _FlagLabel(
                        text: label,
                        color: m.captures > 0 ? Obangsaek.red : Obangsaek.blue,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Obangsaek.white, width: 1.2),
      ),
      child: Text(
        text,
        style: GoogleFonts.notoSans(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

// ── 판 그림 ──────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final double pad;
  final double inner;

  _BoardPainter({required this.pad, required this.inner});

  Offset _pt(int pos) {
    final l = YutBoardGeometry.logical(pos);
    return Offset(pad + l.dx * inner, pad + l.dy * inner);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final card = RRect.fromRectAndRadius(
      rect.deflate(size.width * 0.012),
      Radius.circular(size.width * 0.045),
    );
    // 한지 판: 바닥 그림자 + 닥종이 면 + 가장자리 먹 테두리.
    canvas.drawRRect(
      card.shift(const Offset(0, 5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFCF8EC), Color(0xFFF3E9CF)],
        ).createShader(rect),
    );
    final rnd = math.Random(5);
    final fiber = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.clipRRect(card);
    for (int i = 0; i < 160; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final a = rnd.nextDouble() * math.pi;
      final len = 5 + rnd.nextDouble() * 12;
      fiber
        ..strokeWidth = 0.5
        ..color = rnd.nextBool()
            ? const Color(0x16463820)
            : const Color(0x55FFFFFF);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(a) * len, y + math.sin(a) * len),
        fiber,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x992A2623),
    );
    canvas.drawRRect(
      card.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x552A2623),
    );

    // 먹선: 바깥 길은 굵게, 지름길은 조금 가늘게. 붓이 지나간 듯 겹쳐 그린다.
    final outer = <List<int>>[];
    final diagonal = <List<int>>[];
    for (final e in YutBoardGeometry.edges) {
      final isDiag = e.any((p) => p >= 21) || (e[0] == 23 || e[1] == 23);
      (isDiag ? diagonal : outer).add(e);
    }
    for (final e in diagonal) {
      _brushLine(
        canvas,
        _pt(e[0]),
        _pt(e[1]),
        size.width * 0.011,
        seed: e[0] * 31 + e[1],
      );
    }
    for (final e in outer) {
      _brushLine(
        canvas,
        _pt(e[0]),
        _pt(e[1]),
        size.width * 0.015,
        seed: e[0] * 37 + e[1],
      );
    }
    // 진행 방향 쐐기(바깥 길 한가운데에 아주 옅게).
    final chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.007
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x402A2623);
    for (final e in outer) {
      final a = _pt(e[0]);
      final b = _pt(e[1]);
      final m = Offset.lerp(a, b, 0.5)!;
      final d = (b - a);
      final ang = math.atan2(d.dy, d.dx);
      final s = size.width * 0.016;
      final p = Path()
        ..moveTo(m.dx - math.cos(ang - 0.6) * s, m.dy - math.sin(ang - 0.6) * s)
        ..lineTo(m.dx, m.dy)
        ..lineTo(
          m.dx - math.cos(ang + 0.6) * s,
          m.dy - math.sin(ang + 0.6) * s,
        );
      canvas.drawPath(p, chevron);
    }

    // 칸: 일반 칸은 작은 먹점, 모서리·방은 오방색 큰 칸 + 이름.
    final ordinary = <int>[
      for (int p = 1; p <= 29; p++)
        if (!YutBoardGeometry.corners.contains(p)) p,
    ];
    for (final p in ordinary) {
      final c = _pt(p);
      final r = size.width * (p >= 21 ? 0.0165 : 0.021);
      canvas.drawCircle(
        c.translate(0.8, 1.6),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.2),
      );
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF8F1DC));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.0075
          ..color = Obangsaek.black,
      );
    }
    for (final p in YutBoardGeometry.corners) {
      _bigNode(canvas, size, p);
    }
  }

  void _bigNode(Canvas canvas, Size size, int pos) {
    final c = _pt(pos);
    final r = size.width * 0.062;
    final color = YutBoardGeometry.cornerColor(pos);
    canvas.drawCircle(
      c.translate(1.2, 2.6),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [Color.lerp(color, Colors.white, 0.28)!, color],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.011
        ..color = Obangsaek.black,
    );
    canvas.drawCircle(
      c,
      r - size.width * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color =
            (color.computeLuminance() > 0.5 ? Obangsaek.black : Obangsaek.white)
                .withValues(alpha: 0.5),
    );
    final dark = color.computeLuminance() < 0.4;
    final label = yutSquareName(pos) ?? '';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.gowunBatang(
          fontSize: math.max(12.0, size.width * 0.037),
          fontWeight: FontWeight.w800,
          color: dark ? Obangsaek.white : Obangsaek.black,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r * 2);
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// 붓선: 같은 선을 살짝 어긋나게 두세 번 겹쳐 번짐과 마른 붓결을 만든다.
  void _brushLine(
    Canvas canvas,
    Offset a,
    Offset b,
    double width, {
    required int seed,
  }) {
    final rnd = math.Random(seed);
    final dir = b - a;
    final len = dir.distance;
    if (len == 0) return;
    final normal = Offset(-dir.dy / len, dir.dx / len);
    Path wobble(double amp) {
      final path = Path()..moveTo(a.dx, a.dy);
      const n = 6;
      for (int i = 1; i <= n; i++) {
        final p = Offset.lerp(a, b, i / n)!;
        final off = normal * ((rnd.nextDouble() - 0.5) * amp);
        path.lineTo(p.dx + off.dx, p.dy + off.dy);
      }
      return path;
    }

    canvas.drawPath(
      wobble(width * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * 1.5
        ..color = const Color(0x332A2623)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawPath(
      wobble(width * 0.35),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = const Color(0xE62A2623),
    );
    canvas.drawPath(
      wobble(width * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width * 0.35
        ..color = const Color(0x55FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.pad != pad || old.inner != inner;
}

/// 고른 이동 경로를 붓으로 그어 가는 미리보기.
class _PathPreviewPainter extends CustomPainter {
  final List<YutLegalMove> preview;
  final YutLegalMove? chosen;
  final Offset Function(int) point;
  final double brush;
  final double pulse;

  _PathPreviewPainter({
    required this.preview,
    required this.chosen,
    required this.point,
    required this.brush,
    required this.pulse,
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
          ..strokeWidth = size.width * 0.026
          ..color = Obangsaek.red.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = size.width * 0.014
          ..color = Obangsaek.red.withValues(alpha: 0.82),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PathPreviewPainter old) => true;
}

/// 먹물 번짐(잡기) · 금빛 고리(업기) · 푸른 방패 고리(방어).
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
        _ink(canvas);
      case YutEffectKind.stack:
        _ring(canvas, Obangsaek.yellow);
      case YutEffectKind.block:
        _ring(canvas, Obangsaek.blue);
    }
  }

  void _ink(Canvas canvas) {
    final grow = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final fade = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    final rnd = math.Random(77);
    final paint = Paint()
      ..color = Obangsaek.black.withValues(alpha: 0.62 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    canvas.drawCircle(center, unit * 0.075 * grow, paint);
    for (int i = 0; i < 16; i++) {
      final a = i / 16 * math.pi * 2 + rnd.nextDouble() * 0.3;
      final reach = unit * (0.07 + rnd.nextDouble() * 0.09) * grow;
      final r = unit * (0.012 + rnd.nextDouble() * 0.028) * (1 - 0.3 * grow);
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * reach,
        r,
        paint,
      );
      if (i.isEven) {
        // 사방으로 튄 작은 방울.
        canvas.drawCircle(
          center + Offset(math.cos(a), math.sin(a)) * reach * 1.45,
          r * 0.45,
          paint,
        );
      }
    }
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
