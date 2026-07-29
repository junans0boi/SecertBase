import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/today_api.dart';

void main() {
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
