import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'video_shrinker.dart';

/// Android (Media3) and iOS (AVFoundation) share one channel contract:
///
/// MethodChannel `secretbase/video_tools`
///  - `convert` {id, path, startMs?, endMs?, maxShortSide, videoBitrate,
///    audioBitrate} → path of a new .mp4 in the app cache.
///  - `cancel` {id} → the pending `convert` fails with `cancelled`.
///  - `supported` → whether the platform can convert at all.
/// Error codes: `cancelled`, `unsupported`, `failed`.
///
/// EventChannel `secretbase/video_tools/progress`: {id, progress 0..1}.
VideoShrinker createVideoShrinker() {
  if (Platform.isAndroid || Platform.isIOS) return ChannelVideoShrinker();
  return const _UnsupportedVideoShrinker();
}

class ChannelVideoShrinker extends VideoShrinker {
  ChannelVideoShrinker({
    MethodChannel? methods,
    EventChannel? progress,
    Future<Uint8List> Function(String path)? readFile,
    Future<void> Function(String path)? deleteFile,
  }) : _methods = methods ?? const MethodChannel('secretbase/video_tools'),
       _progress =
           progress ?? const EventChannel('secretbase/video_tools/progress'),
       _readFile = readFile ?? ((path) => File(path).readAsBytes()),
       _deleteFile =
           deleteFile ??
           ((path) async {
             try {
               await File(path).delete();
             } catch (_) {}
           });

  final MethodChannel _methods;
  final EventChannel _progress;
  final Future<Uint8List> Function(String path) _readFile;
  final Future<void> Function(String path) _deleteFile;
  Stream<dynamic>? _events;

  @override
  bool get supported => true;

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
    StreamSubscription<dynamic>? subscription;
    if (onProgress != null) {
      try {
        _events ??= _progress.receiveBroadcastStream();
        subscription = _events!.listen((event) {
          if (event is Map && event['id'] == id) {
            final value = event['progress'];
            if (value is num) onProgress(value.toDouble());
          }
        }, onError: (_) {});
      } catch (_) {
        // Progress is cosmetic; the conversion still runs without it.
      }
    }
    try {
      final output = await _methods.invokeMethod<String>('convert', {
        'id': id,
        'path': path,
        'startMs': ?startMs,
        'endMs': ?endMs,
        'maxShortSide': maxShortSide,
        'videoBitrate': videoBitrate,
        'audioBitrate': audioBitrate,
      });
      if (output == null || output.isEmpty) {
        throw const VideoShrinkException('failed', 'no output path');
      }
      try {
        return await _readFile(output);
      } finally {
        await _deleteFile(output);
      }
    } on PlatformException catch (e) {
      final code = switch (e.code) {
        'cancelled' => 'cancelled',
        'unsupported' => 'unsupported',
        _ => 'failed',
      };
      throw VideoShrinkException(code, e.message);
    } on MissingPluginException {
      throw const VideoShrinkException('unsupported');
    } finally {
      await subscription?.cancel();
    }
  }

  @override
  void cancel(String id) {
    unawaited(
      _methods
          .invokeMethod<void>('cancel', {'id': id})
          .catchError((Object _) {}),
    );
  }
}

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
