import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/birth_profile_api.dart';
import 'package:secret_base_app/screens/relationship/relationship_understanding_screen.dart';

const _profileResponse =
    '{"ok":true,"birthProfile":{"calendarType":"solar",'
    '"birthDate":"2000-01-01","birthTime":null,'
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
        MaterialApp(home: RelationshipUnderstandingScreen(api: api)),
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
        MaterialApp(home: RelationshipUnderstandingScreen(api: api)),
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
      MaterialApp(home: RelationshipUnderstandingScreen(api: api)),
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

  testWidgets('hub keeps personal area available and explains missing couple', (
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
    expect(find.text('커플 영역은 잠겨 있어요'), findsOneWidget);
    expect(find.text('진행 중인 검사가 있어요'), findsOneWidget);
  });
}
