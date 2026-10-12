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

  group('MapScreen bottom sheet', () {
    final pins = [
      {
        'id': 1,
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
        'place_name': '한강 피크닉',
        'category': '활동',
        'status': 'wishlist',
        'latitude': 37.541,
        'longitude': 127.052,
      },
    ];

    Future<void> withMap(
      WidgetTester tester,
      Future<void> Function() body, {
      MockClientHandler? handleRequest,
    }) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: MapScreen()));
          await tester.pump(const Duration(milliseconds: 200));
          await body();
        },
        () => MockClient(
          handleRequest ??
              (_) async => http.Response.bytes(
                utf8.encode(
                  jsonEncode({'ok': true, 'pins': pins, 'reviews': []}),
                ),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
        ),
      );
    }

    double sheetFraction(WidgetTester tester) =>
        tester.getSize(find.byKey(const Key('map-sheet'))).height / 600;

    Future<void> enterWishlistPin(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('map-add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('map-sheet')),
          matching: find.text('가고 싶은 곳'),
        ),
      );
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '장소 이름',
      );
      await tester.enterText(name, '새 카페');
      await tester.ensureVisible(find.text('☕ 카페'));
      await tester.tap(find.text('☕ 카페'));
      final memo = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '가보고 싶은 이유',
      );
      await tester.ensureVisible(memo);
      await tester.enterText(memo, '함께 커피 마시기');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '지도에 저장'));
      await tester.pumpAndSettle();
      expect(sheetFraction(tester), closeTo(0.45, 0.01));
    }

    http.Response jsonResponse(Map<String, dynamic> body, int status) =>
        http.Response.bytes(
          utf8.encode(jsonEncode(body)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    testWidgets('starts collapsed and shows one filter row', (tester) async {
      await withMap(tester, () async {
        expect(sheetFraction(tester), closeTo(0.12, 0.01));
        expect(find.text('전체'), findsOneWidget);
        expect(find.text('다녀온 곳'), findsOneWidget);
        expect(find.text('가고 싶은 곳'), findsOneWidget);
        expect(find.byKey(const Key('map-filter-button')), findsOneWidget);
        expect(find.text('🍽️ 식당'), findsNothing);
      });
    });

    testWidgets('marker tap moves sheet to half with inline detail', (
      tester,
    ) async {
      await withMap(tester, () async {
        await tester.tap(find.byKey(const Key('map-pin-1')));
        await tester.pumpAndSettle();
        expect(find.text('성수 카페'), findsWidgets);
        expect(find.text('장소 수정'), findsOneWidget);
        expect(sheetFraction(tester), closeTo(0.45, 0.01));
      });
    });

    testWidgets('dragging up to expanded shows the place list', (tester) async {
      await withMap(tester, () async {
        await tester.drag(
          find.descendant(
            of: find.byKey(const Key('map-sheet')),
            matching: find.byType(ListView),
          ),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(sheetFraction(tester), closeTo(0.92, 0.01));
        expect(find.text('성수 카페'), findsOneWidget);
        expect(find.text('한강 피크닉'), findsOneWidget);
      });
    });

    testWidgets('filter button picks a category and highlights', (
      tester,
    ) async {
      await withMap(tester, () async {
        await tester.tap(find.byKey(const Key('map-filter-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('☕ 카페'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-pin-1')), findsOneWidget);
        expect(find.byKey(const Key('map-pin-2')), findsNothing);
        expect(find.byKey(const Key('map-filter-active')), findsOneWidget);
      });
    });

    testWidgets('add FAB opens the add form in the half sheet', (tester) async {
      await withMap(tester, () async {
        await tester.tap(find.byKey(const Key('map-add-fab')));
        await tester.pumpAndSettle();
        expect(find.text('비밀 장소 추가'), findsOneWidget);
        expect(sheetFraction(tester), closeTo(0.45, 0.01));
      });
    });

    testWidgets('double tap sends one POST until save completes', (
      tester,
    ) async {
      final save = Completer<http.Response>();
      var saved = false;
      var postCount = 0;
      await withMap(
        tester,
        () async {
          await enterWishlistPin(tester);
          await tester.tap(find.text('지도에 저장'));
          // Both taps occur before a rebuild, exercising the synchronous guard.
          await tester.tap(find.text('지도에 저장'));
          await tester.pump();
          expect(postCount, 1);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '지도에 저장'),
                )
                .onPressed,
            isNull,
          );
          expect(find.text('비밀 장소 추가'), findsOneWidget);
          expect(sheetFraction(tester), closeTo(0.45, 0.01));
          await tester.tap(find.text('지도에 저장'));
          await tester.pump();
          expect(postCount, 1);

          save.complete(jsonResponse({'ok': true, 'id': 3}, 200));
          await tester.pumpAndSettle();
          expect(postCount, 1);
          expect(find.text('비밀 장소 추가'), findsNothing);
          expect(sheetFraction(tester), closeTo(0.12, 0.01));
          expect(find.byKey(const Key('map-pin-3')), findsOneWidget);
          expect(find.byKey(const Key('map-filter-active')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        handleRequest: (request) async {
          if (request.method == 'POST' && request.url.path == '/api/map') {
            postCount++;
            final response = await save.future;
            saved = true;
            return response;
          }
          if (request.method == 'GET' && request.url.path == '/api/map') {
            return jsonResponse({
              'ok': true,
              'pins': [
                ...pins,
                if (saved)
                  {
                    'id': 3,
                    'place_name': '새 카페',
                    'category': '카페',
                    'status': 'wishlist',
                    'latitude': 37.54,
                    'longitude': 127.05,
                  },
              ],
            }, 200);
          }
          throw StateError('Unexpected fake API request');
        },
      );
    });

    testWidgets('completed save returns the sheet to collapsed', (
      tester,
    ) async {
      await withMap(
        tester,
        () async {
          await enterWishlistPin(tester);
          await tester.tap(find.text('지도에 저장'));
          await tester.pumpAndSettle();
          expect(sheetFraction(tester), closeTo(0.12, 0.01));
          expect(find.text('비밀 장소 추가'), findsNothing);
        },
        handleRequest: (request) async {
          if (request.method == 'POST' && request.url.path == '/api/map') {
            return jsonResponse({'ok': true, 'id': 3}, 200);
          }
          if (request.method == 'GET' && request.url.path == '/api/map') {
            return jsonResponse({'ok': true, 'pins': pins}, 200);
          }
          throw StateError('Unexpected fake API request');
        },
      );
    });

    for (final status in [400, 500]) {
      testWidgets('HTTP $status keeps the entered form and permits retry', (
        tester,
      ) async {
        final save = Completer<http.Response>();
        final requests = <Map<String, dynamic>>[];
        await withMap(
          tester,
          () async {
            await enterWishlistPin(tester);
            await tester.tap(find.text('지도에 저장'));
            await tester.pump();
            expect(requests, hasLength(1));
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, '지도에 저장'),
                  )
                  .onPressed,
              isNull,
            );
            // A success-shaped body must not override the HTTP failure.
            save.complete(jsonResponse({'ok': true}, status));
            await tester.pumpAndSettle();
            expect(find.text('비밀 장소 추가'), findsOneWidget);
            expect(find.text('새 카페'), findsOneWidget);
            expect(find.text('함께 커피 마시기'), findsOneWidget);
            expect(find.text('방문 날짜'), findsNothing);
            expect(sheetFraction(tester), closeTo(0.45, 0.01));
            expect(find.text('장소를 저장하지 못했어요'), findsOneWidget);
            expect(find.byKey(const Key('map-filter-active')), findsNothing);
            expect(find.byKey(const Key('map-pin-1')), findsOneWidget);
            expect(find.byKey(const Key('map-pin-2')), findsOneWidget);
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, '지도에 저장'),
                  )
                  .onPressed,
              isNotNull,
            );
            // Let the error snackbar leave the retry button's hit area.
            await tester.pump(const Duration(seconds: 4));
            await tester.pumpAndSettle();
            await tester.tap(find.text('지도에 저장'));
            await tester.pumpAndSettle();
            expect(requests, hasLength(2));
            expect(requests.last, containsPair('place_name', '새 카페'));
            expect(requests.last, containsPair('memo', '함께 커피 마시기'));
            expect(requests.last, containsPair('status', 'wishlist'));
            expect(requests.last, containsPair('category', '카페'));
            expect(sheetFraction(tester), closeTo(0.12, 0.01));
            expect(find.text('비밀 장소 추가'), findsNothing);
            expect(tester.takeException(), isNull);
          },
          handleRequest: (request) async {
            if (request.method == 'POST' && request.url.path == '/api/map') {
              requests.add(jsonDecode(request.body) as Map<String, dynamic>);
              if (requests.length == 1) return save.future;
              return jsonResponse({'ok': true, 'id': 3}, 200);
            }
            if (request.method == 'GET' && request.url.path == '/api/map') {
              return jsonResponse({'ok': true, 'pins': pins}, 200);
            }
            throw StateError('Unexpected fake API request');
          },
        );
      });
    }

    for (final status in [200, 500]) {
      testWidgets('pending HTTP $status save is safe after screen disposal', (
        tester,
      ) async {
        final save = Completer<http.Response>();
        var postCount = 0;
        var loadCount = 0;
        await withMap(
          tester,
          () async {
            await enterWishlistPin(tester);
            await tester.tap(find.text('지도에 저장'));
            await tester.pump();
            expect(postCount, 1);
            await tester.pumpWidget(const MaterialApp(home: SizedBox()));
            save.complete(jsonResponse({'ok': status == 200, 'id': 3}, status));
            await tester.pumpAndSettle();
            expect(loadCount, 1);
            expect(find.byType(MapScreen), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(tester.takeException(), isNull);
          },
          handleRequest: (request) async {
            if (request.method == 'POST' && request.url.path == '/api/map') {
              postCount++;
              return save.future;
            }
            if (request.method == 'GET' && request.url.path == '/api/map') {
              loadCount++;
              return jsonResponse({'ok': true, 'pins': pins}, 200);
            }
            throw StateError('Unexpected fake API request');
          },
        );
      });
    }
  });
}
