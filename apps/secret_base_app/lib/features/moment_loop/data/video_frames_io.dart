import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

Future<List<Uint8List>> videoFrames(
  String path, {
  required int count,
  required Duration duration,
  int height = 112,
}) async {
  if (duration <= Duration.zero) return const [];
  final out = <Uint8List>[];
  final step = duration.inMilliseconds / count;
  for (var i = 0; i < count; i++) {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        timeMs: (i * step + step / 2).round(),
        maxHeight: height,
        quality: 60,
      );
      if (bytes != null) out.add(bytes);
    } catch (_) {
      return out;
    }
  }
  return out;
}
