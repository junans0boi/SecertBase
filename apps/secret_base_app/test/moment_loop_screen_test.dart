import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/features/moment_loop/application/upload_outbox.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment.dart';
import 'package:secret_base_app/screens/archive/moment/moment_format.dart';
import 'package:secret_base_app/screens/archive/moment/moment_sheets.dart';
import 'package:secret_base_app/screens/archive/moment_loop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'moment_loop_test_support.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<void> _pump(
  WidgetTester tester,
  http.Client api, {
  bool openComposer = false,
  Future<List<MomentMedia>> Function()? mediaPicker,
  UploadOutbox? outbox,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MomentLoopScreen(
        client: api,
        baseUrl: 'https://secretbase.example',
        userId: 7,
        outbox: outbox ?? testOutbox(api),
        openComposer: openComposer,
        mediaPicker: mediaPicker,
      ),
    ),
  );
  // The skeleton shimmer never settles: advance time instead.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _today() => DateTime.now().toIso8601String().substring(0, 10);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('save closes the composer within 500ms while upload is pending', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final api = MockClient((request) async {
      if (request.method == 'POST') return pending.future;
      return _json({'ok': true, 'posts': [], 'pins': []});
    });
    final queue = testOutbox(api);
    await _pump(tester, api, outbox: queue);
    await tester.tap(find.byKey(const Key('moment_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '기록 보존');
    await tester.tap(find.byKey(const Key('moment_save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.text('새 순간'), findsNothing);
    expect(queue.drafts.single.caption, '기록 보존');
    pending.complete(
      _json({
        'ok': true,
        'post': {'id': 10, 'user_id': 7},
      }, 201),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(queue.drafts, isEmpty);
  });

  testWidgets('empty 기록 opens on the "내 순간 올리기" page', (tester) async {
    final api = MockClient((_) async => _json({'ok': true, 'posts': []}));
    await _pump(tester, api);
    expect(find.text('기록'), findsWidgets);
    expect(find.byKey(const Key('moment_today_cta')), findsOneWidget);
    expect(find.text('내 순간 올리기'), findsOneWidget);
    expect(find.text('카메라로 찍거나 앨범에서 골라요'), findsOneWidget);
    expect(find.byTooltip('순간 남기기'), findsOneWidget);
  });

  testWidgets(
    'the upload button asks camera or album, album opens the picker',
    (tester) async {
      var picked = 0;
      final api = MockClient((_) async => _json({'ok': true, 'posts': []}));
      await _pump(
        tester,
        api,
        mediaPicker: () async {
          picked++;
          return const [];
        },
      );
      await tester.tap(find.byKey(const Key('moment_upload_cta')));
      await tester.pumpAndSettle();
      expect(find.text('카메라로 찍기'), findsOneWidget);
      expect(find.text('앨범에서 고르기'), findsOneWidget);
      await tester.tap(find.byKey(const Key('moment_source_gallery')));
      await tester.pumpAndSettle();
      expect(find.text('새 순간'), findsOneWidget);
      expect(picked, 1);
    },
  );

  testWidgets('409 active_couple_required is shown as unpaired, not empty', (
    tester,
  ) async {
    final api = MockClient(
      (_) async => _json({'ok': false, 'code': 'active_couple_required'}, 409),
    );
    await _pump(tester, api);
    expect(find.text('아직 연결되지 않았어요'), findsOneWidget);
    expect(find.text('이번 주 첫 순간을 남겨 보세요'), findsNothing);
  });

  testWidgets('feed failure offers retry', (tester) async {
    final api = MockClient((_) async => http.Response('boom', 500));
    await _pump(tester, api);
    expect(find.text('기록을 불러오지 못했어요'), findsWidgets);
    expect(find.text('다시 시도'), findsWidgets);
  });

  testWidgets('a day page shows the post; 모아보기 jumps back to that day', (
    tester,
  ) async {
    final api = MockClient(
      (_) async => _json({
        'ok': true,
        'posts': [
          {
            'id': 42,
            'user_id': 7,
            'media_type': 'text',
            'caption': 'group caption',
            'taken_at': _today(),
            'captured_at': DateTime.now().toUtc().toIso8601String(),
            'session_id': 'grid-group',
            'position': 0,
          },
        ],
      }),
    );
    await _pump(tester, api);
    // I posted today, so the feed opens on today's page, not the CTA.
    expect(find.byKey(const Key('moment_today_cta')), findsNothing);
    expect(find.text('group caption'), findsWidgets);
    await tester.tap(find.byKey(const Key('moment_calendar_toggle')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('moment_month_grid')), findsOneWidget);
    expect(
      find.text('${DateTime.now().month}월에 1일 남겼어요', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('한 장씩'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('moment_month_grid')), findsNothing);
    expect(find.text('group caption'), findsWidgets);
  });

  testWidgets('a day plays like stories: auto next, tap, hold to pause', (
    tester,
  ) async {
    Map<String, Object> post(int id, int user, String caption, int minute) => {
      'id': id,
      'user_id': user,
      'media_type': 'text',
      'caption': caption,
      'taken_at': _today(),
      'captured_at': DateTime.now()
          .copyWith(hour: 9, minute: minute)
          .toUtc()
          .toIso8601String(),
      'session_id': 's-$user-$id',
      'position': 0,
    };
    final api = MockClient(
      (_) async => _json({
        'ok': true,
        'posts': [
          post(1, 7, 'first', 1),
          post(2, 7, 'second', 2),
          post(3, 7, 'third', 3),
          post(4, 8, 'partner one', 4),
        ],
      }),
    );
    await _pump(tester, api);
    Finder item(int id) => find.byKey(ValueKey('story-item-$id'));
    expect(item(1), findsOneWidget);

    // Photos advance on their own after 5 seconds.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(item(2), findsOneWidget);

    // Holding pauses the timer.
    final tap = find.byKey(ValueKey('story_tap_${dayKey(DateTime.now())}'));
    final gesture = await tester.startGesture(tester.getCenter(tap));
    await tester.pump(const Duration(milliseconds: 600)); // long press
    await tester.pump(const Duration(seconds: 6));
    expect(item(2), findsOneWidget);
    await gesture.up();
    await tester.pump();

    // Tap the right side for the next one, the left side to go back.
    final box = tester.getRect(tap);
    await tester.tapAt(Offset(box.right - 20, box.center.dy));
    await tester.pump();
    expect(item(3), findsOneWidget);
    await tester.tapAt(Offset(box.left + 20, box.center.dy));
    await tester.pump();
    expect(item(2), findsOneWidget);

    // After my last item come the partner's.
    await tester.tapAt(Offset(box.right - 20, box.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(box.right - 20, box.center.dy));
    await tester.pump();
    expect(item(4), findsOneWidget);
  });

  testWidgets('openComposer opens the composer with 오늘의 순간 on', (tester) async {
    final posted = <Map<String, String>>[];
    final api = _recordingApi(posted);
    await _pump(tester, api, openComposer: true);
    await tester.pumpAndSettle();
    expect(find.text('새 순간'), findsOneWidget);
    expect(find.text('촬영'), findsOneWidget);
    expect(find.text('갤러리'), findsOneWidget);
    expect(find.text('글만'), findsOneWidget);
    expect(find.text('남기기 · 둘만 볼 수 있어요'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'hello');
    await tester.tap(find.byKey(const Key('moment_save')));
    await tester.pumpAndSettle();
    expect(posted.single['today_moment'], 'true');
  });

  testWidgets('turning 오늘의 순간 off omits today_moment', (tester) async {
    final posted = <Map<String, String>>[];
    final api = _recordingApi(posted);
    await _pump(tester, api, openComposer: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_more_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('오늘의 순간으로 남기기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'light one');
    await tester.tap(find.byKey(const Key('moment_save')));
    await tester.pumpAndSettle();
    expect(posted, hasLength(1));
    expect(posted.single.containsKey('today_moment'), isFalse);
  });

  testWidgets('empty caption without media explains what to do', (
    tester,
  ) async {
    final api = MockClient((_) async => _json({'ok': true, 'posts': []}));
    await _pump(tester, api, openComposer: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_save')));
    await tester.pumpAndSettle();
    expect(find.text('한 줄이나 사진을 남겨 주세요'), findsOneWidget);
  });

  testWidgets('composer lets the author reorder media before upload', (
    tester,
  ) async {
    final api = MockClient((_) async => _json({'ok': true, 'posts': []}));
    await _pump(
      tester,
      api,
      openComposer: true,
      mediaPicker: () async => [
        MomentMedia(
          name: 'first.mp4',
          bytes: Uint8List.fromList([1]),
          isVideo: true,
          clientRequestId: 'first',
        ),
        MomentMedia(
          name: 'second.mp4',
          bytes: Uint8List.fromList([2]),
          isVideo: true,
          clientRequestId: 'second',
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_action_gallery')));
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('media_first'));
    final second = find.byKey(const Key('media_second'));
    final originalFirstX = tester.getTopLeft(first).dx;
    final list = tester.widget<ReorderableListView>(
      find.byKey(const Key('moment_media_reorder_list')),
    );
    list.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dx, greaterThan(originalFirstX));
    expect(tester.getTopLeft(second).dx, lessThan(tester.getTopLeft(first).dx));
  });

  testWidgets('create page uploads with the chosen date, not today', (
    tester,
  ) async {
    final posted = <Map<String, String>>[];
    final api = _recordingApi(posted);
    await _pump(tester, api, openComposer: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_more_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_date_tile')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final pastDay = now.day == 1 ? 2 : 1;
    await tester.tap(find.text('$pastDay').last);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'old day');
    await tester.tap(find.byKey(const Key('moment_save')));
    await tester.pumpAndSettle();
    final expected =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${pastDay.toString().padLeft(2, '0')}';
    expect(posted.single['taken_at'], expected);
    expect(posted.single['captured_at'], startsWith(expected));
    expect(posted.single.containsKey('today_moment'), isFalse);
  });

  group('media limits', () {
    test('video over a minute is rejected with its own reason', () {
      final issue = momentMediaIssue(
        isVideo: true,
        bytes: 1000,
        duration: const Duration(seconds: 62),
      );
      expect(issue, MomentMediaIssue.tooLong);
      expect(momentMediaIssueLabel(issue!), '영상은 1분까지예요');
      expect(
        momentMediaIssue(
          isVideo: true,
          bytes: 1000,
          duration: const Duration(seconds: 60),
        ),
        isNull,
      );
    });

    test('only cut, long or large clips are re-encoded on the device', () {
      const mb = 1024 * 1024;
      expect(
        momentVideoNeedsConvert(
          bytes: 12 * mb,
          duration: const Duration(seconds: 40),
          end: const Duration(seconds: 40),
        ),
        isFalse,
      );
      expect(
        momentVideoNeedsConvert(
          bytes: 45 * mb,
          duration: const Duration(seconds: 25),
        ),
        isTrue,
      );
      expect(
        momentVideoNeedsConvert(
          bytes: 12 * mb,
          duration: const Duration(seconds: 90),
          end: const Duration(seconds: 60),
        ),
        isTrue,
      );
      expect(
        momentVideoNeedsConvert(
          bytes: 12 * mb,
          duration: const Duration(seconds: 40),
          start: const Duration(seconds: 5),
          end: const Duration(seconds: 40),
        ),
        isTrue,
      );
      expect(
        momentDefaultTrim(const Duration(seconds: 90)).end,
        const Duration(seconds: 60),
      );
    });

    test('files over 30MB are rejected', () {
      final issue = momentMediaIssue(isVideo: false, bytes: momentMaxBytes + 1);
      expect(issue, MomentMediaIssue.tooLarge);
      expect(momentMediaIssueLabel(issue!), '30MB 이하만 올릴 수 있어요');
    });

    test('server codes map to reasons the user can act on', () {
      expect(momentFailureReason('clip_too_long'), '영상은 1분까지예요');
      expect(momentFailureNeedsEdit('clip_too_long'), isTrue);
      expect(momentFailureNeedsEdit('network_error'), isFalse);
    });
  });

  testWidgets('upload banner shows the failure reason with a retry action', (
    tester,
  ) async {
    var retried = false;
    final draft = UploadDraft({
      'id': 'd1',
      'caption': '바다',
      'status': 'failed',
      'error': 'network_error',
      'items': [
        {'post': null},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentUploadBanner(
            drafts: [draft],
            onRetry: () => retried = true,
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('기록을 올리지 못했어요'), findsOneWidget);
    expect(find.text('연결이 불안정했어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });
}

MockClient _recordingApi(List<Map<String, String>> posted) =>
    MockClient((request) async {
      if (request.method == 'POST') {
        final body = String.fromCharCodes(request.bodyBytes);
        final fields = <String, String>{};
        for (final key in ['taken_at', 'captured_at', 'today_moment']) {
          final m = RegExp('name="$key"\\r\\n\\r\\n([^\\r]*)').firstMatch(body);
          if (m != null) fields[key] = m.group(1)!;
        }
        posted.add(fields);
        return _json({
          'ok': true,
          'post': {
            'id': 1,
            'user_id': 7,
            'media_type': 'text',
            'taken_at': fields['taken_at'],
            'captured_at': fields['captured_at'],
          },
        });
      }
      return _json({'ok': true, 'posts': [], 'pins': []});
    });
