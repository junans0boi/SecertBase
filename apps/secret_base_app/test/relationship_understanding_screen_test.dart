import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/birth_profile_api.dart';
import 'package:secret_base_app/core/fortune_api.dart';
import 'package:secret_base_app/core/tarot_api.dart';
import 'package:secret_base_app/screens/relationship/relationship_understanding_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _profile = {
  'ok': true,
  'birthProfile': {
    'calendarType': 'solar',
    'birthDate': '1995-03-02',
    'lunarLeapMonth': false,
    'birthTime': null,
    'timezone': 'Asia/Seoul',
    'birthPlace': null,
  },
};

BirthProfileApi _birthApi({
  Map<String, dynamic> profile = _profile,
  void Function(http.Request)? onRequest,
}) => BirthProfileApi(
  baseUrl: 'https://x.example',
  token: 't',
  client: MockClient((r) async {
    onRequest?.call(r);
    return _json(profile);
  }),
);

FortuneApi _fortuneApi() => FortuneApi(
  baseUrl: 'https://x.example',
  token: 't',
  client: MockClient(
    (_) async => _json({
      'ok': true,
      'date': '2026-09-14',
      'contentVersion': 'v1',
      'profileReady': true,
      'fortunes': {
        'personal': {
          'id': 1,
          'type': 'personal',
          'status': 'generated',
          'result': {
            'title': '차분하게 중심을 잡는 날',
            'summary': '서두르지 않으면 오늘은 잘 풀려요.',
            'signals': <String>[],
            'suggestion': '물을 한 잔 마셔요.',
          },
        },
        'relationship': {
          'id': 2,
          'type': 'relationship',
          'status': 'generated',
          'result': {
            'title': '천천히 맞춰 가는 날',
            'summary': '서로의 속도를 물어봐요.',
            'signals': <String>[],
            'suggestion': '고마운 일을 말해요.',
          },
        },
      },
    }),
  ),
);

TarotApi _tarotApi({bool drawn = true}) => TarotApi(
  baseUrl: 'https://x.example',
  token: 't',
  client: MockClient(
    (_) async => _json({
      'ok': true,
      'date': '2026-09-14',
      'catalogVersion': 'v1',
      'redrawAvailable': false,
      'personal': drawn
          ? {
              'scope': 'user',
              'drawn': true,
              'card': {
                'key': 'the_star',
                'title': '별',
                'orientation': 'upright',
                'plain': '희망을 천천히 꺼내 봐요.',
                'reflection': '오늘 바라는 건 무엇인가요?',
              },
            }
          : {
              'scope': 'user',
              'drawn': false,
              'drawRequired': true,
              'cards': [
                {'key': 'the_fool', 'position': 1},
              ],
            },
    }),
  ),
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('hub groups 오늘 / 알아가기 / 돌봄 with an always-visible help chip', (
    tester,
  ) async {
    await _pump(
      tester,
      RelationshipUnderstandingScreen(api: _birthApi(), hasActiveCouple: false),
    );
    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('알아가기'), findsOneWidget);
    expect(find.text('돌봄'), findsOneWidget);
    expect(find.text('도움이 필요하면'), findsOneWidget);
    expect(find.text('사주'), findsOneWidget);
    expect(find.text('심리검사'), findsOneWidget);
    expect(find.text('궁합'), findsOneWidget);
    expect(find.text('마음관리'), findsOneWidget);
    expect(find.text('준비됨'), findsOneWidget);
    expect(find.text('파트너 연결 후'), findsOneWidget);
    // Psychological tests never ask for birth information.
    expect(find.text('출생 정보 없이 바로 할 수 있어요'), findsOneWidget);
    expect(find.textContaining('상담사와 채팅'), findsNothing);
    expect(find.textContaining('전문 상담이 아니에요'), findsOneWidget);
  });

  testWidgets('hub shows birth info needed when the profile is empty', (
    tester,
  ) async {
    await _pump(
      tester,
      RelationshipUnderstandingScreen(
        api: _birthApi(
          profile: {
            'ok': true,
            'birthProfile': {
              'calendarType': 'solar',
              'birthDate': '',
              'lunarLeapMonth': false,
              'birthTime': null,
              'timezone': 'Asia/Seoul',
              'birthPlace': null,
            },
          },
        ),
        hasActiveCouple: false,
      ),
    );
    expect(find.text('출생 정보 필요'), findsOneWidget);
    // The assessment entry is still reachable.
    expect(find.text('심리검사'), findsOneWidget);
  });

  testWidgets(
    'today shows the fortune line and tarot card; 나/우리 toggles when paired',
    (tester) async {
      await _pump(
        tester,
        RelationshipUnderstandingScreen(
          api: _birthApi(),
          hasActiveCouple: true,
          fortuneApi: _fortuneApi(),
          tarotApi: _tarotApi(),
        ),
      );
      expect(find.text('차분하게 중심을 잡는 날'), findsOneWidget);
      expect(find.text('서두르지 않으면 오늘은 잘 풀려요.'), findsOneWidget);
      expect(find.text('별'), findsOneWidget);
      expect(find.text('나'), findsOneWidget);
      expect(find.text('우리'), findsOneWidget);
      await tester.tap(find.text('우리'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('천천히 맞춰 가는 날'), findsOneWidget);
      expect(find.text('연결됨'), findsOneWidget);
      expect(find.text('함께 하는 상담'), findsOneWidget);
    },
  );

  testWidgets('unpaired hub offers connection and hides the toggle', (
    tester,
  ) async {
    await _pump(
      tester,
      RelationshipUnderstandingScreen(
        api: _birthApi(),
        hasActiveCouple: false,
        fortuneApi: _fortuneApi(),
        tarotApi: _tarotApi(drawn: false),
      ),
    );
    expect(find.text('연결하기'), findsOneWidget);
    expect(find.text('우리'), findsNothing);
    expect(find.text('오늘의 한 장을 뽑아 보세요'), findsOneWidget);
  });

  testWidgets('today area fails alone and can retry', (tester) async {
    await _pump(
      tester,
      RelationshipUnderstandingScreen(
        api: _birthApi(),
        hasActiveCouple: false,
        fortuneApi: FortuneApi(
          baseUrl: 'https://x.example',
          token: 't',
          client: MockClient((_) async => _json({'ok': false}, 500)),
        ),
        tarotApi: TarotApi(
          baseUrl: 'https://x.example',
          token: 't',
          client: MockClient((_) async => _json({'ok': false}, 500)),
        ),
      ),
    );
    expect(find.text('오늘의 운세와 타로를 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('알아가기'), findsOneWidget);
    expect(find.text('심리검사'), findsOneWidget);
  });

  testWidgets('birth sheet: lunar adds 윤달, unknown time sends null, saves', (
    tester,
  ) async {
    Map<String, dynamic>? patched;
    await _pump(
      tester,
      RelationshipUnderstandingScreen(
        editBirthProfileOnly: true,
        api: _birthApi(
          onRequest: (r) {
            if (r.method == 'PATCH') {
              patched = jsonDecode(r.body) as Map<String, dynamic>;
            }
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('출생 정보'), findsWidgets);
    expect(find.text('양력'), findsOneWidget);
    expect(find.text('윤달이에요'), findsNothing);
    await tester.tap(find.text('음력'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('윤달이에요'), findsOneWidget);
    expect(find.text('시각을 몰라요'), findsWidgets);
    await tester.tap(find.text('저장하고 보기'));
    await tester.pumpAndSettle();
    expect(patched?['calendarType'], 'lunar');
    expect(patched?['birthTime'], isNull);
    expect(patched?['birthDate'], '1995-03-02');
  });

  testWidgets('birth sheet shows a readable error and keeps the sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      RelationshipUnderstandingScreen(
        editBirthProfileOnly: true,
        api: BirthProfileApi(
          baseUrl: 'https://x.example',
          token: 't',
          client: MockClient((r) async {
            if (r.method == 'PATCH') {
              return _json({'ok': false, 'reason': 'future_birth_date'}, 400);
            }
            return _json(_profile);
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하고 보기'));
    await tester.pumpAndSettle();
    expect(find.text('미래 날짜는 입력할 수 없어요.'), findsOneWidget);
    expect(find.text('저장하고 보기'), findsOneWidget);
  });

  testWidgets('entry card forwards taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelationshipEntryCard(
            status: RelationshipAssessmentStatus.notStarted,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('우리 이해 시작하기'));
    expect(tapped, isTrue);
  });
}
