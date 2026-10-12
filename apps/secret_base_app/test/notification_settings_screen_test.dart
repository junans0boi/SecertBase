import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/screens/settings/notification_settings_screen.dart';

void main() {
  testWidgets('switch change is saved through the prefs API', (tester) async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'http://x.test',
      tokenProvider: () => 'jwt',
      client: MockClient((request) async {
        requests.add(request);
        final body = request.method == 'GET'
            ? {
                'ok': true,
                'prefs': {
                  'partner_moment': true,
                  'today_loop': true,
                  'game_invite': false,
                },
              }
            : {'ok': true};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: NotificationSettingsScreen(apiClient: api)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byKey(const ValueKey('pref_game_invite'))).value,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('pref_today_loop')));
    await tester.pumpAndSettle();

    final put = requests.last;
    expect(put.method, 'PUT');
    expect(put.url.path, '/api/notification-prefs');
    expect(jsonDecode(put.body), {'today_loop': false});
  });
}
