import 'dart:typed_data';

import 'video_shrinker_io.dart'
    if (dart.library.js_interop) 'video_shrinker_web.dart'
    as impl;

/// Why a shrink did not produce a file. Codes match the Android
/// `secretbase/video_tools` channel: `cancelled`, `unsupported`, `failed`.
class VideoShrinkException implements Exception {
  const VideoShrinkException(this.code, [this.detail]);

  final String code;
  final String? detail;

  bool get cancelled => code == 'cancelled';

  @override
  String toString() =>
      'VideoShrinkException($code${detail == null ? '' : ': $detail'})';
}

/// Re-encodes a picked video to a 720p H.264/AAC MP4 (~2.5Mbps) on the
/// device, so clips over the 30MB upload limit can still be posted.
abstract class VideoShrinker {
  const VideoShrinker();

  /// Whether this platform can shrink videos at all.
  bool get supported;

  /// [path] is the picked file's path (a `blob:` URL on the web).
  /// [onProgress] gets 0..1. Throws [VideoShrinkException].
  Future<Uint8List> shrink({
    required String id,
    required String path,
    void Function(double progress)? onProgress,
    int? startMs,
    int? endMs,
    int maxShortSide = 720,
    int videoBitrate = 2500000,
    int audioBitrate = 128000,
  });

  /// Stops [id]; its [shrink] then throws a `cancelled` exception.
  void cancel(String id);
}

/// The browser shrinker on the web (`web/js/moment_video.js`); on Android and
/// iOS the `secretbase/video_tools` platform channel; unsupported elsewhere.
VideoShrinker createVideoShrinker() => impl.createVideoShrinker();
