import 'dart:js_interop';
import 'dart:typed_data';

@JS('secretBaseVideo')
external _Api? get _api;

extension type _Api._(JSObject _) implements JSObject {
  external JSPromise<JSArray<JSUint8Array>> frames(
    JSString url,
    JSNumber count,
    JSNumber durationSec,
    JSNumber height,
  );
}

Future<List<Uint8List>> videoFrames(
  String path, {
  required int count,
  required Duration duration,
  int height = 112,
}) async {
  final api = _api;
  if (api == null || duration <= Duration.zero) return const [];
  try {
    final list = await api
        .frames(
          path.toJS,
          count.toJS,
          (duration.inMilliseconds / 1000).toJS,
          height.toJS,
        )
        .toDart;
    return [for (final f in list.toDart) f.toDart];
  } catch (_) {
    return const [];
  }
}
