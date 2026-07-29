import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/today_api.dart';

void main() {
  test('Today state parses complete moments and a deleted tombstone', () {
    final state = TodayState.fromJson({
      'ok': true,
      'date': '2026-07-29',
      'status': 'complete',
      'hasPartnerMoment': true,
      'revealedAt': '2026-07-29T12:00:00.000Z',
      'myMoment': {
        'id': 11,
        'user_id': 1,
        'UserName': '나',
        'media_type': 'image',
        'media_url': '/uploads/mine.png',
        'caption': '한강 산책',
        'linked_place_name': '한강공원',
        'deleted': false,
      },
      'partnerMoment': {'user_id': 2, 'UserName': '상대', 'deleted': true},
    });

    expect(state.status, TodayStatus.complete);
    expect(state.myMoment?.caption, '한강 산책');
    expect(state.myMoment?.linkedPlaceName, '한강공원');
    expect(state.partnerMoment?.deleted, isTrue);
    expect(state.partnerMoment?.caption, isNull);
  });

  test('Today state supports every Home status', () {
    for (final entry in {
      'empty': TodayStatus.empty,
      'partner_waiting': TodayStatus.partnerWaiting,
      'self_waiting': TodayStatus.selfWaiting,
      'complete': TodayStatus.complete,
      'viewed': TodayStatus.viewed,
    }.entries) {
      final state = TodayState.fromJson({
        'ok': true,
        'date': '2026-07-29',
        'status': entry.key,
      });
      expect(state.status, entry.value);
    }
  });

  test('authenticated user can load the current Today state', () async {
    late http.Request captured;
    final api = TodayApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ok":true,"date":"2026-07-29","status":"empty",'
          '"hasPartnerMoment":false,"myMoment":null,"partnerMoment":null}',
          200,
        );
      }),
    );

    final state = await api.fetchState();

    expect(captured.method, 'GET');
    expect(
      captured.url,
      Uri.parse('https://secretbase.example/api/retention/today'),
    );
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(state.status, TodayStatus.empty);
  });

  test('author can designate an existing post as the Today Moment', () async {
    late http.Request captured;
    final api = TodayApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await api.designateMoment(const TodayMomentSelection(postId: 47));

    expect(captured.method, 'PUT');
    expect(
      captured.url,
      Uri.parse('https://secretbase.example/api/retention/today/moment'),
    );
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(jsonDecode(captured.body), {'post_id': 47});
  });

  test('designation failure exposes the server reason', () async {
    final api = TodayApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async =>
            http.Response('{"ok":false,"reason":"today_loop_locked"}', 409),
      ),
    );

    expect(
      () => api.designateMoment(const TodayMomentSelection(postId: 47)),
      throwsA(
        isA<TodayApiException>().having(
          (error) => error.reason,
          'reason',
          'today_loop_locked',
        ),
      ),
    );
  });

  test('author can remove the current Today Moment designation', () async {
    late http.Request captured;
    final api = TodayApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true,"removed":true}', 200);
      }),
    );

    await api.removeDesignation();

    expect(captured.method, 'DELETE');
    expect(
      captured.url,
      Uri.parse('https://secretbase.example/api/retention/today/moment'),
    );
    expect(captured.headers['authorization'], 'Bearer jwt-token');
  });
}
