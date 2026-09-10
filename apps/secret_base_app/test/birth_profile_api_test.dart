import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/birth_profile_api.dart';

void main() {
  test('loads the authenticated user birth profile', () async {
    late http.Request captured;
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ok":true,"birthProfile":{"calendarType":"lunar",'
          '"birthDate":"1999-12-31","lunarLeapMonth":true,'
          '"birthTime":"23:05:00",'
          '"timezone":"Asia/Tokyo","birthPlace":"서울특별시"}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final profile = await api.fetch();

    expect(captured.method, 'GET');
    expect(
      captured.url,
      Uri.parse('https://secretbase.example/api/relationship/birth-profile'),
    );
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(profile.calendarType, BirthCalendarType.lunar);
    expect(profile.lunarLeapMonth, isTrue);
    expect(profile.birthTime, '23:05:00');
    expect(profile.birthPlace, '서울특별시');
  });

  test('updates the authenticated user birth profile', () async {
    late http.Request captured;
    final api = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ok":true,"birthProfile":{"calendarType":"solar",'
          '"birthDate":"2000-01-01","lunarLeapMonth":false,"birthTime":null,'
          '"timezone":"Asia/Seoul","birthPlace":null}}',
          200,
        );
      }),
    );

    final profile = await api.update(
      const BirthProfileInput(
        calendarType: BirthCalendarType.solar,
        birthDate: '2000-01-01',
        lunarLeapMonth: false,
        timezone: 'Asia/Seoul',
      ),
    );

    expect(captured.method, 'PATCH');
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(jsonDecode(captured.body), {
      'calendarType': 'solar',
      'birthDate': '2000-01-01',
      'lunarLeapMonth': false,
      'birthTime': null,
      'timezone': 'Asia/Seoul',
      'birthPlace': null,
    });
    expect(profile.birthDate, '2000-01-01');
  });

  test('exposes validation reasons and network failures', () async {
    final validationApi = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient(
        (_) async =>
            http.Response('{"ok":false,"reason":"invalid_timezone"}', 400),
      ),
    );

    expect(
      () => validationApi.fetch(),
      throwsA(
        isA<BirthProfileApiException>().having(
          (BirthProfileApiException error) => error.reason,
          'reason',
          'invalid_timezone',
        ),
      ),
    );

    final networkApi = BirthProfileApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(
      () => networkApi.fetch(),
      throwsA(
        isA<BirthProfileApiException>().having(
          (BirthProfileApiException error) => error.reason,
          'reason',
          'network_error',
        ),
      ),
    );
  });
}
