import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/assessment_catalog_api.dart';
import 'package:secret_base_app/core/birth_profile_api.dart';
import 'package:secret_base_app/screens/relationship/relationship_understanding_screen.dart';
import 'package:secret_base_app/screens/relationship/saju_screen.dart';
import 'package:secret_base_app/screens/relationship/tarot_screen.dart';

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
    expect(find.byKey(const Key('relationship_fortune_area')), findsNothing);
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
    expect(find.text('저장된 답변부터 이어서 마무리할 수 있어요.'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('커플'), findsOneWidget);
    expect(find.text('진행 중인 검사가 있어요'), findsOneWidget);
  });

  testWidgets('uses the injected disconnected couple state in the hub', (
    tester,
  ) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => http.Response(_profileResponse, 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipUnderstandingScreen(api: api, hasActiveCouple: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('relationship_couple_restricted')),
      findsOneWidget,
    );
    await tester.tap(find.text('커플'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('relationship_couple_area')), findsNothing);
  });

  testWidgets('uses the injected connected couple state in the hub', (
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

    expect(
      find.byKey(const Key('relationship_couple_restricted')),
      findsNothing,
    );
    await tester.tap(find.text('커플'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('relationship_couple_area')), findsOneWidget);
  });

  testWidgets('does not show a connection CTA while couple status is unknown', (
    tester,
  ) async {
    final firstLookup = Completer<http.Response>();
    var lookupCount = 0;
    final coupleClient = MockClient((_) async {
      lookupCount += 1;
      if (lookupCount == 1) return firstLookup.future;
      return http.Response('{"ok":true}', 200);
    });
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => http.Response(_profileResponse, 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipUnderstandingScreen(
          api: api,
          coupleInfoClient: coupleClient,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('relationship_couple_check_state')),
      findsOneWidget,
    );
    expect(find.text('파트너 연결하기'), findsNothing);

    firstLookup.complete(http.Response('not available', 503));
    await tester.pumpAndSettle();
    expect(find.text('커플 연결 상태를 확인하지 못했어요'), findsOneWidget);
    expect(find.text('파트너 연결하기'), findsNothing);

    await tester.ensureVisible(find.text('다시 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('커플'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('relationship_couple_area')), findsOneWidget);
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
    expect(find.text('검사 시작하기'), findsOneWidget);
    expect(find.text('커플 검사 확인하기'), findsNothing);

    await tester.tap(find.text('커플'));
    await tester.pumpAndSettle();

    expect(find.text('검사 시작하기'), findsNothing);
    expect(find.text('커플 검사 확인하기'), findsOneWidget);
  });

  testWidgets('announces the selected relationship scope tab', (tester) async {
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => http.Response(_profileResponse, 200)),
    );
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipUnderstandingScreen(api: api, hasActiveCouple: true),
      ),
    );
    await tester.pumpAndSettle();

    final personalTab = find.bySemanticsLabel(RegExp('개인 영역 탭'));
    expect(personalTab, findsOneWidget);
    expect(
      tester.getSemantics(personalTab),
      matchesSemantics(
        isSelected: true,
        hasSelectedState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.text('커플'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('커플 영역 탭'))),
      matchesSemantics(
        isSelected: true,
        hasSelectedState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('orders personal next actions before reflection content', (
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('relationship_mindcare_area')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    double top(Key key) => tester.getTopLeft(find.byKey(key)).dy;
    expect(
      top(const Key('relationship_personal_area')),
      lessThan(top(const Key('relationship_saju_area'))),
    );
    expect(
      top(const Key('relationship_saju_area')),
      lessThan(top(const Key('relationship_tarot_area'))),
    );
    expect(
      top(const Key('relationship_tarot_area')),
      lessThan(top(const Key('relationship_mindcare_area'))),
    );
    expect(find.byKey(const Key('relationship_status_action')), findsOneWidget);
    expect(find.text('검사 이어하기'), findsOneWidget);
  });

  testWidgets('explains the locked couple area and provides a connection CTA', (
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

    expect(
      find.byKey(const Key('relationship_couple_restricted')),
      findsOneWidget,
    );
    expect(find.text('파트너 연결하기'), findsOneWidget);
  });

  testWidgets('opens relationship-first Saju and Tarot from the couple tab', (
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
    await tester.tap(find.text('커플'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_couple_saju')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SajuScreen>(find.byType(SajuScreen)).relationshipFirst,
      isTrue,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open_couple_tarot')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_couple_tarot')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TarotScreen>(find.byType(TarotScreen)).relationshipFirst,
      isTrue,
    );
  });
}
