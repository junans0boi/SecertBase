import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_catalog_api.dart';
import 'package:secret_base_app/core/birth_profile_api.dart';
import 'package:secret_base_app/screens/relationship/relationship_understanding_screen.dart';

const _profileResponse =
    '{"ok":true,"birthProfile":{"calendarType":"solar",'
    '"birthDate":"2000-01-01","lunarLeapMonth":false,"birthTime":null,'
    '"timezone":"Asia/Seoul","birthPlace":null}}';
const _emptyProfileResponse =
    '{"ok":true,"birthProfile":{"calendarType":"solar",'
    '"birthDate":"","lunarLeapMonth":false,"birthTime":null,'
    '"timezone":"Asia/Seoul","birthPlace":null}}';

void main() {
  testWidgets(
    'relationship entry card exposes each progress state and opens hub',
    (tester) async {
      var opened = 0;
      for (final testCase in [
        (RelationshipAssessmentStatus.profileIncomplete, '관계 이해 준비하기'),
        (RelationshipAssessmentStatus.notStarted, '관계 이해 시작하기'),
        (RelationshipAssessmentStatus.inProgress, '관계 이해 이어하기'),
        (RelationshipAssessmentStatus.resultReady, '관계 이해 결과 보기'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RelationshipEntryCard(
                status: testCase.$1,
                onTap: () => opened++,
              ),
            ),
          ),
        );
        expect(find.text(testCase.$2), findsOneWidget);
        await tester.tap(find.text(testCase.$2));
      }
      expect(opened, 4);
    },
  );

  testWidgets(
    'loads and saves the birth profile from the relationship screen',
    (tester) async {
      final requests = <http.Request>[];
      final api = BirthProfileApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            _profileResponse,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RelationshipUnderstandingScreen(
            api: api,
            editBirthProfileOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('출생 프로필'), findsOneWidget);
      expect(find.text('2000-01-01'), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, '저장하기').first;
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('출생 프로필을 저장했어요.'), findsOneWidget);
      expect(requests.map((request) => request.method), ['GET', 'PATCH']);
      expect(jsonDecode(requests.last.body)['lunarLeapMonth'], isFalse);
    },
  );

  testWidgets(
    'defaults the country to Korea and maps a selected country to its timezone',
    (tester) async {
      final requests = <http.Request>[];
      final api = BirthProfileApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            _profileResponse,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RelationshipUnderstandingScreen(
            api: api,
            editBirthProfileOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('대한민국'), findsOneWidget);
      final countryField = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(countryField);
      await tester.tap(countryField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('일본').last);
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, '저장하기').first;
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final payload = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(payload['timezone'], 'Asia/Tokyo');
      expect(payload['birthPlace'], isNull);
    },
  );

  testWidgets('shows a network error when the profile cannot be loaded', (
    tester,
  ) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    await tester.pumpWidget(
      MaterialApp(home: RelationshipUnderstandingScreen(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인하고 다시 시도해주세요.'), findsOneWidget);
  });

  testWidgets('shows a server validation error when saving the profile fails', (
    tester,
  ) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            _profileResponse,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"ok":false,"reason":"invalid_timezone"}', 400);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipUnderstandingScreen(
          api: api,
          editBirthProfileOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, '저장하기').first;
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('시간대 형식을 확인해주세요.'), findsOneWidget);
  });

  testWidgets('hides the saved birth profile form in the relationship hub', (
    tester,
  ) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => http.Response(_profileResponse, 200)),
    );

    await tester.pumpWidget(
      MaterialApp(home: RelationshipUnderstandingScreen(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.text('출생 프로필'), findsNothing);
    expect(find.text('관계 이해 허브'), findsWidgets);
    expect(find.byKey(const Key('relationship_personal_area')), findsOneWidget);
    expect(find.byKey(const Key('open_saju')), findsOneWidget);
    expect(find.byKey(const Key('open_tarot')), findsOneWidget);
  });

  testWidgets('shows result-ready status from the saved assessment catalog', (
    tester,
  ) async {
    final profileApi = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => http.Response(_profileResponse, 200)),
    );
    final catalogApi = AssessmentCatalogApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'assessments': [
                {
                  'code': 'attachment',
                  'audience': 'individual',
                  'title': '애착과 안정감',
                  'description': '검사 설명',
                  'version': 'v1',
                  'candidateQuestionCount': 24,
                  'activeQuestionCount': 12,
                  'completionStatus': 'completed',
                  'dimensions': const [],
                  'questions': const [],
                },
              ],
            }),
          ),
          200,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipUnderstandingScreen(
          api: profileApi,
          assessmentCatalogApi: catalogApi,
          assessmentStatus: RelationshipAssessmentStatus.notStarted,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('확인할 결과가 준비됐어요'), findsOneWidget);
  });

  testWidgets('shows the birth profile form when it is not saved', (
    tester,
  ) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async => http.Response(_emptyProfileResponse, 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: RelationshipUnderstandingScreen(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.text('출생 프로필'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '저장하기'), findsOneWidget);
  });

  testWidgets('hub keeps personal area available and locks the couple tab', (
    tester,
  ) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => http.Response(_profileResponse, 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipUnderstandingScreen(
          api: api,
          assessmentStatus: RelationshipAssessmentStatus.inProgress,
          hasActiveCouple: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('relationship_personal_area')), findsOneWidget);
    expect(find.text('파트너가 없어도 내 감정과 관계 패턴을 먼저 살펴볼 수 있어요.'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('커플'), findsOneWidget);
    expect(find.text('진행 중인 검사가 있어요'), findsOneWidget);
  });

  testWidgets('separates personal and couple areas with top tabs', (
    tester,
  ) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => http.Response(_profileResponse, 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipUnderstandingScreen(api: api, hasActiveCouple: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('개인'), findsOneWidget);
    expect(find.text('커플'), findsOneWidget);
    expect(find.text('개인 검사 보기'), findsOneWidget);
    expect(find.text('커플 검사 보기'), findsNothing);

    await tester.tap(find.text('커플'));
    await tester.pumpAndSettle();

    expect(find.text('개인 검사 보기'), findsNothing);
    expect(find.text('커플 검사 보기'), findsOneWidget);
  });
}
