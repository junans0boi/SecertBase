import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'video_shrinker.dart';

VideoShrinker createVideoShrinker() => const _BrowserVideoShrinker();

/// `window.secretBaseVideo` from web/js/moment_video.js.
extension type _VideoApi._(JSObject _) implements JSObject {
  external JSBoolean supported();
  external JSPromise<JSUint8Array> shrink(
    JSString id,
    JSString src,
    JSObject options,
    JSFunction onProgress,
  );
  external void cancel(JSString id);
}

_VideoApi? get _api {
  if (!globalContext.has('secretBaseVideo')) return null;
  final value = globalContext['secretBaseVideo'];
  return value == null ? null : value as _VideoApi;
}

class _BrowserVideoShrinker extends VideoShrinker {
  const _BrowserVideoShrinker();

  @override
  bool get supported {
    try {
      return _api?.supported().toDart ?? false;
    } catch (_) {
      return false;
    }
  }

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
  }) async {
    final api = _api;
    if (api == null) throw const VideoShrinkException('unsupported');
    final options = <String, Object?>{
      'startMs': startMs,
      'endMs': endMs,
      'maxShortSide': maxShortSide,
      'videoBitrate': videoBitrate,
      'audioBitrate': audioBitrate,
    }..removeWhere((_, v) => v == null);
    void progress(JSNumber value) => onProgress?.call(value.toDartDouble);
    try {
      final bytes = await api
          .shrink(
            id.toJS,
            path.toJS,
            options.jsify()! as JSObject,
            progress.toJS,
          )
          .toDart;
      return bytes.toDart;
    } catch (error) {
      final message = _messageOf(error);
      if (message.startsWith('cancelled')) {
        throw const VideoShrinkException('cancelled');
      }
      if (message.startsWith('unsupported')) {
        throw const VideoShrinkException('unsupported');
      }
      throw VideoShrinkException('failed', message);
    }
  }

  @override
  void cancel(String id) {
    try {
      _api?.cancel(id.toJS);
    } catch (_) {}
  }
}

String _messageOf(Object error) {
  try {
    if (error.isA<JSObject>()) {
      final message = (error as JSObject)['message'];
      if (message != null && message.isA<JSString>()) {
        return (message as JSString).toDart;
      }
    }
  } catch (_) {}
  final text = error.toString();
  // dart2js wraps JS errors as "Error: <message>".
  return text.startsWith('Error: ') ? text.substring(7) : text;
}
