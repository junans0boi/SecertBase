import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/compatibility_api.dart';
import 'package:secret_base_app/screens/relationship/compatibility_screen.dart';

Map<String, dynamic> _state({required String status}) => {
  'ok': true,
  'status': status,
  'dependencyStatus': {
    'attachment': status == 'ready' ? 2 : 1,
    'conflictRepair': 2,
  },
  'result': status == 'ready'
      ? {
          'analysisCode': 'attachment_conflict',
          'analysisVersion': 'v1',
          'dimensions': [
            {
              'key': 'reassurance_gap',
              'title': '안정감 확인 차이',
              'scoreDifference': 30,
            },
          ],
          'complementaryPatternKey': 'space_and_closeness_translation',
          'complementaryPattern': '서로의 신호를 번역하는 과정이 중요해요.',
          'cautionInteractions': ['개인 시간을 관계 거절과 구분해보세요.'],
          'conversationPrompts': ['다음 갈등에서 회복 신호를 정해보세요.'],
          'conflictPatternKey': 'coordination_needed',
          'disclaimer': '관계 대화용 참고 정보예요.',
        }
      : null,
};

void main() {
  test('parses conflict repair compatibility fields', () async {
    String? requestedPath;
    final payload = _state(status: 'ready');
    payload['result'] = {
      ...Map<String, dynamic>.from(payload['result'] as Map),
      'analysisCode': 'conflict_repair',
      'dimensions': [
        {'key': 'conflict_trigger', 'title': '갈등 촉발 신호', 'scoreDifference': 30},
      ],
      'conflictTrigger': '갈등 신호를 먼저 알아차려보세요.',
      'repairApproach': '다시 대화할 시점을 정해보세요.',
      'conversationStarters': ['첫 문장을 정해볼까요?'],
    };
    final api = CompatibilityApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response.bytes(
          utf8.encode(jsonEncode(payload)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final state = await api.fetchConflictRepair();

    expect(
      requestedPath,
      '/api/relationship/compatibility/conflict-repair/current',
    );
    expect(state.result?.analysisCode, 'conflict_repair');
    expect(state.result?.conflictTrigger, contains('갈등 신호'));
    expect(state.result?.repairApproach, contains('대화할'));
    expect(state.result?.conversationStarters.single, contains('첫 문장'));
  });

  test('loads personal compatibility by its independent code', () async {
    String? requestedPath;
    final payload = _state(status: 'ready');
    payload['result'] = {
      ...Map<String, dynamic>.from(payload['result'] as Map),
      'analysisCode': 'emotional-regulation_compatibility',
    };
    final api = CompatibilityApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response.bytes(
          utf8.encode(jsonEncode(payload)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final state = await api.fetchPersonal('emotional-regulation');

    expect(
      requestedPath,
      '/api/relationship/compatibility/emotional-regulation/current',
    );
    expect(state.result?.analysisCode, 'emotional-regulation_compatibility');
  });

  test('loads couple compatibility by its independent code', () async {
    String? requestedPath;
    final payload = _state(status: 'pending');
    final api = CompatibilityApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response.bytes(
          utf8.encode(jsonEncode(payload)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final state = await api.fetchCouple('affection-alignment');

    expect(
      requestedPath,
      '/api/relationship/compatibility/affection-alignment/current',
    );
    expect(state.status, 'pending');
    expect(state.result, isNull);
  });

  testWidgets('shows pending dependency state', (tester) async {
    final api = CompatibilityApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(_state(status: 'pending'))),
          200,
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: CompatibilityScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compatibility_pending')), findsOneWidget);
    expect(find.text('애착 요약 1/2명'), findsOneWidget);
  });

  testWidgets('renders ready compatibility without member scores', (
    tester,
  ) async {
    final api = CompatibilityApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(_state(status: 'ready'))),
          200,
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: CompatibilityScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compatibility_ready')), findsOneWidget);
    expect(find.text('차이 30점'), findsOneWidget);
  });
}
