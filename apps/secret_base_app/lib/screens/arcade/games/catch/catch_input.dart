/// 그리는 손: 한 손가락 `Listener` + 33ms 묶음 전송.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'catch_models.dart';
import 'catch_paint.dart';

/// 서버로 보낼 획 묶음 하나(`game:catch:stroke`).
class StrokeBatch {
  final String id;
  final int seq;
  final CatchTool tool;
  final int color;
  final double w;
  final List<Offset> pts;
  final bool end;

  const StrokeBatch({
    required this.id,
    required this.seq,
    required this.tool,
    required this.color,
    required this.w,
    required this.pts,
    required this.end,
  });

  Map<String, dynamic> toPayload(int round) => {
    'round': round,
    'id': id,
    'seq': seq,
    'tool': tool.wire,
    'color': tool == CatchTool.eraser ? 0 : color,
    'w': w,
    'pts': [
      for (final p in pts) [_r4(p.dx), _r4(p.dy)],
    ],
    'end': end,
  };

  static double _r4(double v) => (v * 10000).roundToDouble() / 10000;
}

/// 손가락이 닿아 있는 동안 점을 모아 [interval]마다 한 묶음씩 보내고,
/// 손을 떼면 남은 점을 즉시 `end: true`로 보낸다.
class StrokeBatcher {
  final void Function(StrokeBatch batch) onBatch;
  final Duration interval;

  StrokeBatcher({
    required this.onBatch,
    this.interval = const Duration(milliseconds: 33),
  });

  Timer? _timer;
  String? _id;
  CatchTool _tool = CatchTool.pen;
  int _color = 0;
  double _w = 0.016;
  int _seq = 0;
  final List<Offset> _pending = [];
  Offset? _last;

  bool get active => _id != null;

  void start(
    String id, {
    required CatchTool tool,
    required int color,
    required double w,
    required Offset first,
  }) {
    cancel();
    _id = id;
    _tool = tool;
    _color = color;
    _w = w;
    _seq = 0;
    _last = first;
    _pending
      ..clear()
      ..add(first);
    _timer = Timer.periodic(interval, (_) => _flush(end: false));
  }

  void add(Offset p) {
    if (_id == null) return;
    _pending.add(p);
    _last = p;
  }

  /// 손을 뗐다. 남은 점(없으면 마지막 점)을 마지막 묶음으로 바로 보낸다.
  void end() {
    if (_id == null) return;
    _flush(end: true);
    cancel();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _id = null;
    _pending.clear();
  }

  void _flush({required bool end}) {
    final id = _id;
    if (id == null) return;
    if (_pending.isEmpty && !end) return;
    final pts = _pending.isEmpty && _last != null
        ? [_last!]
        : List<Offset>.of(_pending);
    _pending.clear();
    // 서버는 묶음당 점 80개까지 받는다. 넘치면 쪼개서 보낸다.
    for (var i = 0; i < pts.length; i += 80) {
      final chunk = pts.sublist(i, i + 80 > pts.length ? pts.length : i + 80);
      final isLast = i + 80 >= pts.length;
      onBatch(
        StrokeBatch(
          id: id,
          seq: _seq++,
          tool: _tool,
          color: _color,
          w: _w,
          pts: chunk,
          end: end && isLast,
        ),
      );
    }
  }
}

/// 보드 위에서 그리는 손. 한 손가락만 받고(두 번째 손가락은 무시), 탭도 점으로 남는다.
class CatchDrawingSurface extends StatefulWidget {
  final CatchCanvasModel model;
  final bool enabled;
  final CatchTool tool;
  final int color;
  final int sizeIndex;
  final String Function() nextId;
  final void Function(StrokeBatch batch) onBatch;
  final void Function(String id) onStrokeDone;

  const CatchDrawingSurface({
    super.key,
    required this.model,
    required this.enabled,
    required this.tool,
    required this.color,
    required this.sizeIndex,
    required this.nextId,
    required this.onBatch,
    required this.onStrokeDone,
  });

  @override
  State<CatchDrawingSurface> createState() => _CatchDrawingSurfaceState();
}

class _CatchDrawingSurfaceState extends State<CatchDrawingSurface> {
  late final StrokeBatcher _batcher = StrokeBatcher(
    onBatch: (b) => widget.onBatch(b),
  );
  int? _pointer;
  CatchStroke? _stroke;
  Offset? _lastLocal;

  Offset _normalize(Offset local) {
    final size = context.size ?? const Size(1, 1);
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _down(PointerDownEvent e) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = e.pointer;
    _lastLocal = e.localPosition;
    final n = _normalize(e.localPosition);
    final tool = widget.tool;
    final color = tool == CatchTool.eraser ? 0 : widget.color;
    final w = kCatchBrushWidths[widget.sizeIndex.clamp(0, 2)];
    final stroke = CatchStroke(
      id: widget.nextId(),
      tool: tool,
      color: color,
      w: w,
    )..add(n);
    _stroke = stroke;
    widget.model.begin(stroke);
    _batcher.start(stroke.id, tool: tool, color: color, w: w, first: n);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final stroke = _stroke;
    if (stroke == null) return;
    final last = _lastLocal;
    // 1px도 안 움직인 이동은 점만 늘리므로 건너뛴다.
    if (last != null && (e.localPosition - last).distanceSquared < 1.0) return;
    _lastLocal = e.localPosition;
    final n = _normalize(e.localPosition);
    widget.model.append(stroke.id, [n]);
    _batcher.add(n);
  }

  void _finish(PointerEvent e) {
    if (e.pointer != _pointer) return;
    final stroke = _stroke;
    _pointer = null;
    _stroke = null;
    _lastLocal = null;
    if (stroke == null) return;
    final last = stroke.pts.last;
    final n = _normalize(e.localPosition);
    // 손을 뗀 위치가 마지막 점과 다르면 그 점까지 이어 준다(마지막 점 누락 방지). 탭은 점 하나로 둔다.
    final size = context.size ?? const Size(1, 1);
    final moved = Offset(
      (n.dx - last.dx) * size.width,
      (n.dy - last.dy) * size.height,
    ).distanceSquared;
    if (stroke.pts.length > 1 && moved >= 1.0) {
      widget.model.append(stroke.id, [n]);
      _batcher.add(n);
    }
    widget.model.finish(stroke.id);
    _batcher.end();
    widget.onStrokeDone(stroke.id);
  }

  @override
  void didUpdateWidget(covariant CatchDrawingSurface old) {
    super.didUpdateWidget(old);
    // 라운드가 끝나 그릴 수 없게 되면 그리던 획을 그 자리에서 마무리한다.
    if (old.enabled && !widget.enabled) _abort();
  }

  void _abort() {
    final stroke = _stroke;
    _pointer = null;
    _stroke = null;
    _lastLocal = null;
    if (stroke == null) return;
    widget.model.finish(stroke.id);
    _batcher.end();
  }

  @override
  void dispose() {
    _batcher.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _finish,
      onPointerCancel: _finish,
      child: const SizedBox.expand(),
    );
  }
}
