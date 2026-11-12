import 'package:flutter/widgets.dart';

import 'native_video_preview_stub.dart'
    if (dart.library.js_interop) 'native_video_preview_web.dart'
    as impl;

/// Kept range for the browser's own video player, plus hooks the player
/// registers so the editor can jump to the range start or pause it.
class NativeVideoController {
  Duration start = Duration.zero;
  Duration end = Duration.zero;

  /// True while the video is not playing (the stage shows a play icon).
  final paused = ValueNotifier<bool>(true);
  void Function()? _seek;
  void Function()? _pause;

  void attach({required void Function() seek, required void Function() pause}) {
    _seek = seek;
    _pause = pause;
  }

  void setRange(Duration start, Duration end) {
    this.start = start;
    this.end = end;
    _seek?.call();
  }

  void pause() => _pause?.call();

  void dispose() => paused.dispose();
}

/// Whether the browser's own `<video>` player is used (web only). Mobile
/// browsers (iOS Safari above all) only load a video after a tap on a real
/// video element, so the editor shows one with native play/pause controls.
const nativeVideoPreviewAvailable = impl.available;

Widget nativeVideoPreview({
  required String url,
  required NativeVideoController controller,
}) => impl.build(url, controller);
