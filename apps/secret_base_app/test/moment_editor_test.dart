import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:secret_base_app/features/moment_loop/data/video_shrinker.dart';
import 'package:secret_base_app/screens/archive/moment/editor/editor_item.dart';
import 'package:secret_base_app/screens/archive/moment/editor/moment_editor_page.dart';
import 'package:secret_base_app/screens/archive/moment/editor/photo_filters.dart';
import 'package:secret_base_app/screens/archive/moment/editor/photo_render.dart';

class _FakeShrinker extends VideoShrinker {
  _FakeShrinker({this.supported = true});

  @override
  final bool supported;
  final calls = <({int? startMs, int? endMs})>[];

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
    calls.add((startMs: startMs, endMs: endMs));
    if (!supported) throw const VideoShrinkException('unsupported');
    onProgress?.call(.5);
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  void cancel(String id) {}
}

Uint8List _jpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 80, 40));
  return Uint8List.fromList(img.encodeJpg(image));
}

EditorItem _photo([String name = 'a.jpg']) =>
    EditorItem.photo(file: XFile(name), name: name, photo: _jpeg(32, 24));

EditorItem _video({
  Duration duration = const Duration(seconds: 90),
  int bytes = 12 << 20,
}) => EditorItem.video(
  file: XFile('clip.mov'),
  name: 'clip.mov',
  bytes: bytes,
  duration: duration,
);

/// Opens the editor from a button and returns a getter for its result.
Future<EditorOutcome? Function()> _openEditor(
  WidgetTester tester,
  List<EditorItem> items,
  VideoShrinker shrinker,
) async {
  EditorOutcome? outcome;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            outcome = await MomentEditorPage.open(
              context,
              items,
              shrinker: shrinker,
              videoPreview: false,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  // Let the photos decode (real async work; a spinner shows until then).
  for (
    var i = 0;
    i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  return () => outcome;
}

void main() {
  group('crop math', () {
    test('fits the largest centered frame of a shape', () {
      expect(
        fitCrop(const Size(400, 300), null),
        const Rect.fromLTWH(0, 0, 1, 1),
      );
      final square = fitCrop(const Size(400, 300), 1);
      expect(square.height, 1);
      expect(square.width, closeTo(.75, 1e-9));
      expect(square.left, closeTo(.125, 1e-9));
      final story = fitCrop(const Size(300, 400), 9 / 16);
      expect(story.height, 1);
      expect(story.width * 300 / 400, closeTo(9 / 16, 1e-9));
    });

    test('moving and scaling stay inside the photo', () {
      const crop = Rect.fromLTWH(.25, .25, .5, .5);
      expect(
        moveCrop(crop, const Offset(.9, -.9)),
        const Rect.fromLTWH(.5, 0, .5, .5),
      );
      final bigger = scaleCrop(crop, 3);
      expect(bigger.width, 1);
      expect(bigger.height, 1);
      final smaller = scaleCrop(crop, .01);
      expect(smaller.width, closeTo(.15, 1e-9));
    });

    test('output follows rotation and crop, long edge capped', () {
      final edit = PhotoEdit()..quarterTurns = 1;
      expect(outputSize(const Size(4000, 3000), edit), const Size(1440, 1920));
      edit.crop = const Rect.fromLTWH(0, 0, .5, .5);
      expect(outputSize(const Size(400, 300), edit), const Size(150, 200));
    });

    test('six filters with full color matrices', () {
      expect(photoFilters.map((f) => f.label), [
        '원본',
        '따뜻하게',
        '선명하게',
        '필름',
        '흑백',
        '빈티지',
      ]);
      for (final f in photoFilters.skip(1)) {
        expect(f.matrix, hasLength(20), reason: f.id);
      }
    });
  });

  testWidgets('rendering bakes rotation and crop into the JPEG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final image = await decodeEditorPhoto(_jpeg(40, 20));
      final edit = PhotoEdit()
        ..quarterTurns = 1
        ..filter = 'mono'
        ..texts.add(TextLayer(text: '안녕', color: const Color(0xFFFFFFFF)));
      final out = img.decodeJpg(await renderEditedPhoto(image, edit))!;
      expect(out.width, 20);
      expect(out.height, 40);
      edit.crop = const Rect.fromLTWH(0, .5, 1, .5);
      final cropped = img.decodeJpg(await renderEditedPhoto(image, edit))!;
      expect(cropped.width, 20);
      expect(cropped.height, 20);
      image.dispose();
    });
  });

  testWidgets('long clip starts trimmed to its first minute and converts', (
    tester,
  ) async {
    final tools = _FakeShrinker();
    final items = [_photo(), _video()];
    final result = await _openEditor(tester, items, tools);

    expect(find.text('편집 1/2'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('편집 2/2'), findsOneWidget);
    expect(find.byKey(const Key('video_trim_hint')), findsOneWidget);
    expect(find.text('0:00 – 1:00 · 60초'), findsOneWidget);

    // Dragging the end handle back shortens the range.
    await tester.drag(
      find.byKey(const Key('video_trim_end')),
      const Offset(-60, 0),
    );
    await tester.pumpAndSettle();
    expect(items[1].video!.length, lessThan(const Duration(seconds: 60)));

    // Sliding the range right keeps its length and stays within the clip.
    final len = items[1].video!.length;
    await tester.drag(
      find.byKey(const Key('video_trim_range')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(items[1].video!.length, len);
    expect(items[1].video!.end, const Duration(seconds: 90));

    await tester.tap(find.byKey(const Key('moment_editor_next')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    final outcome = result()!;
    expect(outcome.issue, isNull);
    expect(outcome.media.map((m) => m.name), ['a.jpg', 'clip.mp4']);
    expect(tools.calls.single.endMs, 90000);
    expect(tools.calls.single.startMs, 90000 - len.inMilliseconds);
  });

  testWidgets(
    'short small clips go up untouched, unsupported shrink is skipped',
    (tester) async {
      final tools = _FakeShrinker(supported: false);
      final items = [
        _photo(),
        _video(duration: const Duration(seconds: 20), bytes: 50 << 20),
      ];
      final result = await _openEditor(tester, items, tools);
      await tester.tap(find.byKey(const Key('moment_editor_next')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final outcome = result()!;
      expect(outcome.media.map((m) => m.name), ['a.jpg']);
      expect(outcome.issue, contains('줄일 수 없어요'));
      expect(tools.calls, hasLength(1));
    },
  );

  testWidgets('text can be added, and closing drops unsaved edits', (
    tester,
  ) async {
    final item = _photo();
    final result = await _openEditor(tester, [item], _FakeShrinker());
    expect(find.text('편집'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor_tool_text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('text_layer_field')),
      '우리 첫 여행',
    );
    await tester.tap(find.byKey(const Key('text_layer_color_2')));
    await tester.tap(find.byKey(const Key('text_layer_done')));
    await tester.pumpAndSettle();
    expect(item.edit.texts.single.text, '우리 첫 여행');

    await tester.tap(find.byKey(const Key('editor_tool_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo_filter_mono')));
    await tester.pumpAndSettle();
    expect(item.edit.filter, 'mono');

    await tester.tap(find.byKey(const Key('moment_editor_close')));
    await tester.pumpAndSettle();
    expect(result(), isNull);
    expect(item.edit.isEmpty, isTrue);
  });

  testWidgets('crop shapes and rotation update the edit', (tester) async {
    final item = _photo();
    await _openEditor(tester, [item], _FakeShrinker());
    await tester.tap(find.byKey(const Key('editor_tool_rotate')));
    await tester.pumpAndSettle();
    expect(item.edit.quarterTurns, 1);
    await tester.tap(find.byKey(const Key('editor_tool_crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crop_aspect_square')));
    await tester.pumpAndSettle();
    // Rotated 24x32 photo → square crop is the full width, 75% height.
    expect(item.edit.crop.width, closeTo(1, 1e-9));
    expect(item.edit.crop.height, closeTo(.75, 1e-9));
    await tester.tap(find.byKey(const Key('editor_tool_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editor_tool_crop')), findsOneWidget);
  });
}
