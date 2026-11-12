import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/features/moment_loop/application/moment_loop_controller.dart';
import 'package:secret_base_app/features/moment_loop/data/moment_loop_repository.dart';
import 'package:secret_base_app/features/moment_loop/data/video_shrinker.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment.dart';
import 'package:secret_base_app/screens/archive/moment/moment_composer.dart';
import 'package:secret_base_app/screens/archive/moment/moment_format.dart';
import 'package:secret_base_app/screens/archive/moment/moment_trim_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'moment_loop_test_support.dart';

class _FakeShrinker extends VideoShrinker {
  _FakeShrinker({this.supported = true, this.waitForCancel = false});

  @override
  final bool supported;
  final bool waitForCancel;
  final calls = <String>[];
  final ranges = <(int?, int?)>[];
  final _cancelled = Completer<void>();

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
    calls.add(id);
    ranges.add((startMs, endMs));
    onProgress?.call(0.5);
    if (waitForCancel) {
      await _cancelled.future;
      throw const VideoShrinkException('cancelled');
    }
    return Uint8List(1000);
  }

  @override
  void cancel(String id) {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

XFile _bigVideo() => XFile.fromData(
  Uint8List(momentMaxBytes + 1),
  name: 'big.mov',
  mimeType: 'video/quicktime',
);

// "앨범에서 고르기" on the web opens the album chooser inside the user's tap
// and hands the pending pick to the composer as `startPick`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpComposer(
    WidgetTester tester, {
    required Future<List<XFile>> startPick,
    Future<List<MomentMedia>> Function()? mediaPicker,
    VideoShrinker? videoShrinker,
    Duration? clipLength,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = MockClient(
      (_) async => http.Response(
        jsonEncode({'ok': true, 'posts': []}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final controller = MomentLoopController(
      repository: HttpMomentLoopRepository(
        apiClient: ApiClient(
          baseUrl: 'https://secretbase.example',
          tokenProvider: () => 'test-token',
          client: api,
        ),
      ),
      currentUserId: () => 7,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomentComposerPage(
          controller: controller,
          outbox: testOutbox(api),
          startPick: startPick,
          mediaPicker: mediaPicker,
          videoShrinker: videoShrinker,
          probeDuration: (_) async => clipLength,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('files picked before the composer opened are attached', (
    tester,
  ) async {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    await pumpComposer(
      tester,
      startPick: Future.value([
        XFile.fromData(png, name: 'album.png', mimeType: 'image/png'),
      ]),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment_media_reorder_list')), findsOneWidget);
  });

  testWidgets('a chooser the browser never opened does not lock the buttons', (
    tester,
  ) async {
    final never = Completer<List<XFile>>();
    var picked = 0;
    await pumpComposer(
      tester,
      startPick: never.future,
      mediaPicker: () async {
        picked++;
        return [
          MomentMedia(
            name: 'clip.mp4',
            bytes: Uint8List.fromList([1]),
            isVideo: true,
            clientRequestId: 'clip',
          ),
        ];
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_action_gallery')));
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(find.byKey(const Key('moment_media_reorder_list')), findsOneWidget);
  });

  group('videos over 30MB', () {
    testWidgets('are shrunk on the device and attached', (tester) async {
      final shrinker = _FakeShrinker();
      await pumpComposer(
        tester,
        startPick: Future.value([_bigVideo()]),
        videoShrinker: shrinker,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(shrinker.calls, hasLength(1));
      expect(find.byKey(const Key('moment_shrink_progress')), findsNothing);
      expect(
        find.byKey(const Key('moment_media_reorder_list')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('moment_media_issue')), findsNothing);
    });

    testWidgets('are refused with the 30MB reason when shrinking is '
        'unsupported', (tester) async {
      final shrinker = _FakeShrinker(supported: false);
      await pumpComposer(
        tester,
        startPick: Future.value([_bigVideo()]),
        videoShrinker: shrinker,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(shrinker.calls, isEmpty);
      expect(find.text('30MB 이하만 올릴 수 있어요'), findsOneWidget);
      expect(find.byKey(const Key('moment_media_reorder_list')), findsNothing);
    });

    testWidgets('취소 stops shrinking and attaches nothing', (tester) async {
      final shrinker = _FakeShrinker(waitForCancel: true);
      await pumpComposer(
        tester,
        startPick: Future.value([_bigVideo()]),
        videoShrinker: shrinker,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('moment_shrink_progress')), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('moment_shrink_progress')), findsNothing);
      expect(find.byKey(const Key('moment_media_reorder_list')), findsNothing);
      expect(find.byKey(const Key('moment_media_issue')), findsNothing);
    });
  });

  group('videos over a minute', () {
    XFile longVideo() => XFile.fromData(
      Uint8List(1000),
      name: 'long.mov',
      mimeType: 'video/quicktime',
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('open the trimmer and keep the chosen minute', (tester) async {
      final shrinker = _FakeShrinker();
      await pumpComposer(
        tester,
        startPick: Future.value([longVideo()]),
        videoShrinker: shrinker,
        clipLength: const Duration(seconds: 95),
      );
      await settle(tester);
      expect(find.text('영상 자르기'), findsOneWidget);
      expect(find.text('60.0초'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('moment_trim_done')));
      await settle(tester);
      expect(shrinker.ranges, [(0, 60000)]);
      expect(
        find.byKey(const Key('moment_media_reorder_list')),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the trimmer attaches nothing', (tester) async {
      final shrinker = _FakeShrinker();
      await pumpComposer(
        tester,
        startPick: Future.value([longVideo()]),
        videoShrinker: shrinker,
        clipLength: const Duration(seconds: 95),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('moment_trim_cancel')));
      await settle(tester);
      expect(shrinker.calls, isEmpty);
      expect(find.byKey(const Key('moment_media_reorder_list')), findsNothing);
      expect(find.byKey(const Key('moment_media_issue')), findsNothing);
    });

    testWidgets('are refused when the device cannot cut them', (tester) async {
      await pumpComposer(
        tester,
        startPick: Future.value([longVideo()]),
        videoShrinker: _FakeShrinker(supported: false),
        clipLength: const Duration(seconds: 95),
      );
      await settle(tester);
      expect(find.text('영상 자르기'), findsNothing);
      expect(find.text('영상은 1분까지예요'), findsOneWidget);
    });
  });

  group('clampTrimRange', () {
    MomentTrimRange clamp(int s, int e, {bool movedStart = false}) =>
        clampTrimRange(
          startMs: s,
          endMs: e,
          durationMs: 95000,
          maxMs: 60000,
          movedStart: movedStart,
        );

    test('keeps a valid range', () {
      expect(clamp(5000, 40000), (startMs: 5000, endMs: 40000));
    });

    test('dragging the end past a minute pulls the start along', () {
      expect(clamp(0, 80000), (startMs: 20000, endMs: 80000));
    });

    test('dragging the start back past a minute pulls the end along', () {
      expect(clamp(10000, 90000, movedStart: true), (
        startMs: 10000,
        endMs: 70000,
      ));
    });

    test('never shorter than a second, never outside the clip', () {
      expect(clamp(30000, 30200), (startMs: 30000, endMs: 31000));
      expect(clamp(30000, 30200, movedStart: true), (
        startMs: 29200,
        endMs: 30200,
      ));
      expect(clamp(-500, 99000), (startMs: 35000, endMs: 95000));
    });
  });
}
