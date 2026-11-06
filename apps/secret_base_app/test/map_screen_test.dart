import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/archive/map_screen.dart';

void main() {
  test('map tiles use a keyless primary and fallback provider', () {
    expect(mapTileUrl, contains('openstreetmap.org'));
    expect(mapFallbackTileUrl, contains('openstreetmap.org'));
    expect(mapTileUrl.toLowerCase(), isNot(contains('api_key')));
    expect(mapTileUrl.toLowerCase(), isNot(contains('apikey')));
  });

  test('normalizePlaceResultForMap accepts Kakao string coordinates', () {
    final result = normalizePlaceResultForMap({
      'provider': 'kakao',
      'name': '카카오 장소',
      'latitude': '37.55878289',
      'longitude': '126.8279012',
      'distanceMeters': '132',
    });

    expect(result['lat'], 37.55878289);
    expect(result['lon'], 126.8279012);
    expect(result['distanceMeters'], 132);
  });

  test('map value parsers accept database string values', () {
    expect(placeDoubleForMap('37.55878289'), 37.55878289);
    expect(placeDoubleForMap('126.8279012'), 126.8279012);
    expect(placeDoubleForMap(132), 132);
    expect(placeIntForMap('4'), 4);
    expect(placeIntForMap(4.0), 4);
  });

  test(
    'linkedSetlogPostsForMap prefers same-day posts that mention the place',
    () {
      final pin = {
        'place_name': '성수 카페',
        'visit_date': '2026-07-14T00:00:00.000Z',
      };
      final posts = [
        {'id': 1, 'taken_at': '2026-07-14', 'caption': '비 오는 날 성수 카페에서 찍은 사진'},
        {'id': 2, 'taken_at': '2026-07-14', 'caption': '장소명은 안 적었지만 같은 날 기록'},
        {'id': 3, 'taken_at': '2026-07-13', 'caption': '성수 카페 전날 기록'},
      ];

      final linked = linkedSetlogPostsForMap(pin, posts);

      expect(linked.map((post) => post['id']), [1]);
    },
  );

  test('linkedSetlogPostsForMap prefers direct map_pin_id links', () {
    final linked = linkedSetlogPostsForMap(
      {'id': 12, 'place_name': '성수 카페', 'visit_date': '2026-07-14'},
      [
        {
          'id': 1,
          'map_pin_id': 12,
          'taken_at': '2026-07-13',
          'caption': '직접 연결',
        },
        {'id': 2, 'taken_at': '2026-07-14', 'caption': '같은 날 기록'},
      ],
    );

    expect(linked.map((post) => post['id']), [1]);
  });

  test('linkedSetlogPostsForMap falls back to same-day posts', () {
    final linked = linkedSetlogPostsForMap(
      {'place_name': '성수 카페', 'visit_date': '2026-07-14'},
      [
        {'id': 1, 'taken_at': '2026-07-14', 'caption': '장소명은 안 적었지만 같은 날 기록'},
        {'id': 2, 'taken_at': '2026-07-13', 'caption': '성수 카페 전날 기록'},
      ],
    );

    expect(linked.map((post) => post['id']), [1]);
  });

  group('MapScreen 2.0', () {
    final pins = [
      {
        'id': 1,
        'user_id': 7,
        'place_name': '성수 카페',
        'category': '카페',
        'status': 'visited',
        'latitude': 37.54,
        'longitude': 127.05,
        'rating': 4,
        'visit_date': '2026-07-14',
      },
      {
        'id': 2,
        'user_id': 8,
        'place_name': '한강 피크닉',
        'category': '활동',
        'status': 'wishlist',
        'latitude': 37.541,
        'longitude': 127.052,
      },
    ];

    http.Response jsonResponse(Map<String, dynamic> body, int status) =>
        http.Response.bytes(
          utf8.encode(jsonEncode(body)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    Future<void> withMap(
      WidgetTester tester,
      Future<void> Function() body, {
      MockClientHandler? handleRequest,
    }) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: MapScreen()));
          await tester.pump(const Duration(milliseconds: 300));
          await body();
        },
        () => MockClient(
          handleRequest ??
              (request) async {
                if (request.url.path == '/api/map') {
                  return jsonResponse({'ok': true, 'pins': pins}, 200);
                }
                return jsonResponse({'ok': true, 'reviews': []}, 200);
              },
        ),
      );
    }

    testWidgets('overlay has search + my location, one chip row', (
      tester,
    ) async {
      await withMap(tester, () async {
        expect(find.text('비밀지도'), findsOneWidget);
        expect(find.byKey(const Key('map_search')), findsOneWidget);
        expect(find.byKey(const Key('map_locate')), findsOneWidget);
        expect(find.byTooltip('내 위치로 이동'), findsOneWidget);
        expect(find.text('전체 2'), findsOneWidget);
        expect(find.text('다녀온 곳 1'), findsOneWidget);
        expect(find.text('가고 싶은 곳 1'), findsOneWidget);
        expect(find.text('Date Afterglow'), findsNothing);
        expect(find.byKey(const Key('map-pin-1')), findsOneWidget);
        expect(find.textContaining('OpenStreetMap'), findsWidgets);
      });
    });

    testWidgets('status chip filters the pins', (tester) async {
      await withMap(tester, () async {
        await tester.tap(find.byKey(const Key('map_chip_wishlist')));
        await tester.pump();
        expect(find.byKey(const Key('map-pin-1')), findsNothing);
        expect(find.byKey(const Key('map-pin-2')), findsOneWidget);
      });
    });

    testWidgets('409 active_couple_required shows unpaired, not empty', (
      tester,
    ) async {
      await withMap(
        tester,
        () async {
          expect(find.text('아직 연결되지 않았어요'), findsOneWidget);
          expect(find.text('아직 저장한 장소가 없어요'), findsNothing);
        },
        handleRequest: (_) async => jsonResponse({
          'ok': false,
          'reason': 'active_couple_required',
        }, 409),
      );
    });

    testWidgets('ok:false without status is an error, retry reloads', (
      tester,
    ) async {
      var calls = 0;
      await withMap(
        tester,
        () async {
          expect(find.text('지도를 불러오지 못했어요'), findsOneWidget);
          await tester.tap(find.text('다시 시도'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byKey(const Key('map-pin-1')), findsOneWidget);
        },
        handleRequest: (request) async {
          if (request.url.path != '/api/map') {
            return jsonResponse({'ok': true, 'reviews': []}, 200);
          }
          calls++;
          return calls == 1
              ? jsonResponse({'ok': false}, 200)
              : jsonResponse({'ok': true, 'pins': pins}, 200);
        },
      );
    });

    testWidgets('empty map hints how to add the first place', (tester) async {
      await withMap(
        tester,
        () async {
          expect(find.byKey(const Key('map_empty_hint')), findsOneWidget);
          expect(find.text('검색하거나 지도를 눌러 첫 장소를 남겨 보세요.'), findsOneWidget);
        },
        handleRequest: (_) async => jsonResponse({'ok': true, 'pins': []}, 200),
      );
    });

    testWidgets('pin detail: 3 sections, 한마디, CTA, no fake heart', (
      tester,
    ) async {
      await withMap(tester, () async {
        await tester.tap(find.byKey(const Key('map-pin-2')));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('한강 피크닉'), findsWidgets);
        expect(find.text('우리 이야기'), findsOneWidget);
        expect(find.text('한마디 남기기'), findsOneWidget);
        expect(find.text('리뷰'), findsNothing);
        expect(find.byKey(const Key('map_cta_visited')), findsOneWidget);
        expect(find.byKey(const Key('map_cta_directions')), findsOneWidget);
        expect(find.byKey(const Key('map_leave_moment')), findsOneWidget);
        expect(find.byKey(const Key('map_detail_delete')), findsNothing);
        await tester.tap(find.byKey(const Key('map_detail_more')));
        await tester.pump();
        expect(find.byKey(const Key('map_detail_delete')), findsOneWidget);
      });
    });

    testWidgets('notes show nicknames, never user codes', (tester) async {
      await withMap(
        tester,
        () async {
          await tester.tap(find.byKey(const Key('map-pin-1')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('USER-CODE-9'), findsNothing);
          expect(find.text('같이 가서 좋았어'), findsOneWidget);
        },
        handleRequest: (request) async {
          if (request.url.path == '/api/map') {
            return jsonResponse({'ok': true, 'pins': pins}, 200);
          }
          return jsonResponse({
            'ok': true,
            'reviews': [
              {
                'id': 5,
                'user_id': 8,
                'user_code': 'USER-CODE-9',
                'content': '같이 가서 좋았어',
              },
            ],
          }, 200);
        },
      );
    });

    testWidgets('mini sheet saves a wishlist place and selects the new pin', (
      tester,
    ) async {
      var postCount = 0;
      var saved = false;
      await withMap(
        tester,
        () async {
          await tester.tapAt(const Offset(100, 800));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('장소 추가'), findsOneWidget);
          await tester.tap(find.byKey(const Key('map_add_wishlist')));
          await tester.pump();
          expect(find.text('장소 이름을 적어 주세요'), findsOneWidget);
          await tester.enterText(find.byKey(const Key('map_add_name')), '새 카페');
          await tester.tap(find.byKey(const Key('map_add_wishlist')));
          await tester.tap(find.byKey(const Key('map_add_wishlist')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(postCount, 1);
          expect(find.text('장소 추가'), findsNothing);
          expect(find.text('가고 싶은 곳으로 남겼어요'), findsOneWidget);
          expect(find.text('가고 싶은 곳 2'), findsOneWidget);
        },
        handleRequest: (request) async {
          if (request.method == 'POST' && request.url.path == '/api/map') {
            postCount++;
            saved = true;
            return jsonResponse({'ok': true, 'id': 3}, 200);
          }
          if (request.url.path == '/api/map') {
            return jsonResponse({
              'ok': true,
              'pins': [
                ...pins,
                if (saved)
                  {
                    'id': 3,
                    'user_id': 7,
                    'place_name': '새 카페',
                    'category': '기타',
                    'status': 'wishlist',
                    'latitude': 37.5,
                    'longitude': 127.0,
                  },
              ],
            }, 200);
          }
          return jsonResponse({'ok': true, 'reviews': []}, 200);
        },
      );
    });

    testWidgets('save failure keeps the form and allows retry', (tester) async {
      var failing = true;
      await withMap(
        tester,
        () async {
          await tester.tapAt(const Offset(100, 800));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.enterText(
            find.byKey(const Key('map_add_name')),
            '실패 카페',
          );
          await tester.tap(find.byKey(const Key('map_add_visited')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('장소를 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
          expect(find.text('실패 카페'), findsOneWidget);
          failing = false;
          await tester.tap(find.byKey(const Key('map_add_visited')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('장소 추가'), findsNothing);
        },
        handleRequest: (request) async {
          if (request.method == 'POST') {
            return failing
                ? jsonResponse({'ok': false}, 500)
                : jsonResponse({'ok': true, 'id': 9}, 200);
          }
          if (request.url.path == '/api/map') {
            return jsonResponse({'ok': true, 'pins': pins}, 200);
          }
          return jsonResponse({'ok': true, 'reviews': []}, 200);
        },
      );
    });

    testWidgets('list handle opens the place list', (tester) async {
      await withMap(tester, () async {
        await tester.tap(find.byKey(const Key('map_list_handle')));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('우리 장소 2곳'), findsOneWidget);
        expect(find.byKey(const Key('map_list_1')), findsOneWidget);
      });
    });
  });
}
