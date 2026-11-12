import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import 'editor_item.dart';
import 'photo_filters.dart';

/// Decodes a (normalized) photo for the editor canvas.
Future<ui.Image> decodeEditorPhoto(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// Bakes [edit] into a JPEG (85%, long edge 1920) — same output rules as
/// `compressMomentImage`, so edited and untouched photos look alike.
Future<Uint8List> renderEditedPhoto(ui.Image image, PhotoEdit edit) async {
  final size = outputSize(
    ui.Size(image.width.toDouble(), image.height.toDouble()),
    edit,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paintEditedPhoto(
    canvas,
    size,
    image,
    edit,
    filter: photoFilterById(edit.filter).colorFilter,
  );
  final picture = recorder.endRecording();
  final w = size.width.round();
  final h = size.height.round();
  final rendered = await picture.toImage(w, h);
  picture.dispose();
  try {
    final data = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('render failed');
    final out = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: data.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 85));
  } finally {
    rendered.dispose();
  }
}
