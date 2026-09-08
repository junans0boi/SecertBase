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
