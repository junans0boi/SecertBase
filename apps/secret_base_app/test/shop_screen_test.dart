import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/shop/inventory_tab.dart';
import 'package:secret_base_app/screens/shop/shop_screen.dart';

const _baseUrl = 'https://shop.test';

http.Response _json(Object body, {int statusCode = 200}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _shopItem({bool usable = true}) => {
  'id': 1,
  'name': '봄빛 윷',
  'description': '오늘의 게임을 조금 더 산뜻하게 시작해요.',
  'game': 'yut',
  'slot': 'yut_yut',
  'grade': 'A',
  'icon': '🎲',
  'price': 120,
  'usable': usable,
  'stats': <Map<String, dynamic>>[],
};

Future<http.Response> _getShopResponse(http.Request request) async {
  return switch (request.url.path) {
    '/api/shop/items' => _json({
      'items': [_shopItem()],
    }),
    '/api/shop/coupons' => _json({'coupons': []}),
    '/api/shop/owned' => _json({'owned': []}),
    '/api/shop/equipped' => _json({'slots': {}}),
    '/api/wallet/balance' => _json({'balance': 500}),
    '/api/user/level' => _json({
      'ok': true,
      'level': 2,
      'xp': 40,
      'xpNeeded': 100,
      'tickets': 1,
    }),
    '/api/missions' => _json({'missions': []}),
    _ => _json({}),
  };
}

void main() {
  testWidgets('shop separates balance, purchase action, and result', (
    tester,
  ) async {
    final purchase = Completer<http.Response>();
    var purchaseCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return _getShopResponse(request);
      if (request.url.path == '/api/shop/buy') {
        purchaseCalls++;
        return purchase.future;
      }
      return _json({});
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ShopScreen(client: client, baseUrl: _baseUrl),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop_balance_card')), findsOneWidget);
    expect(find.text('현재 사용할 수 있는 코인'), findsOneWidget);
    expect(find.text('구매 가능한 아이템'), findsOneWidget);
    expect(find.byKey(const Key('shop_item_1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop_item_1')));
    await tester.pumpAndSettle();
    expect(find.text('🪙 120 구매'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop_purchase_button_1')));
    await tester.pump();
    expect(purchaseCalls, 1);

    // Re-opening while the first request is pending must not expose a second
    // active submit action.
    await tester.tap(find.byKey(const Key('shop_item_1')));
    await tester.pumpAndSettle();
    expect(find.text('구매 중...'), findsOneWidget);
    expect(purchaseCalls, 1);

    purchase.complete(_json({'ok': true, 'new_balance': 380}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop_purchase_feedback')), findsOneWidget);
    expect(find.textContaining('봄빛 윷을 보관함에 넣었어요'), findsOneWidget);
  });

  testWidgets('shop keeps purchase errors readable and recoverable', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'GET') return _getShopResponse(request);
      if (request.url.path == '/api/shop/buy') {
        return _json({'ok': false, 'reason': 'insufficient_coins'});
      }
      return _json({});
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ShopScreen(client: client, baseUrl: _baseUrl),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop_item_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop_purchase_button_1')));
    await tester.pumpAndSettle();

    expect(find.text('구매하지 못했어요 · 코인이 부족해요'), findsOneWidget);
    expect(find.text('구매 가능한 아이템'), findsOneWidget);
  });

  testWidgets('inventory exposes a retryable error state', (tester) async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryTab(
            client: client,
            baseUrl: _baseUrl,
            onBalanceChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inventory_error_state')), findsOneWidget);
    expect(find.text('인벤토리를 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('inventory distinguishes empty and usable item details', (
    tester,
  ) async {
    var hasItem = false;
    final client = MockClient((request) async {
      if (request.url.path == '/api/shop/owned') {
        return _json({
          'owned': hasItem
              ? [
                  {
                    'item_id': 1,
                    'name': '별빛 카드',
                    'description': '원카드에서 사용할 수 있는 카드 뒷면이에요.',
                    'game': 'onecard',
                    'slot': 'onecard_cardback',
                    'grade': 'A',
                    'icon': '🃏',
                    'stats': <String, dynamic>{},
                  },
                ]
              : [],
        });
      }
      if (request.url.path == '/api/shop/equipped') {
        return _json({'slots': {}});
      }
      if (request.url.path == '/api/wallet/balance') {
        return _json({'balance': 80});
      }
      return _json({});
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryTab(
            client: client,
            baseUrl: _baseUrl,
            onBalanceChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inventory_empty_state')), findsOneWidget);
    expect(find.text('아직 보유한 아이템이 없어요.'), findsOneWidget);

    hasItem = true;
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inventory_empty_state')), findsNothing);
    await tester.tap(find.text('별빛 카드'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inventory_item_description')), findsOneWidget);
    expect(find.text('원카드에서 사용할 수 있는 카드 뒷면이에요.'), findsOneWidget);
    expect(find.byKey(const Key('inventory_use_cta')), findsOneWidget);
    expect(find.text('장착하기'), findsOneWidget);
  });
}
