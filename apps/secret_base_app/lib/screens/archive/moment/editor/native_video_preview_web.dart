import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';

import 'native_video_preview.dart';

const available = true;

double _sec(Duration d) => d.inMilliseconds / 1000;

Widget build(String url, NativeVideoController controller) {
  return HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (Object element) {
      final video = element as JSObject;
      video.callMethod('setAttribute'.toJS, 'playsinline'.toJS, ''.toJS);
      video['playsInline'] = true.toJS;
      video['controls'] = false.toJS;
      video['preload'] = 'metadata'.toJS;
      video['src'] = url.toJS;
      final style = video['style'] as JSObject;
      style['width'] = '100%'.toJS;
      style['height'] = '100%'.toJS;
      style['objectFit'] = 'contain'.toJS;
      style['backgroundColor'] = 'black'.toJS;

      void seek() {
        try {
          video['currentTime'] = _sec(controller.start).toJS;
        } catch (_) {}
      }

      // Show the kept range's first frame, and loop inside the range.
      video.callMethod(
        'addEventListener'.toJS,
        'loadedmetadata'.toJS,
        ((JSAny? _) => seek()).toJS,
      );
      video.callMethod(
        'addEventListener'.toJS,
        'timeupdate'.toJS,
        ((JSAny? _) {
          final t = (video['currentTime'] as JSNumber?)?.toDartDouble ?? 0;
          final start = _sec(controller.start);
          final end = _sec(controller.end);
          if (end > start && (t >= end - 0.05 || t < start - 0.5)) seek();
        }).toJS,
      );
      // Tap toggles play/pause; the tap is the user gesture iOS needs.
      video.callMethod(
        'addEventListener'.toJS,
        'click'.toJS,
        ((JSAny? _) {
          final paused = (video['paused'] as JSBoolean?)?.toDart ?? true;
          try {
            if (paused) {
              final t = (video['currentTime'] as JSNumber?)?.toDartDouble ?? 0;
              if (t < _sec(controller.start) || t >= _sec(controller.end)) {
                seek();
              }
              video.callMethod('play'.toJS);
            } else {
              video.callMethod('pause'.toJS);
            }
          } catch (_) {}
        }).toJS,
      );
      for (final (event, paused) in [('play', false), ('pause', true)]) {
        video.callMethod(
          'addEventListener'.toJS,
          event.toJS,
          ((JSAny? _) => controller.paused.value = paused).toJS,
        );
      }
      controller.attach(
        seek: seek,
        pause: () {
          try {
            video.callMethod('pause'.toJS);
          } catch (_) {}
        },
      );
    },
  );
}
