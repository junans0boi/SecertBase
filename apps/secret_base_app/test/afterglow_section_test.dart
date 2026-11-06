import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/afterglow_api.dart';
import 'package:secret_base_app/screens/archive/afterglow_section.dart';
import 'package:secret_base_app/v2/v2.dart';

AfterglowContribution _slot(
  int id,
  String name, {
  bool done = false,
  bool deleted = false,
  String? caption,
  String? tag,
}) => AfterglowContribution(
  userId: id,
  userName: name,
  contributed: done,
  deleted: deleted,
  caption: caption,
  emotionTag: tag,
);

Future<void> _pump(
  WidgetTester tester,
  List<AfterglowContribution> contributions, {
  VoidCallback? onContribute,
  int? currentUserId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: V2Theme(
        child: Scaffold(
          body: SingleChildScrollView(
            child: AfterglowSection(
              baseUrl: 'https://example.test',
              onContribute: onContribute,
              currentUserId: currentUserId,
              state: AfterglowState(
                placeName: '카페',
                visit: const AfterglowVisit(
                  id: 1,
                  mapPinId: 2,
                  visitDate: '2026-07-29',
                ),
                contributions: contributions,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('title is Korean only and shows the visit date', (tester) async {
    await _pump(tester, [_slot(1, '나'), _slot(2, '서윤')]);
    expect(find.text('우리의 여운'), findsOneWidget);
    expect(find.textContaining('Afterglow'), findsNothing);
    expect(find.text('7월 29일에 다녀왔어요'), findsOneWidget);
  });

  testWidgets('nothing yet: explains and offers to write the first one', (
    tester,
  ) async {
    var tapped = 0;
    await _pump(tester, [
      _slot(1, '나'),
      _slot(2, '서윤'),
    ], onContribute: () => tapped++);

    expect(find.text('아직 아무도 남기지 않았어요'), findsOneWidget);
    expect(find.textContaining('서윤도 남기면'), findsOneWidget);
    expect(find.text('아직 없어요'), findsOneWidget);
    await tester.tap(find.text('첫 여운 남기기'));
    expect(tapped, 1);
  });

  testWidgets('empty slot list is the same first-write state', (tester) async {
    await _pump(tester, const [], onContribute: () {});
    expect(find.text('아직 아무도 남기지 않았어요'), findsOneWidget);
    expect(find.text('첫 여운 남기기'), findsOneWidget);
  });

  testWidgets('I wrote: my scene is open, partner slot waits', (tester) async {
    await _pump(tester, [
      _slot(1, '나', done: true, caption: '또 걷고 싶어', tag: '포근함'),
      _slot(2, '서윤'),
    ], onContribute: () {});

    expect(find.text('또 걷고 싶어'), findsOneWidget);
    expect(find.text('#포근함'), findsOneWidget);
    expect(find.text('서윤 기다리는 중'), findsOneWidget);
    expect(find.text('서윤의 여운을 기다리고 있어요'), findsOneWidget);
    expect(find.text('내 여운 다시 남기기'), findsOneWidget);
  });

  testWidgets('partner wrote: it is my turn and their scene stays closed', (
    tester,
  ) async {
    var tapped = 0;
    await _pump(tester, [
      _slot(1, '나'),
      _slot(2, '서윤', done: true, caption: '서윤의 비밀 문장'),
    ], onContribute: () => tapped++);

    expect(find.text('내 차례예요'), findsOneWidget);
    expect(find.text('서윤의 여운이 도착했어요'), findsOneWidget);
    expect(find.text('서윤의 비밀 문장'), findsNothing);
    await tester.tap(find.text('내 여운 남기기'));
    expect(tapped, 1);
  });

  testWidgets('both done: both scenes are opened', (tester) async {
    await _pump(tester, [
      _slot(1, '나', done: true, caption: '내 장면'),
      _slot(2, '서윤', done: true, caption: '서윤 장면'),
    ]);

    expect(find.text('함께 열렸어요'), findsOneWidget);
    expect(find.text('내 장면'), findsOneWidget);
    expect(find.text('서윤 장면'), findsOneWidget);
    expect(find.text('서윤의 여운'), findsOneWidget);
  });

  testWidgets('currentUserId decides which slot is mine', (tester) async {
    // Server lists me first; here the partner is listed first and the
    // caller is user 2 -> partner (user 1) wrote, my turn.
    await _pump(
      tester,
      [_slot(1, '서윤', done: true, caption: '숨김'), _slot(2, '나')],
      currentUserId: 2,
      onContribute: () {},
    );
    expect(find.text('내 차례예요'), findsOneWidget);
    expect(find.text('숨김'), findsNothing);
  });

  testWidgets('a deleted scene says so once both have written', (tester) async {
    await _pump(tester, [
      _slot(1, '나', done: true, caption: '내 장면'),
      _slot(2, '서윤', done: true, deleted: true),
    ]);
    expect(find.text('삭제된 순간이에요'), findsOneWidget);
    expect(find.text('내 장면'), findsOneWidget);
  });

  testWidgets('no action button without onContribute', (tester) async {
    await _pump(tester, [_slot(1, '나'), _slot(2, '서윤')]);
    expect(find.byType(V2Button), findsNothing);
  });
}
