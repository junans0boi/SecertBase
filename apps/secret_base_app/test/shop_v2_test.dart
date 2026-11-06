import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/shop/shop_screen.dart';

const _base = 'https://shop.test';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

MockClient _client({
  int balance = 60000,
  List<Map<String, dynamic>> missions = const [],
  bool failItems = false,
  List<http.Request>? log,
}) => MockClient((request) async {
  log?.add(request);
  if (request.method == 'GET') {
    return switch (request.url.path) {
      '/api/shop/items' =>
        failItems ? _json({}, 500) : _json({'items': <Object>[]}),
      '/api/shop/coupons' => _json({'coupons': <Object>[]}),
      '/api/shop/owned' => _json({'owned': <Object>[]}),
      '/api/shop/equipped' => _json({'slots': {}}),
      '/api/wallet/balance' => _json({'balance': balance}),
      '/api/user/level' => _json({
        'ok': true,
        'level': 3,
        'xp': 10,
        'xpNeeded': 100,
        'tickets': 0,
      }),
      '/api/missions' => _json({'missions': missions}),
      _ => _json({}),
    };
  }
  return _json({'ok': true});
});

Future<void> _open(WidgetTester tester, MockClient client) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ShopScreen(client: client, baseUrl: _base),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _mission(
  int id,
  String title, {
  int progress = 0,
  int target = 1,
  bool completed = false,
  bool claimed = false,
  int coins = 300,
}) => {
  'id': id,
  'title': title,
  'type': 'weekly',
  'progress': progress,
  'targetCount': target,
  'completed': completed,
  'claimed': claimed,
  'rewardCoins': coins,
};

void main() {
  testWidgets('shop load failure is a retryable state, never 오류: \$e', (
    tester,
  ) async {
    await _open(tester, _client(failItems: true));
    expect(find.text('상점을 열지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('오류'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('coin pill is the one balance and opens 코인 얻는 법', (tester) async {
    await _open(tester, _client(balance: 52300));
    expect(find.text('52,300'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop_balance_card')));
    await tester.pumpAndSettle();
    expect(find.text('코인 얻는 법'), findsWidgets);
    expect(find.textContaining('돈으로 살 수 없어요'), findsOneWidget);
  });

  testWidgets('missions are split into ready / in progress / done', (
    tester,
  ) async {
    await _open(
      tester,
      _client(
        missions: [
          _mission(1, '오늘의 기록 남기기', progress: 1, completed: true),
          _mission(2, '이번 주 기록 5번', progress: 3, target: 5),
          _mission(3, '프로필 설정', progress: 1, completed: true, claimed: true),
        ],
      ),
    );
    await tester.tap(find.text('미션 1'));
    await tester.pumpAndSettle();
    expect(find.text('받을 수 있어요 1'), findsOneWidget);
    expect(find.text('진행 중 1'), findsOneWidget);
    expect(find.text('완료 1'), findsOneWidget);
    expect(find.text('받았어요'), findsOneWidget);
  });

  testWidgets('no missions shows an empty state, not "불러오는 중"', (tester) async {
    await _open(tester, _client());
    await tester.tap(find.text('미션'));
    await tester.pumpAndSettle();
    expect(find.text('지금은 진행 중인 미션이 없어요'), findsOneWidget);
    expect(find.textContaining('불러오는 중'), findsNothing);
  });

  testWidgets('coupon without a title explains why instead of doing nothing', (
    tester,
  ) async {
    final log = <http.Request>[];
    await _open(tester, _client(log: log));
    await tester.tap(find.text('쿠폰'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('쿠폰 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();
    expect(find.text('쿠폰 이름을 입력해 주세요.'), findsOneWidget);
    expect(log.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('gacha: odds sheet, confirm shows before and after coins', (
    tester,
  ) async {
    await _open(tester, _client(balance: 60000));
    await tester.tap(find.text('뽑기').first);
    await tester.pumpAndSettle();
    expect(find.text('3,000 코인으로 뽑기'), findsOneWidget);
    expect(find.text('45,000 코인으로 뽑기'), findsOneWidget);

    await tester.tap(find.text('뽑기 확률 보기'));
    await tester.pumpAndSettle();
    expect(find.text('60.0%'), findsOneWidget);
    expect(find.text('96.0%'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('45,000 코인으로 뽑기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('45,000 코인을 써요'), findsOneWidget);
    expect(find.textContaining('60,000 → 15,000'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });

  testWidgets('gacha: not enough coins shows the shortfall', (tester) async {
    await _open(tester, _client(balance: 500));
    await tester.tap(find.text('뽑기').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('100,000 코인 · 코인이 모자라요'));
    await tester.pumpAndSettle();
    expect(find.text('코인이 99,500 모자라요'), findsOneWidget);
    expect(find.text('코인 얻는 법 보기'), findsOneWidget);
  });
}
