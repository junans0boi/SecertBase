import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/tarot_api.dart';
import 'package:secret_base_app/screens/relationship/tarot_screen.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _drawn(String scope, String key, String title) => {
  'scope': scope,
  'drawn': true,
  'drawRequired': false,
  'card': {
    'key': key,
    'title': title,
    'orientation': 'upright',
    'plain': '새로운 시작을 살펴봐요.',
    'reflection': '오늘의 첫 걸음을 적어 보세요.',
  },
  'disclaimer': '재미와 성찰을 위한 안내예요.',
};

Widget _host(TarotApi api, {bool reduced = true, VoidCallback? onPartner}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 1600),
          disableAnimations: reduced,
        ),
        child: TarotScreen(api: api, onOpenPartner: onPartner),
      ),
    );

void main() {
  testWidgets('pick a face-down card, flip, and see the reading', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var picked = false;
    final api = TarotApi(
      baseUrl: 'https://x.example',
      token: 't',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return _json({
            'ok': true,
            'date': '2026-09-10',
            'catalogVersion': 'tarot-major-v1',
            'redrawAvailable': false,
            'personal': {
              'scope': 'user',
              'drawn': false,
              'drawRequired': true,
              'cards': [
                {'key': 'the_fool', 'position': 1},
                {'key': 'the_star', 'position': 2},
              ],
            },
          });
        }
        picked = true;
        return _json({
          'ok': true,
          'date': '2026-09-10',
          'catalogVersion': 'tarot-major-v1',
          'redrawAvailable': false,
          'personal': _drawn('user', 'the_fool', '바보'),
        });
      }),
    );
    await tester.pumpWidget(_host(api));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('tarot_user_picker')), findsOneWidget);
    expect(find.text('카드를 한 장 골라 주세요'), findsOneWidget);
    expect(find.text('바보'), findsNothing);

    await tester.tap(find.byKey(const Key('tarot_pick_user_the_fool')));
    await tester.pump();
    await tester.tap(find.text('이 카드 뒤집기'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(picked, isTrue);
    expect(find.text('바보'), findsOneWidget);
    expect(find.byKey(const Key('tarot_user_result_message')), findsOneWidget);
    expect(find.text('정방향'), findsNothing);
    // No partner yet: the connect CTA is present and tappable.
    expect(find.text('파트너 연결하기'), findsOneWidget);
    // Share card opens a preview that omits personal data.
    await tester.ensureVisible(find.text('카드로 공유'));
    await tester.tap(find.text('카드로 공유'));
    await tester.pumpAndSettle();
    expect(find.text('이미지로 저장'), findsOneWidget);
    expect(find.textContaining('이름이나 생일은 카드에 들어가지 않아요'), findsOneWidget);
  });

  testWidgets('already drawn today shows the card, toggle, and partner CTA works', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = TarotApi(
      baseUrl: 'https://x.example',
      token: 't',
      client: MockClient(
        (request) async => _json({
          'ok': true,
          'date': '2026-09-10',
          'catalogVersion': 'tarot-major-v1',
          'redrawAvailable': false,
          'personal': _drawn('user', 'the_star', '별'),
          'relationship': _drawn('couple', 'the_sun', '태양'),
        }),
      ),
    );
    await tester.pumpWidget(_host(api));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('별'), findsOneWidget);
    expect(find.text('오늘 이미 뽑은 카드예요'), findsOneWidget);
    await tester.tap(find.text('우리'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('태양'), findsOneWidget);
    expect(find.text('우리 둘의 관계 카드'), findsOneWidget);
  });

  testWidgets('error state offers retry and partner connect without callbacks', (
    tester,
  ) async {
    var partner = 0;
    final api = TarotApi(
      baseUrl: 'https://x.example',
      token: 't',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'ok': false, 'reason': 'active_couple_required'}),
          409,
        ),
      ),
    );
    await tester.pumpWidget(_host(api, onPartner: () => partner++));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.tap(find.text('파트너 연결하기'));
    expect(partner, 1);
  });
}
