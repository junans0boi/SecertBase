import 'dart:typed_data';

import 'video_shrinker.dart';

VideoShrinker createVideoShrinker() => const _UnsupportedVideoShrinker();

class _UnsupportedVideoShrinker extends VideoShrinker {
  const _UnsupportedVideoShrinker();

  @override
  bool get supported => false;

  @override
  Future<Uint8List> shrink({
    required String id,
    required String path,
    void Function(double progress)? onProgress,
    int? startMs,
    int? endMs,
    int maxShortSide = 720,
    int videoBitrate = 2500000,
    int audioBitrate = 128000,
  }) => Future.error(const VideoShrinkException('unsupported'));

  @override
  void cancel(String id) {}
}
