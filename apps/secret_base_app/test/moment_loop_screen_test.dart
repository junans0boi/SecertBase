import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String dayOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> post(
    int id,
    int user,
    String caption, {
    DateTime? day,
    int hour = 9,
    int minute = 0,
    bool locked = false,
  }) {
    final d = day ?? DateTime.now();
    if (locked) {
      return {
        'id': id,
        'user_id': user,
        'taken_at': dayOf(d),
        'today_locked': true,
      };
    }
    return {
      'id': id,
      'user_id': user,
      'media_type': 'text',
      'caption': caption,
      'taken_at': dayOf(d),
      'captured_at': DateTime(
        d.year,
        d.month,
        d.day,
        hour,
        minute,
      ).toUtc().toIso8601String(),
      'session_id': 's-$user-$id',
      'position': 0,
    };
  }

  MomentMedia jpeg(String name) => MomentMedia(
    name: name,
    bytes: Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 6))),
    isVideo: false,
  );

  testWidgets('a text record saves and closes while the upload is pending', (
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
    await tester.tap(find.byKey(const Key('moment_source_text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moment_caption_field')).first,
      '기록 보존',
    );
    await tester.tap(find.byKey(const Key('moment_save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.byKey(const Key('moment_save')), findsNothing);
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

  testWidgets('empty 기록 invites a first record', (tester) async {
    final api = MockClient((_) async => _json({'ok': true, 'posts': []}));
    await _pump(tester, api);
    expect(find.text('우리의 하루'), findsOneWidget);
    expect(find.text('첫 기록을 남겨 볼까요?'), findsOneWidget);
    expect(find.byTooltip('기록 남기기'), findsOneWidget);
  });

  testWidgets('+ asks camera, album or text; album opens the picker', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const Key('moment_add')));
    await tester.pumpAndSettle();
    expect(find.text('카메라로 찍기'), findsOneWidget);
    expect(find.text('앨범에서 고르기'), findsOneWidget);
    expect(find.text('글만 쓰기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('moment_source_gallery')));
    await tester.pumpAndSettle();
    expect(picked, 1);
  });

  testWidgets('a day card has my row and the partner row; 달력 jumps back', (
    tester,
  ) async {
    final api = MockClient(
      (_) async => _json({
        'ok': true,
        'posts': [
          post(42, 7, 'group caption', minute: 1),
          post(43, 8, 'partner caption', minute: 2),
        ],
      }),
    );
    await _pump(tester, api);
    final today = dayKey(DateTime.now());
    expect(find.byKey(Key('moment_day_$today')), findsOneWidget);
    expect(find.byKey(Key('moment_lane_me_$today')), findsOneWidget);
    expect(find.byKey(Key('moment_lane_partner_$today')), findsOneWidget);
    expect(find.byKey(const Key('moment_tile_42')), findsOneWidget);
    expect(find.byKey(const Key('moment_tile_43')), findsOneWidget);
    expect(find.text('group caption', findRichText: true), findsWidgets);

    await tester.tap(find.byKey(const Key('moment_calendar_toggle')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('moment_month_grid')), findsOneWidget);
    expect(
      find.text('${DateTime.now().month}월에 1일 남겼어요 · 둘 다 남긴 날 1일'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(Key('moment_day_cell_$today')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('moment_month_grid')), findsNothing);
    expect(find.byKey(Key('moment_day_$today')), findsOneWidget);
  });

  testWidgets('filling my empty row files the record under that day', (
    tester,
  ) async {
    final posted = <Map<String, String>>[];
    final api = _recordingApi(
      posted,
      posts: [
        post(
          5,
          8,
          'partner only',
          day: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    );
    await _pump(tester, api);
    final day = dateOnly(DateTime.now().subtract(const Duration(days: 3)));
    await tester.tap(find.byKey(Key('moment_fill_${dayKey(day)}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_source_text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moment_caption_field')).first,
      '그날 이야기',
    );
    await tester.tap(find.byKey(const Key('moment_save')));
    await tester.pumpAndSettle();
    expect(posted.single['taken_at'], dayOf(day));
    expect(posted.single.containsKey('today_moment'), isFalse);
  });

  testWidgets('a tile opens the whole day in time order', (tester) async {
    final api = MockClient(
      (_) async => _json({
        'ok': true,
        'posts': [
          post(1, 7, 'first', minute: 1),
          post(2, 8, 'second', minute: 2),
          post(3, 7, 'third', minute: 3),
        ],
      }),
    );
    await _pump(tester, api);
    await tester.tap(find.byKey(const Key('moment_tile_3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment_viewer_pages')), findsOneWidget);
    String who() =>
        tester.widget<Text>(find.byKey(const Key('moment_viewer_who'))).data!;
    expect(who(), startsWith('나 · 오전 9:03'));
    await tester.tap(find.byKey(const Key('moment_viewer_thumb_1')));
    await tester.pumpAndSettle();
    expect(who(), contains('오전 9:02'));
    expect(who(), isNot(startsWith('나 ')));
    await tester.tap(find.byKey(const Key('moment_viewer_thumb_0')));
    await tester.pumpAndSettle();
    expect(who(), startsWith('나 · 오전 9:01'));
    await tester.tap(find.byKey(const Key('moment_viewer_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment_viewer_pages')), findsNothing);
  });

  testWidgets("a partner's locked 오늘의 순간 says how to open it", (tester) async {
    final api = MockClient(
      (_) async => _json({
        'ok': true,
        'posts': [post(9, 8, '', locked: true)],
      }),
    );
    await _pump(tester, api);
    expect(find.text('내 순간을 올리면\n열려요'), findsOneWidget);
    await tester.tap(find.byKey(const Key('moment_tile_9')));
    await tester.pump();
    expect(find.textContaining('내 순간을 남기면'), findsOneWidget);
  });

  testWidgets('openComposer asks how to record', (tester) async {
    final api = MockClient((_) async => _json({'ok': true, 'posts': []}));
    await _pump(tester, api, openComposer: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment_source_camera')), findsOneWidget);
    expect(find.byKey(const Key('moment_source_text')), findsOneWidget);
  });

  testWidgets('album → editor → 올리기 posts with the caption and 오늘의 순간', (
    tester,
  ) async {
    final posted = <Map<String, String>>[];
    final api = _recordingApi(posted);
    await _pump(tester, api, mediaPicker: () async => [jpeg('a.jpg')]);
    await tester.tap(find.byKey(const Key('moment_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_source_gallery')));
    await settle(tester);
    expect(find.byKey(const Key('moment_post_submit')), findsOneWidget);
    expect(find.byKey(const Key('moment_post_today')), findsOneWidget);
    expect(find.textContaining('오늘'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('moment_post_caption')),
      '한강 산책',
    );
    await tester.tap(find.byKey(const Key('moment_post_submit')));
    await settle(tester);
    expect(posted, hasLength(1));
    expect(posted.single['taken_at'], dayOf(DateTime.now()));
    expect(posted.single['caption'], '한강 산책');
    expect(posted.single['today_moment'], 'true');
  });

  testWidgets('choosing 어제 drops 오늘의 순간 and posts yesterday', (tester) async {
    final posted = <Map<String, String>>[];
    final api = _recordingApi(posted);
    await _pump(tester, api, mediaPicker: () async => [jpeg('a.jpg')]);
    await tester.tap(find.byKey(const Key('moment_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment_source_gallery')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('moment_post_date')));
    await tester.pumpAndSettle();
    final yesterday = dateOnly(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    await tester.tap(find.byKey(Key('moment_date_${dayKey(yesterday)}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment_post_today')), findsNothing);
    await tester.tap(find.byKey(const Key('moment_post_submit')));
    await settle(tester);
    expect(posted.single['taken_at'], dayOf(yesterday));
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

MockClient _recordingApi(
  List<Map<String, String>> posted, {
  List<Map<String, Object?>> posts = const [],
}) => MockClient((request) async {
  if (request.method == 'POST') {
    final body = utf8.decode(request.bodyBytes, allowMalformed: true);
    final fields = <String, String>{};
    for (final key in ['taken_at', 'captured_at', 'today_moment', 'caption']) {
      final m = RegExp(
        'name="$key"\\r\\n(?:[^\\r]+\\r\\n)*\\r\\n([^\\r]*)',
      ).firstMatch(body);
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
  return _json({'ok': true, 'posts': posts, 'pins': []});
});
