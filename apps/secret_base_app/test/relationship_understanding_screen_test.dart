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
  testWidgets('loads and saves the birth profile from the relationship screen', (
    tester,
  ) async {
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
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(find.text('출생 프로필을 저장했어요.'), findsOneWidget);
    expect(requests.map((request) => request.method), ['GET', 'PATCH']);
  });

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
    final timezoneField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '시간대 (예: Asia/Seoul)',
    );
    await tester.enterText(timezoneField, 'not/a-timezone');
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(find.text('시간대 형식을 확인해주세요.'), findsOneWidget);
  });
}
