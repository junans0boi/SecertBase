import 'dart:typed_data';

import 'video_frames_io.dart'
    if (dart.library.js_interop) 'video_frames_web.dart'
    as impl;

/// [count] evenly spaced JPEG frames of a picked clip, [height] px tall, for
/// the editor's trim filmstrip. Empty when the platform cannot read frames.
/// [path] is the picked file's path (a `blob:` URL on the web).
Future<List<Uint8List>> videoFrames(
  String path, {
  required int count,
  required Duration duration,
  int height = 112,
}) => impl.videoFrames(path, count: count, duration: duration, height: height);
