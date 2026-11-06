import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/home/home_format.dart';
import 'package:secret_base_app/screens/secret_base/base_anniversaries_tab.dart';
import 'package:secret_base_app/screens/secret_base/base_rewards_tab.dart';
import 'package:secret_base_app/screens/secret_base/secret_base_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _ms(
  String type,
  String label, {
  bool achieved = false,
  bool claimed = false,
  String? at,
  Map<String, dynamic>? reward,
  int? value,
}) => {
  'type': type,
  'label': label,
  'achieved': achieved,
  'claimed': claimed,
  'achieved_at': at,
  'reward': reward,
  'value': ?value,
};

Widget _hub(MockClient client, {int tab = 0}) => MaterialApp(
  home: SecretBaseScreen(
    baseUrl: 'https://base.test',
    authHeaders: const {},
    client: client,
    initialTab: tab,
  ),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final startDay = today().subtract(const Duration(days: 411));
  final coupleInfo = {
    'ok': true,
    'partnerName': '서윤',
    'startDate': isoDay(startDay),
    'dDay': 412,
  };

  test('day milestones are judged by the date, not the server flag', () {
    final future = isoDay(today().add(const Duration(days: 5)));
    final m = Milestone.fromJson(
      _ms('d500', '500일', achieved: true, at: future, reward: {'name': '커플 말'}),
    );
    expect(m.achieved, isFalse);
    expect(m.claimable, isFalse);
    expect(m.subtitle(), contains('5일 남았어요'));
  });

  testWidgets('rewards tab shows progress, claimable rewards and groups', (
    tester,
  ) async {
    _tall(tester);
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/couple/info')) return _json(coupleInfo);
      if (path.endsWith('/milestones')) {
        return _json({
          'ok': true,
          'milestones': [
            _ms(
              'first_moment',
              '첫 번째 순간',
              achieved: true,
              claimed: true,
              at: '2025-09-21',
              reward: {'name': '동물 말', 'icon': '🐾', 'grade': 'B'},
            ),
            _ms(
              'first_visit',
              '첫 번째 방문',
              achieved: true,
              at: '2025-10-01',
              reward: {'name': '황금 윷', 'icon': '🏆', 'grade': 'A'},
            ),
            _ms(
              'moments_50',
              '50번째 순간',
              reward: {'name': '대나무 윷', 'icon': '🎋', 'grade': 'B'},
              value: 41,
            ),
          ],
        });
      }
      return _json({'ok': true});
    });
    await tester.pumpWidget(_hub(client));
    await _settle(tester);

    expect(find.text('2'), findsOneWidget); // achieved
    expect(find.text('받을 보상 1개'), findsOneWidget);
    expect(find.text('지금 받을 수 있어요'), findsOneWidget);
    expect(find.text('황금 윷'), findsOneWidget);
    expect(find.text('받기'), findsOneWidget);
    expect(find.textContaining('41/50'), findsWidgets);
    expect(find.text('받았어요'), findsOneWidget);
    expect(find.textContaining('활성 커플'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('claiming a reward reveals it once and refreshes the list', (
    tester,
  ) async {
    _tall(tester);
    var claimed = false;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/couple/info')) return _json(coupleInfo);
      if (path.endsWith('/claim')) {
        claimed = true;
        return _json({'ok': true, 'item_name': '황금 윷', 'item_icon': '🏆'});
      }
      if (path.endsWith('/milestones')) {
        return _json({
          'ok': true,
          'milestones': [
            _ms(
              'first_visit',
              '첫 번째 방문',
              achieved: true,
              claimed: claimed,
              at: '2025-10-01',
              reward: {'name': '황금 윷', 'icon': '🏆', 'grade': 'A'},
            ),
          ],
        });
      }
      return _json({'ok': true});
    });
    await tester.pumpWidget(_hub(client));
    await _settle(tester);

    await tester.tap(find.text('받기'));
    await _settle(tester);

    expect(claimed, isTrue);
    expect(find.text('황금 윷을 받았어요'), findsOneWidget);
    expect(find.text('놀이에서 써 보기'), findsOneWidget);
    expect(find.text('꾸러미에서 보기'), findsOneWidget);
  });

  testWidgets('rewards tab: error with retry, and unpaired state', (
    tester,
  ) async {
    _tall(tester);
    var calls = 0;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/couple/info')) return _json(coupleInfo);
      calls++;
      if (calls == 1) return _json({'ok': false}, 500);
      return _json({'ok': true, 'milestones': []});
    });
    await tester.pumpWidget(_hub(client));
    await _settle(tester);
    expect(find.text('보상을 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 불러오기'));
    await _settle(tester);
    expect(find.text('보상을 불러오지 못했어요'), findsNothing);
    expect(find.text('첫 보상은 동물 말이에요'), findsOneWidget);

    final unpaired = MockClient(
      (_) async =>
          _json({'ok': false, 'reason': 'active_couple_required'}, 409),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_hub(unpaired));
    await _settle(tester);
    expect(find.text('아직 연결되지 않았어요'), findsOneWidget);
    expect(find.textContaining('활성 커플'), findsNothing);
  });

  testWidgets('grade legend explains B to SSS', (tester) async {
    _tall(tester);
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/couple/info')) return _json(coupleInfo);
      return _json({'ok': true, 'milestones': []});
    });
    await tester.pumpWidget(_hub(client));
    await _settle(tester);
    await tester.tap(find.text('등급이 뭐예요?'));
    await _settle(tester);
    expect(find.text('보상 등급이 뭐예요?'), findsOneWidget);
    expect(find.text('전설'), findsOneWidget);
  });

  test(
    'anniversary entries merge manual and automatic ones, nearest first',
    () {
      final start = today().subtract(const Duration(days: 411));
      final e = buildEntries([
        {
          'id': 1,
          'label': '서윤 생일',
          'date': isoDay(today().add(const Duration(days: 23))),
          'repeat_yearly': true,
        },
        {
          'id': 2,
          'label': '지난 여행',
          'date': isoDay(today().subtract(const Duration(days: 40))),
          'repeat_yearly': false,
        },
      ], start);
      expect(e.upcoming.first.label, '서윤 생일');
      expect(e.upcoming.any((a) => a.auto && a.label == '500일'), isTrue);
      expect(e.past.any((a) => a.label == '지난 여행'), isTrue);
      final days = e.upcoming.map((a) => a.daysUntil).toList();
      expect([...days]..sort(), days);
    },
  );

  testWidgets('anniversaries: list, add, and delete with undo', (tester) async {
    _tall(tester);
    final list = <Map<String, dynamic>>[
      {
        'id': 7,
        'label': '서윤 생일',
        'date': isoDay(today().add(const Duration(days: 23))),
        'repeat_yearly': true,
      },
    ];
    final deletes = <String>[];
    Map<String, dynamic>? posted;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/couple/info')) return _json(coupleInfo);
      if (path.contains('/anniversaries')) {
        if (req.method == 'DELETE') {
          deletes.add(path);
          list.clear();
          return _json({'ok': true});
        }
        if (req.method == 'POST') {
          posted = jsonDecode(req.body) as Map<String, dynamic>;
          list.add({'id': 8, ...posted!});
          return _json({'ok': true}, 201);
        }
        return _json({'ok': true, 'anniversaries': list});
      }
      return _json({'ok': true, 'milestones': []});
    });
    await tester.pumpWidget(_hub(client, tab: 1));
    await _settle(tester);

    expect(find.text('우리의 첫날'), findsOneWidget);
    expect(find.text('D+412'), findsOneWidget);
    expect(find.text('서윤 생일'), findsOneWidget);
    expect(find.text('D-23'), findsOneWidget);
    expect(find.text('자동'), findsWidgets);

    // add
    await tester.tap(find.text('추가'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, '첫 여행');
    await tester.pump();
    await tester.tap(find.text('저장하기'));
    await _settle(tester);
    expect(posted?['label'], '첫 여행');
    expect(posted?['repeat_yearly'], isTrue);

    // delete from the edit sheet, then undo within 5 seconds
    await tester.tap(find.text('서윤 생일'));
    await _settle(tester);
    await tester.tap(find.text('이 기념일 삭제'));
    await _settle(tester);
    await tester.tap(find.text('삭제하기'));
    await _settle(tester);
    expect(find.text('실행 취소'), findsOneWidget);
    await tester.tap(find.text('실행 취소'));
    await _settle(tester);
    expect(find.text('서윤 생일'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(deletes, isEmpty);

    // delete for real: the server is told after the undo window
    await tester.tap(find.text('서윤 생일'));
    await _settle(tester);
    await tester.tap(find.text('이 기념일 삭제'));
    await _settle(tester);
    await tester.tap(find.text('삭제하기'));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 6));
    expect(deletes, ['/api/anniversaries/7']);
  });

  testWidgets('anniversaries: unset first day and no entries shows guidance', (
    tester,
  ) async {
    _tall(tester);
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/couple/info')) {
        return _json({'ok': true, 'partnerName': '서윤', 'startDate': null});
      }
      return _json({'ok': true, 'anniversaries': []});
    });
    await tester.pumpWidget(_hub(client, tab: 1));
    await _settle(tester);
    expect(find.text('아직 등록된 기념일이 없어요'), findsOneWidget);
    expect(find.text('우리의 첫날 정하기'), findsOneWidget);
    expect(find.text('기념일 직접 추가'), findsOneWidget);
  });

  testWidgets('start-date change is saved and rewards reload', (tester) async {
    _tall(tester);
    var milestoneLoads = 0;
    String? patched;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/couple/info')) {
        if (req.method == 'PATCH') {
          patched = jsonDecode(req.body)['start_date'] as String?;
          return _json({'ok': true});
        }
        return _json(coupleInfo);
      }
      if (path.endsWith('/milestones')) {
        milestoneLoads++;
        return _json({'ok': true, 'milestones': []});
      }
      return _json({'ok': true, 'anniversaries': []});
    });
    await tester.pumpWidget(_hub(client, tab: 0));
    await _settle(tester);
    expect(milestoneLoads, 1);

    await tester.tap(find.text('기념일'));
    await _settle(tester);
    await tester.tap(find.byTooltip('첫날 바꾸기'));
    await _settle(tester);
    await tester.tap(find.text('저장하기'));
    await _settle(tester);

    expect(patched, isNotNull);
    expect(milestoneLoads, 2);
  });

  testWidgets('postcard tab: card, empty month and error keep the layout', (
    tester,
  ) async {
    _tall(tester);
    final now = DateTime.now();
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/couple/info')) return _json(coupleInfo);
      if (path.contains('/postcard/')) {
        final month = int.parse(path.split('/').last);
        if (month == now.month) {
          return _json({
            'ok': true,
            'postcard': {
              'year': now.year,
              'month': month,
              'moments_count': 24,
              'visited_count': 3,
              'highlight_post': {
                'id': 1,
                'caption': '한강 노을',
                'media_url': null,
                'captured_at':
                    '${now.year}-${month.toString().padLeft(2, '0')}-18T10:00:00',
              },
              'visited_places': [
                {'pin_id': 1, 'place_name': '한강공원', 'visit_date': '2026-10-18'},
              ],
            },
          });
        }
        return _json({'ok': false}, 500);
      }
      return _json({'ok': true, 'milestones': []});
    });
    await tester.pumpWidget(_hub(client, tab: 2));
    await _settle(tester);

    expect(find.text('${now.month}월의 우리'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('한강 노을'), findsOneWidget);
    expect(find.text('공유하기'), findsOneWidget);

    await tester.tap(find.byTooltip('지난달'));
    await _settle(tester);
    // previous card stays (dimmed) with a retry banner instead of flashing
    expect(find.textContaining('엽서를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('한강 노을'), findsOneWidget);
  });

  testWidgets('memories tab groups by year and refreshes; errors can retry', (
    tester,
  ) async {
    _tall(tester);
    var calls = 0;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/couple/info')) return _json(coupleInfo);
      if (path.endsWith('/memory-card/list')) {
        calls++;
        if (calls == 1) return http.Response('<html>502</html>', 200);
        return _json({
          'ok': true,
          'business_date': '2026-11-06',
          'posts': [
            {
              'id': 1,
              'caption': '노을이 예뻤던 한강 산책',
              'media_url': null,
              'captured_at': '2025-11-06T17:48:00',
              'place_name': '한강공원',
              'years_ago': 1,
            },
            {
              'id': 2,
              'caption': '첫 눈 오는 날',
              'media_url': null,
              'captured_at': '2024-11-06T21:02:00',
              'place_name': null,
              'years_ago': 2,
            },
          ],
        });
      }
      return _json({'ok': true});
    });
    await tester.pumpWidget(_hub(client, tab: 3));
    await _settle(tester);
    expect(find.text('추억을 불러오지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 불러오기'));
    await _settle(tester);
    expect(find.text('1년 전'), findsOneWidget);
    expect(find.text('2년 전'), findsOneWidget);
    expect(find.text('노을이 예뻤던 한강 산책'), findsOneWidget);
    expect(find.text('11월 6일 · 이날의 기록 2개'), findsOneWidget);
  });

  testWidgets('memories tab empty state invites a first record', (
    tester,
  ) async {
    _tall(tester);
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/couple/info')) return _json(coupleInfo);
      return _json({'ok': true, 'posts': [], 'business_date': '2026-11-06'});
    });
    await tester.pumpWidget(_hub(client, tab: 3));
    await _settle(tester);
    expect(find.text('이날의 기록은 아직 없어요'), findsOneWidget);
    expect(find.text('오늘의 순간 남기기'), findsOneWidget);
  });
}
