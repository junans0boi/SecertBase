// 윷 스킨 상점·보관함 표시(티켓 27): 윷 스킨만 보이고, 말 스킨·은퇴한 옛 윷은 숨기며, 소수 효과 수치도 읽기 좋게.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_palette.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_skin_shop.dart';
import 'package:secret_base_app/widgets/play_kit/play_kit.dart';
import 'package:secret_base_app/screens/shop/inventory_tab.dart';
import 'package:secret_base_app/screens/shop/shop_screen.dart';

const _baseUrl = 'https://shop.test';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _skin(
  int id,
  String name,
  String grade,
  String icon,
  int price,
  String statKey,
  num value,
) => {
  'id': id,
  'name': name,
  'description': '$name 설명',
  'game': 'yut',
  'slot': 'yut_yut',
  'grade': grade,
  'icon': icon,
  'price': price,
  'usable': true,
  'stats': [
    {'key': statKey, 'value': value},
  ],
};

void main() {
  test('stat values print readably: whole numbers plain, decimals trimmed', () {
    expect(formatStatValue(8), '8');
    expect(formatStatValue(8.0), '8');
    expect(formatStatValue(0.4), '0.4');
    expect(formatStatValue(1.2), '1.2');
    expect(formatStatValue(2.50), '2.5');
    expect(formatStatValue(0.125), '0.13');
  });

  test('the yut stat labels name the real effects in Korean', () {
    expect(statLabels['yut_control_pct'], contains('윷·모 확률'));
    expect(statLabels['yut_backdo_shield_pct'], contains('빽도 방어'));
    expect(statLabels['piece_catch_resist_pct'], contains('잡힘 방어'));
    expect(statLabels['yut_win_coin_pct'], contains('코인'));
    expect(statLabels['yut_overturn_pct'], contains('지고 있을 때'));
  });

  testWidgets(
    'shop lists only yut skins with their effect; piece skins and retired items are hidden',
    (tester) async {
      final client = MockClient((request) async {
        return switch (request.url.path) {
          '/api/shop/items' => _json({
            'items': [
              _skin(110, '대나무 윷', 'B', '🎋', 1500, 'yut_control_pct', 0.4),
              _skin(113, '옥 윷', 'A', '💚', 2500, 'yut_win_coin_pct', 4),
              {
                'id': 30,
                'name': '호랑이 말',
                'game': 'yut',
                'slot': 'yut_piece',
                'grade': 'A',
                'icon': '🐯',
                'price': 2000,
                'stats': <Map<String, dynamic>>[],
              },
            ],
          }),
          '/api/shop/coupons' => _json({'coupons': []}),
          '/api/shop/owned' => _json({'owned': []}),
          '/api/shop/equipped' => _json({'slots': {}}),
          '/api/wallet/balance' => _json({'balance': 5000}),
          '/api/user/level' => _json({
            'ok': true,
            'level': 1,
            'xp': 0,
            'xpNeeded': 100,
            'tickets': 0,
          }),
          '/api/missions' => _json({'missions': []}),
          _ => _json({}),
        };
      });
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ShopScreen(client: client, baseUrl: _baseUrl),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop_item_110')), findsOneWidget);
      expect(find.byKey(const Key('shop_item_113')), findsOneWidget);
      expect(find.byKey(const Key('shop_item_30')), findsNothing);
      expect(find.text('호랑이 말'), findsNothing);
      expect(find.text('♟️ 말'), findsNothing);
      // 효과 수치: 소수점이 잘리지 않는다.
      await tester.tap(find.byKey(const Key('shop_item_110')));
      await tester.pumpAndSettle();
      expect(find.text('+0.4'), findsOneWidget);
      expect(find.text('🎯 윷·모 확률 +%p'), findsOneWidget);
      expect(find.text('🪙 1.5K 구매'), findsOneWidget);
    },
  );

  testWidgets(
    'inventory hides piece skins, retired yut items and the default piece',
    (tester) async {
      final client = MockClient((request) async {
        return switch (request.url.path) {
          '/api/shop/owned' => _json({
            'owned': [
              {
                'item_id': 115,
                'name': '번개 윷',
                'game': 'yut',
                'slot': 'yut_yut',
                'grade': 'S',
                'icon': '⚡',
                'stats': {'yut_control_pct': 0.8},
              },
              {
                'item_id': 62,
                'name': '호랑이 말',
                'game': 'yut',
                'slot': 'yut_piece',
                'grade': 'A',
                'icon': '🐯',
                'stats': <String, dynamic>{},
              },
              {
                'item_id': 40,
                'name': '벚꽃 윷',
                'game': 'yut_legacy',
                'slot': 'yut_yut',
                'grade': 'B',
                'icon': '🌸',
                'stats': <String, dynamic>{},
              },
            ],
          }),
          '/api/shop/equipped' => _json({
            'slots': {
              'yut_yut': {
                'item_id': 115,
                'name': '번개 윷',
                'icon': '⚡',
                'grade': 'S',
                'stats': {'yut_control_pct': 0.8},
              },
            },
          }),
          '/api/wallet/balance' => _json({'balance': 80}),
          _ => _json({}),
        };
      });
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
      expect(find.text('번개 윷'), findsWidgets);
      expect(find.text('기본 윷'), findsWidgets);
      expect(find.text('호랑이 말'), findsNothing);
      expect(find.text('벚꽃 윷'), findsNothing);
      expect(find.text('기본 말'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'the server theme picks the day or night palette; unknown means day',
    () {
      expect(YutPalette.forTheme('night').night, isTrue);
      expect(YutPalette.forTheme('night').theme, same(GameTheme.yutNight));
      expect(YutPalette.forTheme('day').theme, same(GameTheme.yutDay));
      expect(YutPalette.forTheme(null).night, isFalse);
      expect(YutPalette.forTheme('whatever').night, isFalse);
    },
  );

  testWidgets(
    'skin shop: hero shows the equipped skin, cards by grade, tapping a card previews it',
    (tester) async {
      final items = [
        _skin(113, '옥 윷', 'A', '💚', 2500, 'yut_win_coin_pct', 4),
        _skin(110, '대나무 윷', 'B', '🎋', 1500, 'yut_control_pct', 0.4),
        _skin(115, '번개 윷', 'S', '⚡', 0, 'yut_control_pct', 0.7),
      ];
      final tapped = <int>[];
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                YutSkinShop(
                  items: items,
                  ownedIds: const {110, 113},
                  equippedIds: const {113},
                  formatCoins: (n) => '$n',
                  onItemTap: (i) => tapped.add((i['id'] as num).toInt()),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      Finder inHero(String text) => find.descendant(
        of: find.byKey(const ValueKey('yut_skin_hero')),
        matching: find.text(text),
      );
      expect(inHero('옥 윷'), findsOneWidget);
      expect(inHero('장착 중'), findsOneWidget);
      expect(find.textContaining('윷·모 코인 보너스'), findsOneWidget);
      // 카드는 B, A, S 순서. 뽑기 전용 스킨은 가격 대신 "뽑기 전용".
      final order = [110, 113, 115];
      final xs = [
        for (final id in order)
          tester.getTopLeft(find.byKey(ValueKey('shop_item_$id'))).dx,
      ];
      expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue);
      expect(find.text('뽑기 전용'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_item_110')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, [110]);
      expect(inHero('대나무 윷'), findsOneWidget);
      expect(inHero('보유'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
