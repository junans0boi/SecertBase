import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment.dart';
import 'package:secret_base_app/screens/archive/moment/moment_date_sheet.dart';
import 'package:secret_base_app/screens/archive/moment/moment_days.dart';

Moment _m(int id, int user, String day, String captured, {int pos = 0}) =>
    Moment(
      id: id,
      userId: user,
      takenAt: day,
      capturedAt: captured,
      sessionId: 's$id',
      position: pos,
    );

void main() {
  test('days group me and the partner, each in time order', () {
    final pages = buildMomentDayPages([
      _m(1, 7, '2025-11-09', '2025-11-09T05:00:00Z'),
      _m(2, 8, '2025-11-09', '2025-11-09T03:00:00Z'),
      _m(3, 7, '2025-11-09', '2025-11-09T01:00:00Z'),
      _m(4, 8, '2025-11-02', '2025-11-02T01:00:00Z'),
    ], 7);
    expect(pages.map((p) => p.day.day), [9, 2]);
    expect(pages.first.mine.map((m) => m.id), [3, 1]);
    expect(pages.first.theirs.map((m) => m.id), [2]);
    expect(pages.first.all.map((m) => m.id), [3, 2, 1]);
    expect(pages.first.count, 3);
    expect(pages.last.hasMine, isFalse);
  });

  test('date chip says why the day was picked', () {
    final now = DateTime(2025, 11, 12, 15);
    expect(
      momentDateChipLabel(DateTime(2025, 11, 12), now: now),
      '11월 12일 · 오늘',
    );
    expect(
      momentDateChipLabel(DateTime(2025, 11, 11), now: now),
      '11월 11일 · 어제',
    );
    expect(
      momentDateChipLabel(
        DateTime(2025, 11, 9),
        photoDate: DateTime(2025, 11, 9),
        now: now,
      ),
      '11월 9일 · 사진 찍은 날',
    );
    expect(momentDateChipLabel(DateTime(2025, 10, 3), now: now), '10월 3일');
  });
}
