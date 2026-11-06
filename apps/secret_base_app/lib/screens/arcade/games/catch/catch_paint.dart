/// 그림 맞히기 보드 그리기: 획 한 개 그리기, 완료 획 캐시, 종이·스프링 장식.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'catch_models.dart';

/// 획 하나를 가상 보드(1000×750) 좌표로 그린다. 지우개는 [BlendMode.clear]라서
/// 반드시 `saveLayer` 안에서 그려야 종이가 아니라 획만 지워진다.
void paintCatchStroke(Canvas canvas, CatchStroke s) {
  if (s.pts.isEmpty) return;
  final base = kCatchPalette[s.color.clamp(0, kCatchPalette.length - 1)].color;
  final width = s.strokeWidth;
  switch (s.tool) {
    case CatchTool.pen:
      // 연필: 살짝 옅은 바깥 선 + 진한 심. 가장자리가 부드러운 흑연 느낌.
      final soft = Paint()
        ..color = base.withValues(alpha: 0.86)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width;
      final core = Paint()
        ..color = base
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1.2, width * 0.5);
      if (s.isDot) {
        final c = s.lastVirtual!;
        canvas.drawCircle(c, width / 2, Paint()..color = soft.color);
        canvas.drawCircle(
          c,
          math.max(0.6, width * 0.25),
          Paint()..color = base,
        );
      } else {
        final p = s.path;
        canvas.drawPath(p, soft);
        canvas.drawPath(p, core);
      }
    case CatchTool.marker:
      // 마커: 넓고 반투명한 네모 촉. 겹치면 진해진다.
      final paint = Paint()
        ..color = base.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.bevel
        ..strokeWidth = width;
      if (s.isDot) {
        final c = s.lastVirtual!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: width, height: width),
            Radius.circular(width * 0.22),
          ),
          Paint()..color = paint.color,
        );
      } else {
        canvas.drawPath(s.path, paint);
      }
    case CatchTool.eraser:
      final paint = Paint()
        ..blendMode = BlendMode.clear
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width;
      if (s.isDot) {
        canvas.drawCircle(
          s.lastVirtual!,
          width / 2,
          Paint()
            ..blendMode = BlendMode.clear
            ..color = const Color(0xFF000000),
        );
      } else {
        canvas.drawPath(s.path, paint);
      }
  }
}

/// 보드의 획 모음. 끝난 획은 `Picture` 하나로 구워 두고(캐시), 진행 중인 획만 매 프레임 다시 그린다.
/// 되돌리기·지우기·다시 받기 때만 처음부터 다시 굽는다.
class CatchCanvasModel extends ChangeNotifier {
  final List<CatchStroke> strokes = [];
  ui.Picture? _picture;
  int _baked = 0;
  int _commitsSinceFlatten = 0;

  /// 중첩 그림이 너무 깊어지기 전에 한 번씩 평평하게 다시 굽는 간격.
  static const int flattenEvery = 24;

  ui.Picture? get picture => _picture;
  int get bakedCount => _baked;

  /// 아직 구워지지 않은 획(진행 중인 획과 그 뒤의 획).
  Iterable<CatchStroke> get live => strokes.skip(_baked);
  bool get isEmpty => strokes.isEmpty;

  CatchStroke? byId(String id) {
    for (var i = strokes.length - 1; i >= 0; i--) {
      if (strokes[i].id == id) return strokes[i];
    }
    return null;
  }

  CatchStroke begin(CatchStroke stroke) {
    strokes.add(stroke);
    notifyListeners();
    return stroke;
  }

  void append(String id, Iterable<Offset> points) {
    final s = byId(id);
    if (s == null || !s.open) return;
    s.addAll(points);
    notifyListeners();
  }

  void finish(String id) {
    final s = byId(id);
    if (s == null) return;
    s.finish();
    _bakeReady();
    notifyListeners();
  }

  void remove(String id) {
    final i = strokes.lastIndexWhere((s) => s.id == id);
    if (i < 0) return;
    strokes.removeAt(i);
    _rebuild();
    notifyListeners();
  }

  void clear() {
    if (strokes.isEmpty && _picture == null) return;
    strokes.clear();
    _rebuild();
    notifyListeners();
  }

  /// 서버가 다시 보낸 그림으로 통째로 바꾼다(재접속).
  void replaceAll(Iterable<CatchStroke> next) {
    strokes
      ..clear()
      ..addAll(next);
    _rebuild();
    notifyListeners();
  }

  void _bakeReady() {
    var end = _baked;
    while (end < strokes.length && !strokes[end].open) {
      end++;
    }
    if (end == _baked) return;
    if (_commitsSinceFlatten >= flattenEvery) {
      _bakeFrom(0, end);
      return;
    }
    _bakeFrom(_baked, end, keep: _picture);
  }

  void _rebuild() {
    var end = 0;
    while (end < strokes.length && !strokes[end].open) {
      end++;
    }
    _bakeFrom(0, end);
  }

  void _bakeFrom(int from, int to, {ui.Picture? keep}) {
    final old = _picture;
    if (to == 0) {
      _picture = null;
      _baked = 0;
      _commitsSinceFlatten = 0;
      old?.dispose();
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (keep != null) canvas.drawPicture(keep);
    for (var i = from; i < to; i++) {
      paintCatchStroke(canvas, strokes[i]);
    }
    _picture = recorder.endRecording();
    _commitsSinceFlatten = keep == null ? 0 : _commitsSinceFlatten + 1;
    _baked = to;
    old?.dispose();
  }

  @override
  void dispose() {
    _picture?.dispose();
    _picture = null;
    super.dispose();
  }
}

/// 구워 둔 획 + 진행 중인 획을 한 겹(layer)에 그린다. 지우개가 획만 지우도록 `saveLayer` 안에서 그린다.
class CatchStrokesPainter extends CustomPainter {
  final CatchCanvasModel model;

  CatchStrokesPainter(this.model) : super(repaint: model);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kCatchVirtualW;
    canvas.save();
    canvas.scale(scale);
    final bounds = const Rect.fromLTWH(0, 0, kCatchVirtualW, kCatchVirtualH);
    canvas.saveLayer(bounds, Paint());
    final picture = model.picture;
    if (picture != null) canvas.drawPicture(picture);
    for (final s in model.live) {
      paintCatchStroke(canvas, s);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatchStrokesPainter old) => old.model != model;
}

/// 이미 끝난 획 목록을 작게 그린다(결과 갤러리).
class CatchStaticStrokesPainter extends CustomPainter {
  final List<CatchStroke> strokes;

  CatchStaticStrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kCatchVirtualW;
    canvas.save();
    canvas.scale(scale);
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, kCatchVirtualW, kCatchVirtualH),
      Paint(),
    );
    for (final s in strokes) {
      paintCatchStroke(canvas, s);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatchStaticStrokesPainter old) =>
      !identical(old.strokes, strokes);
}

/// 크림색 종이 결: 은은한 섬유와 점 얼룩, 가장자리 그늘.
class SketchPaperPainter extends CustomPainter {
  const SketchPaperPainter();

  static const Color paper = Color(0xFFFFFBF0);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = paper);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.0,
          colors: [Color(0x00FFFFFF), Color(0x1AD9C49A)],
          stops: [0.55, 1],
        ).createShader(rect),
    );
    final rnd = math.Random(17);
    final dots = Paint()..color = const Color(0x12806040);
    final count = (size.width * size.height / 260).round();
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 0.7 + 0.15,
        dots,
      );
    }
    final fibre = Paint()
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x14A0825A);
    for (var i = 0; i < count ~/ 14; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final a = rnd.nextDouble() * math.pi;
      final l = 3 + rnd.nextDouble() * 6;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(a) * l, y + math.sin(a) * l),
        fibre,
      );
    }
    // 스프링 아래쪽 그늘.
    final top = Rect.fromLTWH(0, 0, size.width, 26);
    canvas.drawRect(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x26806040), Color(0x00806040)],
        ).createShader(top),
    );
  }

  @override
  bool shouldRepaint(covariant SketchPaperPainter old) => false;
}

/// 스케치북 윗변의 스프링 철: 종이에 뚫린 구멍과 은색 고리.
class SpiralBindingPainter extends CustomPainter {
  const SpiralBindingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(8, (size.width / 24).floor());
    final step = size.width / n;
    for (var i = 0; i < n; i++) {
      final x = step * (i + 0.5);
      // 종이에 뚫린 구멍.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 10), width: 10, height: 6.5),
        Paint()..color = const Color(0xFF3B3A4A).withValues(alpha: 0.65),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 11.2), width: 9, height: 4.5),
        Paint()..color = const Color(0x33000000),
      );
      // 고리: 살짝 기운 은색 타원 테두리.
      canvas.save();
      canvas.translate(x, 5);
      canvas.rotate(-0.22);
      final ring = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 8.5, height: 26),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        ring.shift(const Offset(1.2, 1.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = const Color(0x33000000),
      );
      canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F5F8), Color(0xFF9CA0AE), Color(0xFFE9EAF0)],
          ).createShader(ring.outerRect),
      );
      canvas.drawLine(
        const Offset(-2.3, -9),
        const Offset(-2.3, 2),
        Paint()
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xAAFFFFFF),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SpiralBindingPainter old) => false;
}
