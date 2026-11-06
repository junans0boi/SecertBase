import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/auth_service.dart';
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Requests the fake server saw, as `METHOD /path`.
final moreRequests = <String>[];

/// Bodies of the last requests keyed like [moreRequests].
final moreBodies = <String, String>{};

/// The user the fake server returns from the profile endpoint.
Map<String, dynamic> moreUser = {};

/// Per-test overrides: `METHOD /path` → response (status, body).
final moreOverrides = <String, (int, Object)>{};

Map<String, dynamic> pairedUser({String provider = 'password'}) => {
  'UserId': 1,
  'UserName': '민지',
  'Nickname': '민지',
  'FullName': '김민지',
  'Email': 'minji@example.com',
  'BirthDate': '1998-03-14',
  'AuthProvider': provider,
  'PartnerCode': 'ABC123',
  'PartnerName': '서윤',
};

Map<String, dynamic> unpairedUser() => {
  'UserId': 1,
  'UserName': '민지',
  'Nickname': '민지',
  'FullName': '김민지',
  'Email': 'minji@example.com',
  'BirthDate': '1998-03-14',
  'AuthProvider': 'password',
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<http.Response> _handle(http.Request r) async {
  final key = '${r.method} ${r.url.path}';
  moreRequests.add(key);
  moreBodies[key] = r.body;
  final override = moreOverrides[key];
  if (override != null) return _json(override.$2, override.$1);
  switch (key) {
    case 'GET /api/user/profile/1':
      return _json({'user': moreUser});
    case 'PATCH /api/user/profile/1':
      final body = jsonDecode(r.body) as Map;
      moreUser = {
        ...moreUser,
        'Nickname': body['nickname'],
        'BirthDate': body['birthDate'],
      };
      return _json({'user': moreUser});
    case 'GET /api/couple/info':
      return _json({
        'ok': true,
        'startDate': '2025-09-21',
        'dDay': 412,
        'partnerName': '서윤',
        'nextAnniversary': {
          'label': '500일',
          'date': '2027-02-02',
          'daysUntil': 88,
        },
      });
    case 'GET /api/notification-prefs':
      return _json({
        'prefs': {
          'partner_moment': true,
          'today_loop': true,
          'game_invite': true,
          'quiet_hours_enabled': true,
          'quiet_start': '23:00',
          'quiet_end': '07:00',
        },
      });
    case 'GET /api/wallet/balance':
      return _json({'balance': 52300});
    case 'DELETE /api/user/partner':
      moreUser = {...moreUser}
        ..remove('PartnerCode')
        ..remove('PartnerName');
      return _json({'ok': true});
    case 'DELETE /api/user':
      return _json({'ok': true});
  }
  return _json({});
}

/// Call once in `setUpAll`: the AuthService API client talks to [_handle].
void setUpMoreServer() {
  http.runWithClient(() => AuthService().apiClient, () => MockClient(_handle));
}

/// Signs [user] in through the real AuthService against the fake server.
Future<void> signInForMore(
  WidgetTester tester,
  Map<String, dynamic> user,
) async {
  moreRequests.clear();
  moreBodies.clear();
  moreOverrides.clear();
  moreUser = user;
  SharedPreferences.setMockInitialValues({
    'auth_token': 'test-token',
    'user_data': jsonEncode(user),
  });
  await tester.runAsync(() => AuthService().init());
}

/// Records clipboard writes; returns a getter for the last text.
String? Function() captureClipboard(WidgetTester tester) {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return () => copied;
}

/// A client against the fake server that does NOT log out on 401.
ApiClient plainMoreClient() => ApiClient(
  baseUrl: 'https://more.test',
  tokenProvider: () => 'test-token',
  client: MockClient(_handle),
);
