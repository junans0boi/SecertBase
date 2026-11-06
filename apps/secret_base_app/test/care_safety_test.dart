import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/counseling_api.dart';
import 'package:secret_base_app/core/mindcare_api.dart';
import 'package:secret_base_app/core/safety_location.dart';
import 'package:secret_base_app/screens/relationship/care_safety.dart';
import 'package:secret_base_app/screens/relationship/care_settings_screen.dart';
import 'package:secret_base_app/screens/relationship/counseling_screen.dart';
import 'package:secret_base_app/screens/relationship/mindcare_screen.dart';
import 'package:secret_base_app/v2/v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Granted implements SafetyLocationProvider {
  @override
  Future<SafetyLocation> resolve() async => const SafetyLocation(
    permissionGranted: true,
    countryCode: 'KR',
    adminArea: '서울특별시',
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _mind({
  String status = 'active',
  String state = 'emotion',
  List<Map<String, String>> choices = const [],
  Map<String, dynamic> extra = const {},
}) => {
  'ok': true,
  'session': {
    'id': 7,
    'status': status,
    'currentState': state,
    'userResponseCount': 0,
    'ownerOnly': true,
  },
  'messages': [
    {
      'id': 1,
      'sequence': 1,
      'role': 'assistant',
      'content': '지금 마음을 안전한 속도로 살펴볼게요.',
    },
  ],
  'choices': choices,
  'nextQuestion': {'key': state, 'text': '어떤 감정이 가까우세요?', 'allowFreeText': false},
  ...extra,
};

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('mindcare asks for consent once before any request', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final api = MindcareApi(
      baseUrl: 'https://x.example',
      token: 't',
      client: MockClient((r) async {
        requests.add(r);
        return _json(
          _mind(choices: [
            {'key': 'anxious', 'label': '불안해요'},
          ]),
          201,
        );
      }),
    );
    await _pump(tester, MindcareScreen(api: api));
    expect(find.text('시작하기 전에 알려드려요'), findsOneWidget);
    expect(find.textContaining('AI 가이드예요'), findsWidgets);
    expect(find.textContaining('112·119'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.tap(find.text('확인했고 시작할게요'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('지금 마음을 안전한 속도로 살펴볼게요.'), findsOneWidget);
    expect(find.text('불안해요'), findsOneWidget);
    expect(find.text('도움이 필요하면'), findsOneWidget);
    expect(find.byKey(const Key('mindcare_flow_header')), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool(CarePrefs.consentKey), isTrue);
  });

  testWidgets('safety answer keeps location off by default and shows built-in contacts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({CarePrefs.consentKey: true});
    Map<String, dynamic>? safetyBody;
    final api = MindcareApi(
      baseUrl: 'https://x.example',
      token: 't',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/sessions')) {
          return _json(
            _mind(status: 'safety_pending', state: 'safety', choices: [
              {'key': 'safe_now', 'label': '지금은 안전해요'},
              {'key': 'need_help', 'label': '지금 도움이 필요해요'},
            ]),
            201,
          );
        }
        if (r.url.path.endsWith('/safety')) {
          safetyBody = jsonDecode(r.body) as Map<String, dynamic>;
          return _json(
            _mind(status: 'safety_support', state: 'safety', extra: {
              'safety': {'status': 'needs_immediate_help'},
              'resourceVersion': 'v1',
              'locationMode': 'general',
              'resources': [
                {'key': 'e', 'title': '지금 바로 도움', 'description': 'd', 'contact': '112 / 119'},
              ],
            }),
          );
        }
        return _json({'ok': true});
      }),
    );
    await _pump(tester, MindcareScreen(api: api, locationProvider: _Granted()));
    await tester.tap(find.text('지금 도움이 필요해요'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(safetyBody!['safeNow'], isFalse);
    expect(safetyBody!['locationPermission'], 'denied');
    expect(safetyBody!.containsKey('adminArea'), isFalse);
    for (final n in ['112', '119', '109', '1577-0199', '1366']) {
      expect(find.text(n), findsOneWidget);
    }
  });

  testWidgets('location is sent only when pre-chosen in settings', (tester) async {
    SharedPreferences.setMockInitialValues({
      CarePrefs.consentKey: true,
      CarePrefs.locationKey: true,
    });
    Map<String, dynamic>? safetyBody;
    final api = MindcareApi(
      baseUrl: 'https://x.example',
      token: 't',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/sessions')) {
          return _json(
            _mind(status: 'safety_pending', state: 'safety', choices: [
              {'key': 'need_help', 'label': '지금 도움이 필요해요'},
            ]),
            201,
          );
        }
        safetyBody = jsonDecode(r.body) as Map<String, dynamic>;
        return _json(_mind(status: 'safety_support', state: 'safety'));
      }),
    );
    await _pump(tester, MindcareScreen(api: api, locationProvider: _Granted()));
    await tester.tap(find.text('지금 도움이 필요해요'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(safetyBody!['locationPermission'], 'granted');
    expect(safetyBody!['adminArea'], '서울특별시');
  });

  testWidgets('help chip opens offline contacts; tap offers call or copy', (
    tester,
  ) async {
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
    await _pump(
      tester,
      const V2Theme(
        child: Scaffold(body: Center(child: CareHelpChip())),
      ),
    );
    await tester.tap(find.text('도움이 필요하면'));
    await tester.pumpAndSettle();
    expect(find.text('109'), findsOneWidget);
    await tester.tap(find.text('109'));
    await tester.pumpAndSettle();
    expect(find.text('전화 걸기'), findsOneWidget);
    await tester.tap(find.text('번호 복사'));
    await tester.pumpAndSettle();
    expect(copied, '109');
  });

  testWidgets('counseling shows crisis contacts from server safety fields and fallback badge', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({CarePrefs.consentKey: true});
    final conv = {
      'ok': true,
      'session': {'id': 12, 'scope': 'private', 'title': '나의 상담', 'status': 'active'},
      'messages': [
        {'id': 1, 'sequence': 1, 'role': 'assistant', 'content': '천천히 이야기해도 괜찮아요.'},
      ],
    };
    final api = CounselingApi(
      baseUrl: 'https://x.example',
      token: 't',
      client: MockClient((r) async {
        if (r.method == 'GET') return _json({'ok': true, 'sessions': []});
        if (r.url.path.endsWith('/messages')) {
          return _json({
            ...conv,
            'messages': [
              ...(conv['messages'] as List),
              {'id': 2, 'sequence': 2, 'role': 'user', 'content': '힘들어요'},
              {'id': 3, 'sequence': 3, 'role': 'assistant', 'content': '아래 도움 기관을 확인해 주세요.'},
            ],
            'safety': {'required': true, 'status': 'pending'},
            'resourceVersion': 'v1',
            'locationMode': 'general',
            'resources': <Object>[],
          }, 201);
        }
        return _json(conv, 201);
      }),
    );
    await _pump(tester, RelationshipCounselingScreen(api: api, shared: false));
    expect(find.text('상담 시작하기'), findsOneWidget);
    expect(find.textContaining('상담사와 채팅'), findsNothing);
    await tester.tap(find.text('상담 시작하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('counseling_scope_card')), findsOneWidget);
    expect(find.text('천천히 이야기해도 괜찮아요.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '힘들어요');
    await tester.tap(find.text('보내고 답변 받기'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('109'), findsOneWidget);
    expect(find.text('1577-0199'), findsOneWidget);
  });

  testWidgets('돌봄 설정: location is off by default and needs OS permission to turn on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const CareSettingsScreen(locationProvider: _Denied()));
    expect(await CarePrefs.locationEnabled(), isFalse);
    for (final n in ['112', '119', '109', '1577-0199', '1366']) {
      expect(find.text(n), findsOneWidget);
    }
    // Turning it on goes through the purpose sheet, then the OS (denied here).
    await tester.tap(find.byType(V2Toggle));
    await tester.pumpAndSettle();
    expect(find.text('허용하기'), findsOneWidget);
    await tester.tap(find.text('허용하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('위치를 켜지 못했어요'), findsOneWidget);
    expect(await CarePrefs.locationEnabled(), isFalse);
  });
}

class _Denied implements SafetyLocationProvider {
  const _Denied();
  @override
  Future<SafetyLocation> resolve() async => const SafetyLocation.denied();
}
