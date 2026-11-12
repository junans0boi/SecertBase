import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/features/moment_loop/data/video_shrinker.dart';
import 'package:secret_base_app/features/moment_loop/data/video_shrinker_io.dart';

// Android (Media3) and iOS (AVFoundation) answer the same channel contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/video_tools');
  const progress = EventChannel('test/video_tools/progress');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(progress, null);
  });

  ChannelVideoShrinker shrinker({List<String>? deleted}) =>
      ChannelVideoShrinker(
        methods: methods,
        progress: progress,
        readFile: (path) async => Uint8List.fromList(path.codeUnits),
        deleteFile: (path) async => deleted?.add(path),
      );

  test('convert sends the contract and returns the output bytes', () async {
    MethodCall? call;
    messenger.setMockMethodCallHandler(methods, (c) async {
      call = c;
      return '/cache/out.mp4';
    });
    final deleted = <String>[];
    final bytes = await shrinker(
      deleted: deleted,
    ).shrink(id: 'job1', path: '/picked/in.mov', startMs: 1000, endMs: 31000);
    expect(String.fromCharCodes(bytes), '/cache/out.mp4');
    expect(deleted, ['/cache/out.mp4']);
    expect(call!.method, 'convert');
    expect(call!.arguments, {
      'id': 'job1',
      'path': '/picked/in.mov',
      'startMs': 1000,
      'endMs': 31000,
      'maxShortSide': 720,
      'videoBitrate': 2500000,
      'audioBitrate': 128000,
    });
  });

  test('untrimmed calls leave startMs and endMs out', () async {
    MethodCall? call;
    messenger.setMockMethodCallHandler(methods, (c) async {
      call = c;
      return '/cache/out.mp4';
    });
    await shrinker().shrink(id: 'job2', path: '/picked/in.mov');
    final args = call!.arguments as Map;
    expect(args.containsKey('startMs'), isFalse);
    expect(args.containsKey('endMs'), isFalse);
  });

  test('progress events for this job reach onProgress', () async {
    messenger.setMockStreamHandler(
      progress,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success({'id': 'other', 'progress': 0.9});
          sink.success({'id': 'job3', 'progress': 0.25});
          sink.success({'id': 'job3', 'progress': 1.0});
        },
      ),
    );
    messenger.setMockMethodCallHandler(methods, (c) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return '/cache/out.mp4';
    });
    final seen = <double>[];
    await shrinker().shrink(
      id: 'job3',
      path: '/picked/in.mov',
      onProgress: seen.add,
    );
    expect(seen, [0.25, 1.0]);
  });

  test('platform error codes become VideoShrinkException codes', () async {
    for (final entry in {
      'cancelled': 'cancelled',
      'unsupported': 'unsupported',
      'failed': 'failed',
      'ERROR_CODE_DECODER_INIT_FAILED': 'failed',
    }.entries) {
      messenger.setMockMethodCallHandler(
        methods,
        (_) async => throw PlatformException(code: entry.key, message: 'x'),
      );
      await expectLater(
        shrinker().shrink(id: 'e', path: '/p'),
        throwsA(
          isA<VideoShrinkException>().having(
            (e) => e.code,
            'code',
            entry.value,
          ),
        ),
      );
    }
  });

  test('a platform without the plugin reports unsupported', () async {
    await expectLater(
      shrinker().shrink(id: 'm', path: '/p'),
      throwsA(
        isA<VideoShrinkException>().having(
          (e) => e.code,
          'code',
          'unsupported',
        ),
      ),
    );
  });

  test('cancel forwards the id', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methods, (c) async {
      calls.add(c);
      return null;
    });
    shrinker().cancel('job4');
    await Future<void>.delayed(Duration.zero);
    expect(calls.single.method, 'cancel');
    expect(calls.single.arguments, {'id': 'job4'});
  });
}
