import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/screens/settings/notification_settings_screen.dart';

void main() {
  testWidgets(
    'pending save blocks later writes, rolls back on failure, and survives disposal',
    (tester) async {
      final first = Completer<http.Response>();
      var puts = 0;
      final api = ApiClient(
        baseUrl: 'http://x.test',
        tokenProvider: () => 'jwt',
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            puts++;
            return first.future;
          }
          return http.Response(
            '{"prefs":{"partner_moment":true,"today_loop":true,"game_invite":true}}',
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: NotificationSettingsScreen(apiClient: api)),
      );
      await tester.pumpAndSettle();
      final partner = find.byKey(const ValueKey('pref_partner_moment'));
      await tester.tap(partner);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pref_today_loop')));
      await tester.pump();
      expect(puts, 1);
      first.complete(http.Response('{"error":"unavailable"}', 503));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(partner).value, true);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('pref_today_loop')),
            )
            .value,
        true,
      );
      expect(find.text('저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);

      final pending = Completer<http.Response>();
      final disposedApi = ApiClient(
        baseUrl: 'http://x.test',
        tokenProvider: () => 'jwt',
        client: MockClient(
          (request) async => request.method == 'GET'
              ? http.Response('{"prefs":{"partner_moment":true}}', 200)
              : pending.future,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            key: const ValueKey('new'),
            apiClient: disposedApi,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(partner);
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete(http.Response('{"error":"unavailable"}', 503));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'quiet hours and reveal hour retain typed values and save partial changes',
    (tester) async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://x.test',
        tokenProvider: () => 'jwt',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? {
                      'prefs': {
                        'partner_moment': true,
                        'today_loop': true,
                        'game_invite': true,
                        'quiet_hours_enabled': true,
                        'quiet_start': '22:00',
                        'quiet_end': '08:00',
                        'reveal_hour': 21,
                      },
                    }
                  : {'ok': true},
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: NotificationSettingsScreen(apiClient: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('21:00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pref_quiet_start')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 22, minute: 0),
      );
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(jsonDecode(requests.last.body), {'quiet_start': '22:00'});
      await tester.tap(find.byKey(const ValueKey('pref_quiet_hours_enabled')));
      await tester.pumpAndSettle();
      expect(jsonDecode(requests.last.body), {'quiet_hours_enabled': false});
      await tester.ensureVisible(
        find.byKey(const ValueKey('pref_reveal_hour')),
      );
      await tester.tap(find.byKey(const ValueKey('pref_reveal_hour')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reveal_option_20')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('reveal_option_20')));
      await tester.pumpAndSettle();
      expect(jsonDecode(requests.last.body), {'reveal_hour': 20});
    },
  );
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
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('pref_game_invite')),
          )
          .value,
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
