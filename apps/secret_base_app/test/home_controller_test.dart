import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/today_api.dart';
import 'package:secret_base_app/features/home/application/home_controller.dart';
import 'package:secret_base_app/features/home/data/home_overview_repository.dart';
import 'package:secret_base_app/features/home/domain/home_overview.dart';

void main() {
  test('successful load exposes a ready typed overview', () async {
    final overview = _overview();
    final controller = HomeController(
      _FakeHomeRepository(() async => overview),
    );

    await controller.load();

    expect(controller.state.status, HomeStatus.ready);
    expect(controller.state.data, same(overview));
    expect(controller.state.data?.couple?.partnerName, 'partner');
  });

  test('an empty memory card is still a successful home load', () async {
    final controller = HomeController(
      _FakeHomeRepository(
        () async => _overview(includeMemoryCard: false, memoryCardTotal: 0),
      ),
    );

    await controller.load();

    expect(controller.state.status, HomeStatus.ready);
    expect(controller.state.data?.memoryCard, isNull);
    expect(controller.state.data?.failedSections, isEmpty);
  });

  test(
    'a Today failure keeps the rest of Home available as partial state',
    () async {
      final controller = HomeController(
        _FakeHomeRepository(
          () async =>
              _overview(todayState: null, failedSections: {HomeSection.today}),
        ),
      );

      await controller.load();

      expect(controller.state.status, HomeStatus.partial);
      expect(controller.state.data?.todayLoadFailed, isTrue);
      expect(controller.state.data?.couple?.partnerName, 'partner');
    },
  );

  test('all section failure becomes a retryable failure state', () async {
    final controller = HomeController(
      _FakeHomeRepository(
        () async => throw const HomeRepositoryException({
          HomeSection.couple,
          HomeSection.memory,
          HomeSection.assessments,
          HomeSection.today,
        }),
      ),
    );

    await controller.load();

    expect(controller.state.status, HomeStatus.failure);
    expect(controller.state.error, isA<HomeRepositoryException>());
  });

  test(
    'retry replaces a failed state with the next successful result',
    () async {
      var attempts = 0;
      final controller = HomeController(
        _FakeHomeRepository(() async {
          attempts++;
          if (attempts == 1) {
            throw const HomeRepositoryException({HomeSection.today});
          }
          return _overview();
        }),
      );

      await controller.load();
      expect(controller.state.status, HomeStatus.failure);

      await controller.refresh();
      expect(controller.state.status, HomeStatus.ready);
      expect(attempts, 2);
    },
  );

  test('a stale load cannot overwrite a newer refresh', () async {
    final first = Completer<HomeOverview>();
    final second = Completer<HomeOverview>();
    var calls = 0;
    final controller = HomeController(
      _FakeHomeRepository(() {
        calls++;
        return calls == 1 ? first.future : second.future;
      }),
    );

    final firstLoad = controller.load();
    final secondLoad = controller.refresh();
    second.complete(_overview(partnerName: 'newer'));
    await secondLoad;
    expect(controller.state.data?.couple?.partnerName, 'newer');

    first.complete(_overview(partnerName: 'stale'));
    await firstLoad;
    expect(controller.state.data?.couple?.partnerName, 'newer');
  });
}

class _FakeHomeRepository extends HomeOverviewRepository {
  final Future<HomeOverview> Function() _loader;

  _FakeHomeRepository(this._loader) : super.fake();

  @override
  Future<HomeOverview> fetch() => _loader();
}

HomeOverview _overview({
  String partnerName = 'partner',
  HomeMemoryCard? memoryCard,
  bool includeMemoryCard = true,
  int memoryCardTotal = 1,
  TodayState? todayState,
  Set<HomeSection> failedSections = const {},
}) {
  return HomeOverview(
    couple: HomeCoupleInfo(
      partnerName: partnerName,
      dDay: 12,
      startDate: '2026-01-01',
    ),
    memoryCard: includeMemoryCard
        ? memoryCard ??
              const HomeMemoryCard(
                yearsAgo: 1,
                placeName: 'place',
                caption: 'caption',
                mediaUrl: null,
              )
        : null,
    memoryCardTotal: memoryCardTotal,
    assessmentStatus: HomeAssessmentStatus.notStarted,
    todayState:
        todayState ??
        const TodayState(date: '2026-10-08', status: TodayStatus.empty),
    failedSections: failedSections,
  );
}
