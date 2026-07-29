import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/afterglow_api.dart';

void main() {
  test('Afterglow API creates a visit and contributes with JWT', () async {
    final captured = <http.Request>[];
    final api = AfterglowApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured.add(request);
        if (request.url.path.endsWith('/visit')) {
          return http.Response(
            '{"ok":true,"visit":{"id":7,"mapPinId":4,"visitDate":"2026-07-29"}}',
            201,
          );
        }
        return http.Response('{"ok":true,"contribution":{"id":9}}', 200);
      }),
    );

    final visit = await api.createVisit(4);
    await api.contribute(
      visitId: visit.id,
      postId: 12,
      caption: '좋았어',
      emotionTag: '포근함',
    );

    expect(visit.visitDate, '2026-07-29');
    expect(captured.first.method, 'POST');
    expect(captured.first.headers['authorization'], 'Bearer jwt-token');
    expect(captured.last.method, 'PUT');
    expect(jsonDecode(captured.last.body), {
      'post_id': 12,
      'caption': '좋았어',
      'emotion_tag': '포근함',
    });
  });

  test('candidate picker requires author, pin, and visit date', () {
    final candidates = afterglowMomentCandidates(
      pinId: 4,
      visitDate: '2026-07-29',
      userId: 1,
      posts: [
        {'id': 1, 'user_id': 1, 'map_pin_id': 4, 'taken_at': '2026-07-29'},
        {'id': 2, 'user_id': 2, 'map_pin_id': 4, 'taken_at': '2026-07-29'},
        {'id': 3, 'user_id': 1, 'map_pin_id': 5, 'taken_at': '2026-07-29'},
        {'id': 4, 'user_id': 1, 'map_pin_id': 4, 'taken_at': '2026-07-28'},
      ],
    );

    expect(candidates.map((post) => post['id']), [1]);
  });
}
