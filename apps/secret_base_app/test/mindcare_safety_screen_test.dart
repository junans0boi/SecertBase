import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/mindcare_api.dart';
import 'package:secret_base_app/core/safety_location.dart';
import 'package:secret_base_app/screens/relationship/mindcare_screen.dart';

class _GrantedLocationProvider implements SafetyLocationProvider {
  @override
  Future<SafetyLocation> resolve() async => const SafetyLocation(
    permissionGranted: true,
    countryCode: 'KR',
    adminArea: '서울특별시',
  );
}

class _DeniedLocationProvider implements SafetyLocationProvider {
  @override
  Future<SafetyLocation> resolve() async => const SafetyLocation.denied();
}

void main() {
  testWidgets(
    'mindcare safety flow shows region resources without exposing coordinates',
    (tester) async {
      final requests = <http.Request>[];
      final api = MindcareApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST' &&
              request.url.path.endsWith('/sessions')) {
            return http.Response(
              jsonEncode({
                'ok': true,
                'session': {
                  'id': 7,
                  'status': 'safety_pending',
                  'currentState': 'safety',
                  'userResponseCount': 1,
                  'ownerOnly': true,
                },
                'messages': [
                  {
                    'id': 1,
                    'sequence': 1,
                    'role': 'assistant',
                    'content': '지금 안전한 곳에 있나요?',
                  },
                ],
                'choices': [
                  {'key': 'safe_now', 'label': '지금은 안전해요'},
                  {'key': 'need_help', 'label': '지금 도움이 필요해요'},
                ],
                'nextQuestion': {
                  'key': 'safety',
                  'text': '지금 안전한 곳에 있나요?',
                  'allowFreeText': false,
                },
                'safety': {'status': 'pending'},
              }),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/relationship/mindcare/sessions/7/safety',
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('latitude'), isFalse);
          expect(body.containsKey('longitude'), isFalse);
          expect(body['safeNow'], isFalse);
          expect(body['locationPermission'], 'granted');
          expect(body['countryCode'], 'KR');
          expect(body['adminArea'], '서울특별시');
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
                  'description': '서울특별시에서 즉시 도움을 요청하세요.',
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

      await tester.pumpWidget(
        MaterialApp(
          home: MindcareScreen(
            api: api,
            locationProvider: _GrantedLocationProvider(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('지금 도움이 필요해요'));
      await tester.pumpAndSettle();

      expect(find.text('서울특별시 기준 안내'), findsOneWidget);
      expect(find.text('112 / 119'), findsOneWidget);
      expect(requests, hasLength(2));
    },
  );

  testWidgets(
    'mindcare safety flow keeps general guidance when location is denied',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final requests = <http.Request>[];
      final api = MindcareApi(
        baseUrl: 'https://secretbase.example',
        token: 'jwt-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/sessions')) {
            return http.Response(
              jsonEncode({
                'ok': true,
                'session': {
                  'id': 8,
                  'status': 'safety_support',
                  'currentState': 'safety',
                  'userResponseCount': 1,
                  'ownerOnly': true,
                },
                'messages': [],
                'choices': [],
                'nextQuestion': null,
                'safety': {'status': 'needs_immediate_help'},
              }),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(
            request.url.path,
            '/api/relationship/mindcare/safety-resources',
          );
          expect(request.url.queryParameters['permission'], 'denied');
          return http.Response(
            jsonEncode({
              'ok': true,
              'resourceVersion': 'safety-kr-v1',
              'locationMode': 'general',
              'resources': [
                {
                  'key': 'emergency',
                  'title': '지금 바로 도움',
                  'description': '급하면 112 또는 119에 연락하세요.',
                  'contact': '112 / 119',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MindcareScreen(
            api: api,
            locationProvider: _DeniedLocationProvider(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('일반 안전 안내'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '일반 안전 안내. 위치 정보는 저장하지 않아요.',
        ),
        findsOneWidget,
      );
      expect(requests, hasLength(2));
      semantics.dispose();
    },
  );
}
