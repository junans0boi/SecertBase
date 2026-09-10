import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/tarot_api.dart';

void main() {
  test('loads a selectable deck before a daily card is chosen', () async {
    final api = TarotApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({
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
                {'key': 'the_star', 'position': 18},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await api.fetchToday();

    expect(result.personal?.drawn, isFalse);
    expect(result.personal?.drawRequired, isTrue);
    expect(result.personal?.cards.length, 2);
    expect(result.personal?.cards.last.key, 'the_star');
    expect(result.personal?.card, isNull);
  });

  test('loads the authenticated personal and couple Tarot cards', () async {
    late http.Request captured;
    final api = TarotApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'date': '2026-09-10',
            'catalogVersion': 'tarot-major-v1',
            'redrawAvailable': false,
            'personal': {
              'scope': 'user',
              'card': {
                'key': 'the_star',
                'title': '별',
                'orientation': 'upright',
                'plain': '작은 희망을 다시 확인해봐요.',
                'reflection': '오늘의 회복 신호를 적어보세요.',
              },
            },
            'relationship': {
              'scope': 'couple',
              'card': {
                'key': 'the_sun',
                'title': '태양',
                'orientation': 'upright',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await api.fetchToday();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/relationship/tarot/today');
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(result.personal?.card?.title, '별');
    expect(result.relationship?.card?.title, '태양');
    expect(result.redrawAvailable, isFalse);
  });

  test('sends the selected card and scope to the draw endpoint', () async {
    late http.Request captured;
    final api = TarotApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'date': '2026-09-10',
            'catalogVersion': 'tarot-major-v1',
            'redrawAvailable': false,
            'personal': {
              'scope': 'user',
              'drawn': true,
              'drawRequired': false,
              'card': {
                'key': 'the_star',
                'title': '별',
                'orientation': 'upright',
                'plain': '작은 희망을 다시 확인해봐요.',
                'reflection': '오늘의 회복 신호를 적어보세요.',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await api.drawToday(scope: 'user', cardKey: 'the_star');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/relationship/tarot/today/draw');
    expect(jsonDecode(captured.body), {'scope': 'user', 'cardKey': 'the_star'});
    expect(result.personal?.card?.title, '별');
  });
}
