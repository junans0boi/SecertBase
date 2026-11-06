import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/archive/personal_history_screen.dart';
import 'package:secret_base_app/v2/v2.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _history() => {
  'ok': true,
  'moments': [
    {
      'id': 11,
      'caption': '비 오는 날 산책',
      'media_type': 'image',
      'media_url': '/uploads/a.jpg',
      'linked_place_name': '한강공원',
      'captured_at': '2026-07-29T03:00:00.000Z',
    },
    {'id': 12, 'caption': null, 'media_type': 'video', 'media_url': '/b.mp4'},
  ],
  'pins': [
    {'id': 5, 'place_name': '달빛카페', 'memo': '라떼가 맛있어요'},
  ],
};

Future<void> _pump(
  WidgetTester tester,
  http.Client client, {
  VoidCallback? onCreateRecord,
  PersonalHistorySaver? saver,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PersonalHistoryScreen(
        client: client,
        onCreateRecord: onCreateRecord,
        saver: saver,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('shows a skeleton while loading', (tester) async {
    final gate = Completer<http.Response>();
    final client = MockClient((_) => gate.future);
    await _pump(tester, client);

    expect(find.byType(V2SkeletonList), findsOneWidget);
    gate.complete(_json({'moments': [], 'pins': []}));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(V2SkeletonList), findsNothing);
  });

  testWidgets('explains that the vault is private and shows the empty state', (
    tester,
  ) async {
    await _pump(
      tester,
      MockClient((_) async => _json({'moments': [], 'pins': []})),
    );

    expect(find.text('나만 볼 수 있는 보관함이에요'), findsOneWidget);
    expect(find.textContaining('상대에게는 보이지 않아요'), findsOneWidget);
    expect(find.text('보관된 기록이 없어요'), findsOneWidget);
    // No create action wired -> no CTA, and nothing to export yet.
    expect(find.text('첫 기록 남기기'), findsNothing);
    expect(find.text('ZIP으로 내보내기'), findsNothing);
  });

  testWidgets('empty state offers the first-record action when wired', (
    tester,
  ) async {
    var tapped = 0;
    await _pump(
      tester,
      MockClient((_) async => _json({'moments': [], 'pins': []})),
      onCreateRecord: () => tapped++,
    );

    await tester.tap(find.text('첫 기록 남기기'));
    expect(tapped, 1);
  });

  testWidgets('lists records with thumbnails and places', (tester) async {
    await _pump(tester, MockClient((_) async => _json(_history())));

    expect(find.text('비 오는 날 산책'), findsOneWidget);
    expect(find.textContaining('한강공원'), findsOneWidget);
    expect(find.textContaining('2026년 7월 29일'), findsOneWidget);
    expect(find.text('영상으로 남긴 순간'), findsOneWidget);
    expect(find.text('달빛카페'), findsOneWidget);
    expect(find.text('라떼가 맛있어요'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('내 기록'), findsOneWidget);
    expect(find.text('내 장소'), findsOneWidget);
  });

  testWidgets('error state offers a retry that reloads', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('boom', 500)
            : _json({'moments': [], 'pins': []});
      }),
    );

    expect(find.text('개인 보관함을 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
    expect(find.text('보관된 기록이 없어요'), findsOneWidget);
  });

  testWidgets('offline failure shows the offline state', (tester) async {
    await _pump(
      tester,
      MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(find.text('인터넷에 연결되어 있지 않아요'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsOneWidget);
  });

  testWidgets('409 while connected is guidance, not an error', (tester) async {
    await _pump(
      tester,
      MockClient(
        (_) async =>
            _json({'reason': 'personal_history_requires_pairing_wait'}, 409),
      ),
    );

    expect(find.text('지금은 닫혀 있어요'), findsOneWidget);
    expect(find.text('개인 보관함을 불러오지 못했어요'), findsNothing);
    expect(find.text('다시 불러오기'), findsNothing);
  });

  testWidgets('delete asks first, says what disappears, then reloads', (
    tester,
  ) async {
    final deleted = <String>[];
    var history = _history();
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.path);
        history = {
          ...history,
          'moments': [(history['moments'] as List).last],
        };
        return _json({'ok': true});
      }
      return _json(history);
    });
    await _pump(tester, client);

    await tester.tap(find.byTooltip('비 오는 날 산책 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('이 기록을 지울까요?'), findsOneWidget);
    expect(find.text('사진 파일까지 함께 지워져요'), findsOneWidget);
    expect(find.text('지운 기록은 되돌릴 수 없어요'), findsOneWidget);
    expect(deleted, isEmpty);

    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(deleted, ['/api/history/moments/11']);
    expect(find.text('기록을 지웠어요'), findsOneWidget);
    expect(find.text('비 오는 날 산책'), findsNothing);
  });

  testWidgets('cancelling the delete sheet keeps the record', (tester) async {
    var deletes = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') deletes++;
      return _json(_history());
    });
    await _pump(tester, client);

    await tester.tap(find.byTooltip('달빛카페 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('이 장소를 지울까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(deletes, 0);
    expect(find.text('달빛카페'), findsOneWidget);
  });

  testWidgets('a failed delete is reported and can be retried', (tester) async {
    var deleteCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleteCalls++;
        return deleteCalls == 1 ? http.Response('x', 500) : _json({'ok': true});
      }
      return _json(_history());
    });
    await _pump(tester, client);

    await tester.tap(find.byTooltip('달빛카페 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(find.text('장소를 지우지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('달빛카페'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(deleteCalls, 2);
  });

  testWidgets('export shows progress, then a success result', (tester) async {
    final gate = Completer<http.Response>();
    Uint8List? saved;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/export')) return gate.future;
      return _json(_history());
    });
    await _pump(
      tester,
      client,
      saver: (name, bytes) async {
        saved = bytes;
        return '/tmp/$name';
      },
    );

    await tester.tap(find.text('ZIP으로 내보내기'));
    await tester.pump();
    expect(find.text('내보내는 중이에요'), findsOneWidget);

    gate.complete(http.Response.bytes([1, 2, 3], 200));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(saved, [1, 2, 3]);
    expect(find.text('내보내는 중이에요'), findsNothing);
    expect(find.text('내보냈어요'), findsOneWidget);
  });

  testWidgets('export failure offers a retry', (tester) async {
    var exports = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/export')) {
        exports++;
        return exports == 1
            ? http.Response('x', 500)
            : http.Response.bytes([9], 200);
      }
      return _json(_history());
    });
    await _pump(tester, client, saver: (name, bytes) async => '/tmp/$name');

    await tester.tap(find.text('ZIP으로 내보내기'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('내보내지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(exports, 2);
    expect(find.text('내보냈어요'), findsOneWidget);
  });
}
