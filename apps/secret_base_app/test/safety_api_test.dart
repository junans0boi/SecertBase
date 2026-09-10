import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/mindcare_api.dart';
import 'package:secret_base_app/core/safety_location.dart';

void main() {
  test(
    'platform location provider falls back when location services are unavailable',
    () async {
      final location = await const PlatformSafetyLocationProvider().resolve();
      expect(location.permissionGranted, isFalse);
      expect(location.countryCode, isNull);
      expect(location.adminArea, isNull);
    },
  );

  test('mindcare API parses region-only safety resources', () async {
    final api = MindcareApi(
      baseUrl: 'https://secretbase.example',
      token: 'jwt-token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/relationship/mindcare/safety-resources');
        expect(request.url.queryParameters['permission'], 'granted');
        expect(request.url.queryParameters['country'], 'KR');
        expect(request.url.queryParameters['adminArea'], '서울특별시');
        return http.Response(
          jsonEncode({
            'ok': true,
            'resourceVersion': 'safety-kr-v1',
            'locationMode': 'region',
            'countryCode': 'KR',
            'adminArea': '서울특별시',
            'resources': [
              {'key': 'emergency', 'title': '지금 바로 도움', 'region': '서울특별시'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final result = await api.fetchSafetyResources(
      permissionGranted: true,
      countryCode: 'KR',
      adminArea: '서울특별시',
    );
    expect(result.locationMode, 'region');
    expect(result.resources.single.region, '서울특별시');
  });

  test(
    'mindcare safety confirmation sends only region fields and parses resources',
    () async {
      final api = MindcareApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/relationship/mindcare/sessions/7/safety',
          );
          expect(jsonDecode(request.body), {
            'safeNow': false,
            'locationPermission': 'granted',
            'countryCode': 'KR',
            'adminArea': '서울특별시',
          });
          return http.Response(
            jsonEncode({
              'ok': true,
              'session': {
                'id': 7,
                'status': 'safety_support',
                'currentState': 'safety',
                'userResponseCount': 1,
                'ownerOnly': true,
              },
              'messages': [],
              'choices': [],
              'nextQuestion': null,
              'safety': {'status': 'needs_immediate_help'},
              'resourceVersion': 'safety-kr-v1',
              'locationMode': 'region',
              'countryCode': 'KR',
              'adminArea': '서울특별시',
              'resources': [
                {
                  'key': 'emergency',
                  'title': '지금 바로 도움',
                  'description': '서울특별시에서 바로 도움을 요청하세요.',
                  'contact': '112 / 119',
                  'region': '서울특별시',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final conversation = await api.confirmSafety(
        id: 7,
        safeNow: false,
        permissionGranted: true,
        countryCode: 'KR',
        adminArea: '서울특별시',
      );
      expect(conversation.safetyStatus, 'needs_immediate_help');
      expect(conversation.safetyResources?.locationMode, 'region');
      expect(conversation.safetyResources?.adminArea, '서울특별시');
      expect(
        conversation.safetyResources?.resources.single.contact,
        '112 / 119',
      );
    },
  );
}
