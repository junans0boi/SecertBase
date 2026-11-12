import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../v2/v2.dart';
import 'editor_item.dart';
import 'photo_filters.dart';

/// What the photo canvas is doing right now.
enum PhotoTool { none, crop, filter }

/// Photo canvas of the editor: shows the edited photo, lets the user move
/// the crop frame (crop tool) or move / pinch / rotate texts (otherwise).
class PhotoStage extends StatefulWidget {
  const PhotoStage({
    super.key,
    required this.image,
    required this.edit,
    required this.tool,
    required this.onChanged,
    required this.onEditText,
  });

  final ui.Image image;
  final PhotoEdit edit;
  final PhotoTool tool;
  final VoidCallback onChanged;
  final void Function(TextLayer layer) onEditText;

  @override
  State<PhotoStage> createState() => _PhotoStageState();
}

class _PhotoStageState extends State<PhotoStage> {
  // Crop gesture.
  Rect? _cropStart;
  Offset _focusStart = Offset.zero;

  // Text gesture.
  TextLayer? _active;
  Offset _centerStart = Offset.zero;
  double _scaleStart = 1;
  double _rotationStart = 0;
  bool _overTrash = false;

  PhotoEdit get _edit => widget.edit;

  Size get _photoSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  /// Display size of [content] fitted into [box].
  Size _fit(Size content, Size box) {
    if (content.isEmpty) return box;
    final s = (box.width / content.width).clamp(
      0.0,
      box.height / content.height,
    );
    return Size(content.width * s, content.height * s);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final box = Size(c.maxWidth, c.maxHeight);
        return widget.tool == PhotoTool.crop ? _cropView(box) : _photoView(box);
      },
    );
  }

  // ── Crop ─────────────────────────────────────────────────────────────────

  Widget _cropView(Size box) {
    final rotated = rotatedSize(_photoSize, _edit.quarterTurns);
    final shown = _fit(rotated, Size(box.width - 32, box.height - 32));
    final whole = PhotoEdit()
      ..quarterTurns = _edit.quarterTurns
      ..filter = _edit.filter;
    final crop = _edit.crop;
    final frame = Rect.fromLTWH(
      crop.left * shown.width,
      crop.top * shown.height,
      crop.width * shown.width,
      crop.height * shown.height,
    );
    return Center(
      child: SizedBox.fromSize(
        size: shown,
        child: GestureDetector(
          key: const Key('photo_crop_area'),
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) {
            _cropStart = _edit.crop;
            _focusStart = d.localFocalPoint;
          },
          onScaleUpdate: (d) {
            final start = _cropStart;
            if (start == null) return;
            var next = d.pointerCount > 1
                ? scaleCrop(start, 1 / d.scale)
                : start;
            final delta = d.localFocalPoint - _focusStart;
            next = moveCrop(
              next,
              Offset(delta.dx / shown.width, delta.dy / shown.height),
            );
            setState(() => _edit.crop = next);
            widget.onChanged();
          },
          onScaleEnd: (_) => _cropStart = null,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PhotoPainter(
                    widget.image,
                    whole,
                    photoFilterById(_edit.filter).colorFilter,
                    drawTexts: false,
                  ),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: _CropShade(frame))),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo + texts ────────────────────────────────────────────────────────

  Widget _photoView(Size box) {
    final out = outputSize(_photoSize, _edit);
    final shown = _fit(out, box);
    final filter = photoFilterById(_edit.filter).colorFilter;
    final textsLocked = widget.tool != PhotoTool.none;
    return Center(
      child: SizedBox.fromSize(
        size: shown,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('photo_text_area'),
                behavior: HitTestBehavior.opaque,
                onTapUp: textsLocked
                    ? null
                    : (d) {
                        final hit = _hit(shown, d.localPosition);
                        if (hit != null) widget.onEditText(hit);
                      },
                onScaleStart: textsLocked
                    ? null
                    : (d) {
                        final hit = _hit(shown, d.localFocalPoint);
                        if (hit == null) return;
                        _edit.texts
                          ..remove(hit)
                          ..add(hit);
                        setState(() {
                          _active = hit;
                          _centerStart = hit.center;
                          _scaleStart = hit.scale;
                          _rotationStart = hit.rotation;
                          _focusStart = d.localFocalPoint;
                        });
                      },
                onScaleUpdate: textsLocked
                    ? null
                    : (d) {
                        final t = _active;
                        if (t == null) return;
                        final delta = d.localFocalPoint - _focusStart;
                        setState(() {
                          t.center = Offset(
                            (_centerStart.dx + delta.dx / shown.width).clamp(
                              0,
                              1,
                            ),
                            (_centerStart.dy + delta.dy / shown.height).clamp(
                              0,
                              1,
                            ),
                          );
                          if (d.pointerCount > 1) {
                            t.scale = (_scaleStart * d.scale).clamp(.4, 5.0);
                            t.rotation = _rotationStart + d.rotation;
                          }
                          _overTrash = _trashRect(
                            shown,
                          ).contains(d.localFocalPoint);
                        });
                      },
                onScaleEnd: textsLocked
                    ? null
                    : (_) {
                        final t = _active;
                        if (t == null) return;
                        setState(() {
                          if (_overTrash) _edit.texts.remove(t);
                          _active = null;
                          _overTrash = false;
                        });
                        widget.onChanged();
                      },
                child: CustomPaint(
                  painter: _PhotoPainter(widget.image, _edit, filter),
                ),
              ),
            ),
            if (_active != null)
              Positioned.fromRect(
                rect: _trashRect(shown),
                child: IgnorePointer(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: _overTrash ? 1.2 : 1,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _overTrash
                            ? V2Colors.rose600
                            : Colors.black.withValues(alpha: .55),
                        border: Border.all(color: Colors.white70, width: 1.5),
                      ),
                      child: const Icon(V2Icons.delete, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Rect _trashRect(Size shown) => Rect.fromCenter(
    center: Offset(shown.width / 2, shown.height - 40),
    width: 52,
    height: 52,
  );

  TextLayer? _hit(Size shown, Offset point) {
    for (final t in _edit.texts.reversed) {
      if (hitTextLayer(t, shown, point)) return t;
    }
    return null;
  }
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.image, this.edit, this.filter, {this.drawTexts = true});

  final ui.Image image;
  final PhotoEdit edit;
  final ColorFilter? filter;
  final bool drawTexts;

  @override
  void paint(Canvas canvas, Size size) => paintEditedPhoto(
    canvas,
    size,
    image,
    edit,
    filter: filter,
    drawTexts: drawTexts,
  );

  // The edit is mutated in place; repaint whenever the stage rebuilds.
  @override
  bool shouldRepaint(_PhotoPainter old) => true;
}

/// Dims everything outside the crop frame and draws a thirds grid.
class _CropShade extends CustomPainter {
  _CropShade(this.frame);
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(shade, Paint()..color = const Color(0x99000000));
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(frame, line);
    final thin = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = frame.left + frame.width * i / 3;
      final y = frame.top + frame.height * i / 3;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), thin);
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), thin);
    }
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const k = 18.0;
    for (final c in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
    ]) {
      final dx = c.dx == frame.left ? k : -k;
      final dy = c.dy == frame.top ? k : -k;
      canvas.drawLine(c, c + Offset(dx, 0), corner);
      canvas.drawLine(c, c + Offset(0, dy), corner);
    }
  }

  @override
  bool shouldRepaint(_CropShade old) => old.frame != frame;
}

/// Small preview of the photo with [filter] for the 필터 row.
class FilterThumb extends StatelessWidget {
  const FilterThumb({
    super.key,
    required this.image,
    required this.edit,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final ui.Image image;
  final PhotoEdit edit;
  final PhotoFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final square = PhotoEdit()
      ..quarterTurns = edit.quarterTurns
      ..crop = fitCrop(
        rotatedSize(
          Size(image.width.toDouble(), image.height.toDouble()),
          edit.quarterTurns,
        ),
        1,
      );
    return Semantics(
      button: true,
      selected: selected,
      label: '필터 ${filter.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: _PhotoPainter(
                      image,
                      square,
                      filter.colorFilter,
                      drawTexts: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  filter.label,
                  style: V2Text.cap.copyWith(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : null,
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
