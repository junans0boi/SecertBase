import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';

import '../moment_format.dart';

/// Crop frame shapes offered in the editor.
enum CropAspect {
  original('원본'),
  square('1:1'),
  portrait('4:5'),
  story('9:16');

  const CropAspect(this.label);
  final String label;

  /// Width / height, or null to follow the (rotated) photo.
  double? get ratio => switch (this) {
    CropAspect.original => null,
    CropAspect.square => 1,
    CropAspect.portrait => 4 / 5,
    CropAspect.story => 9 / 16,
  };
}

/// Text placed on a photo. Position is the center in the output frame
/// (0..1 on both axes); size scales with the frame width so the editor
/// preview and the final JPEG match.
class TextLayer {
  String text;
  Color color;
  bool boxed;
  Offset center;
  double scale;
  double rotation;

  TextLayer({
    required this.text,
    required this.color,
    this.boxed = false,
    this.center = const Offset(.5, .5),
    this.scale = 1,
    this.rotation = 0,
  });

  TextLayer copy() => TextLayer(
    text: text,
    color: color,
    boxed: boxed,
    center: center,
    scale: scale,
    rotation: rotation,
  );
}

/// Font size of a text layer for a frame [width] wide.
double textLayerFontSize(TextLayer t, double width) =>
    (width * 0.072 * t.scale).clamp(6.0, width * 0.6);

/// Colors offered for text.
const textLayerColors = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFF111111),
  Color(0xFFFF5A7A),
  Color(0xFFFFD84D),
  Color(0xFF4DA3FF),
];

/// Photo edits; the empty edit uploads the normalized photo untouched.
class PhotoEdit {
  int quarterTurns = 0;
  CropAspect aspect = CropAspect.original;

  /// Crop in the rotated photo, normalized to 0..1.
  Rect crop = const Rect.fromLTWH(0, 0, 1, 1);
  String filter = 'original';
  final List<TextLayer> texts = [];

  bool get isEmpty =>
      quarterTurns % 4 == 0 &&
      crop == const Rect.fromLTWH(0, 0, 1, 1) &&
      filter == 'original' &&
      texts.isEmpty;

  /// Puts back an earlier [copy] (closing the editor without saving).
  void restore(PhotoEdit from) {
    quarterTurns = from.quarterTurns;
    aspect = from.aspect;
    crop = from.crop;
    filter = from.filter;
    texts
      ..clear()
      ..addAll(from.texts.map((t) => t.copy()));
  }

  PhotoEdit copy() => PhotoEdit()
    ..quarterTurns = quarterTurns
    ..aspect = aspect
    ..crop = crop
    ..filter = filter
    ..texts.addAll(texts.map((t) => t.copy()));
}

/// Kept range of a clip.
class VideoEdit {
  final Duration duration;
  Duration start;
  Duration end;

  VideoEdit(this.duration)
    : start = momentDefaultTrim(duration).start,
      end = momentDefaultTrim(duration).end;

  Duration get length => end - start;
}

/// One picked file and how it is being edited. Lives in memory only (for
/// re-editing from the composer); the outbox stores the final bytes.
class EditorItem {
  final XFile file;
  final String name;
  final bool isVideo;

  /// Original size in bytes (videos are not read into memory).
  final int bytes;

  /// Normalized photo (oriented, 1920px JPEG), the editing source.
  final Uint8List? photo;

  /// Video length, when the device could read it.
  final Duration? duration;

  final PhotoEdit edit = PhotoEdit();
  final VideoEdit? video;

  /// Filmstrip frames, filled lazily by the trim bar.
  List<Uint8List>? frames;

  EditorItem.photo({
    required this.file,
    required this.name,
    required Uint8List this.photo,
  }) : isVideo = false,
       bytes = photo.length,
       duration = null,
       video = null;

  EditorItem.video({
    required this.file,
    required this.name,
    required this.bytes,
    this.duration,
  }) : isVideo = true,
       photo = null,
       video = duration == null ? null : VideoEdit(duration);

  /// Whether this clip must be re-encoded on the device before upload.
  bool get needsConvert =>
      isVideo &&
      momentVideoNeedsConvert(
        bytes: bytes,
        duration: duration,
        start: video?.start ?? Duration.zero,
        end: video?.end,
      );
}

/// The part of a clip the author keeps, in milliseconds of the source.
typedef MomentTrimRange = ({int startMs, int endMs});

const _minSpanMs = 1000;

/// Keeps a dragged range valid: inside the clip, at least a second long and
/// at most [maxMs]. When one end is dragged past the limit, the other end
/// follows it, so the handle under the finger never jumps.
MomentTrimRange clampTrimRange({
  required int startMs,
  required int endMs,
  required int durationMs,
  required int maxMs,
  bool movedStart = false,
}) {
  var start = startMs.clamp(0, durationMs);
  var end = endMs.clamp(0, durationMs);
  final span = durationMs < _minSpanMs ? durationMs : _minSpanMs;
  if (end - start < span) {
    if (movedStart) {
      start = (end - span).clamp(0, durationMs);
      end = start + span;
    } else {
      end = (start + span).clamp(0, durationMs);
      start = end - span;
    }
  }
  if (end - start > maxMs) {
    if (movedStart) {
      end = start + maxMs;
    } else {
      start = end - maxMs;
    }
  }
  return (startMs: start, endMs: end);
}

/// Size of the photo after [quarterTurns].
Size rotatedSize(Size image, int quarterTurns) =>
    quarterTurns.isOdd ? Size(image.height, image.width) : image;

/// Largest centered crop of [ratio] (w/h in pixels) inside a [size] photo,
/// normalized. Null ratio keeps the whole photo.
Rect fitCrop(Size size, double? ratio) {
  if (ratio == null || size.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
  final photoRatio = size.width / size.height;
  if (ratio >= photoRatio) {
    final h = photoRatio / ratio;
    return Rect.fromLTWH(0, (1 - h) / 2, 1, h);
  }
  final w = ratio / photoRatio;
  return Rect.fromLTWH((1 - w) / 2, 0, w, 1);
}

/// Moves a normalized crop by [delta] without leaving the photo.
Rect moveCrop(Rect crop, Offset delta) {
  final left = (crop.left + delta.dx).clamp(0.0, 1 - crop.width);
  final top = (crop.top + delta.dy).clamp(0.0, 1 - crop.height);
  return Rect.fromLTWH(left, top, crop.width, crop.height);
}

/// Scales a normalized crop around its center by [factor], keeping its
/// shape, at least 15% of the photo and inside it.
Rect scaleCrop(Rect crop, double factor) {
  final maxFactor = math.min(1 / crop.width, 1 / crop.height);
  final minFactor = math.max(.15 / crop.width, .15 / crop.height);
  final f = factor.clamp(math.min(minFactor, 1.0), math.max(maxFactor, 1.0));
  final w = crop.width * f;
  final h = crop.height * f;
  final scaled = Rect.fromCenter(center: crop.center, width: w, height: h);
  return moveCrop(scaled, Offset.zero);
}

/// Pixel size of the edited photo, long edge capped at [maxEdge].
Size outputSize(Size image, PhotoEdit edit, {double maxEdge = 1920}) {
  final r = rotatedSize(image, edit.quarterTurns);
  var w = r.width * edit.crop.width;
  var h = r.height * edit.crop.height;
  final long = math.max(w, h);
  if (long > maxEdge) {
    w = w * maxEdge / long;
    h = h * maxEdge / long;
  }
  return Size(w.roundToDouble().clamp(1, 1e5), h.roundToDouble().clamp(1, 1e5));
}

/// Paints the edited photo (rotation, crop, filter, texts) into [size].
/// Used for both the editor preview and the final JPEG.
void paintEditedPhoto(
  Canvas canvas,
  Size size,
  ui.Image image,
  PhotoEdit edit, {
  ColorFilter? filter,
  bool drawTexts = true,
  TextLayer? hidden,
}) {
  final src = Size(image.width.toDouble(), image.height.toDouble());
  final r = rotatedSize(src, edit.quarterTurns);
  final crop = Rect.fromLTWH(
    edit.crop.left * r.width,
    edit.crop.top * r.height,
    edit.crop.width * r.width,
    edit.crop.height * r.height,
  );
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.scale(size.width / crop.width, size.height / crop.height);
  canvas.translate(-crop.left, -crop.top);
  canvas.translate(r.width / 2, r.height / 2);
  canvas.rotate(edit.quarterTurns * math.pi / 2);
  final paint = Paint()
    ..filterQuality = FilterQuality.high
    ..isAntiAlias = true;
  if (filter != null) paint.colorFilter = filter;
  canvas.drawImage(image, Offset(-src.width / 2, -src.height / 2), paint);
  canvas.restore();
  if (!drawTexts) return;
  for (final t in edit.texts) {
    if (identical(t, hidden)) continue;
    paintTextLayer(canvas, size, t);
  }
}

/// Layout of one text layer for a frame of [size].
({TextPainter painter, Rect box}) layoutTextLayer(TextLayer t, Size size) {
  final fontSize = textLayerFontSize(t, size.width);
  final light = t.color.computeLuminance() > .5;
  final textColor = t.boxed
      ? (light ? const Color(0xFF111111) : const Color(0xFFFFFFFF))
      : t.color;
  final painter = TextPainter(
    text: TextSpan(
      text: t.text,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontFamilyFallback: const ['Apple SD Gothic Neo', 'Noto Sans KR'],
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: textColor,
        shadows: t.boxed
            ? null
            : [
                Shadow(
                  color: const Color(0x66000000),
                  blurRadius: fontSize * .15,
                  offset: Offset(0, fontSize * .04),
                ),
              ],
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width * .86);
  final pad = t.boxed ? fontSize * .35 : 0.0;
  final box = Rect.fromCenter(
    center: Offset.zero,
    width: painter.width + pad * 2,
    height: painter.height + pad * 2,
  );
  return (painter: painter, box: box);
}

void paintTextLayer(Canvas canvas, Size size, TextLayer t) {
  final l = layoutTextLayer(t, size);
  canvas.save();
  canvas.translate(t.center.dx * size.width, t.center.dy * size.height);
  canvas.rotate(t.rotation);
  if (t.boxed) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(l.box, Radius.circular(l.box.height * .22)),
      Paint()..color = t.color,
    );
  }
  l.painter.paint(canvas, Offset(-l.painter.width / 2, -l.painter.height / 2));
  canvas.restore();
}

/// Whether [point] (frame pixels) hits text layer [t].
bool hitTextLayer(TextLayer t, Size size, Offset point) {
  final l = layoutTextLayer(t, size);
  final local =
      point - Offset(t.center.dx * size.width, t.center.dy * size.height);
  final c = math.cos(-t.rotation);
  final s = math.sin(-t.rotation);
  final unrotated = Offset(
    local.dx * c - local.dy * s,
    local.dx * s + local.dy * c,
  );
  return l.box.inflate(12).contains(unrotated);
}
