import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/afterglow_api.dart';
import 'package:secret_base_app/screens/archive/afterglow_section.dart';

void main() {
  testWidgets('Afterglow renders contributed, empty, and deleted slots', (
    tester,
  ) async {
    Future<void> pump(List<AfterglowContribution> contributions) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AfterglowSection(
              baseUrl: 'https://example.test',
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
      );
    }

    await pump(const [
      AfterglowContribution(
        userId: 1,
        userName: '나',
        contributed: true,
        deleted: false,
        caption: '또 걷고 싶어',
        emotionTag: '포근함',
      ),
      AfterglowContribution(
        userId: 2,
        userName: '상대',
        contributed: false,
        deleted: false,
      ),
    ]);
    expect(find.text('우리의 여운'), findsOneWidget);
    expect(find.text('또 걷고 싶어'), findsOneWidget);
    expect(find.text('#포근함'), findsOneWidget);
    expect(find.text('아직 남긴 장면이 없어요'), findsOneWidget);

    await pump(const [
      AfterglowContribution(
        userId: 1,
        userName: '나',
        contributed: false,
        deleted: false,
      ),
      AfterglowContribution(
        userId: 2,
        userName: '상대',
        contributed: false,
        deleted: false,
      ),
    ]);
    expect(find.text('아직 남긴 장면이 없어요'), findsNWidgets(2));

    await pump(const [
      AfterglowContribution(
        userId: 1,
        userName: '나',
        contributed: true,
        deleted: false,
        caption: '내 장면',
      ),
      AfterglowContribution(
        userId: 2,
        userName: '상대',
        contributed: true,
        deleted: false,
        caption: '상대 장면',
      ),
    ]);
    expect(find.text('내 장면'), findsOneWidget);
    expect(find.text('상대 장면'), findsOneWidget);

    await pump(const [
      AfterglowContribution(
        userId: 1,
        userName: '나',
        contributed: true,
        deleted: true,
      ),
    ]);
    expect(find.text('삭제된 순간이에요'), findsOneWidget);
  });
}
