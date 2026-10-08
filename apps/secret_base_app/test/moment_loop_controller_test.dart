import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/features/moment_loop/application/moment_loop_controller.dart';
import 'package:secret_base_app/features/moment_loop/data/moment_loop_repository.dart';
import 'package:secret_base_app/features/moment_loop/domain/moment.dart';

void main() {
  final week = DateTime(2026, 10, 5);

  test('feed success and empty feed become ready states', () async {
    final repository = FakeMomentLoopRepository(feed: const []);
    final controller = MomentLoopController(
      repository: repository,
      currentUserId: () => 1,
    );

    await controller.loadWeek(week);

    expect(controller.state.status, MomentLoopStatus.ready);
    expect(controller.state.moments, isEmpty);
    expect(repository.lastWeek, week);
  });

  test('feed error is retryable and retry can recover', () async {
    final repository = FakeMomentLoopRepository(
      feedError: const MomentLoopException('network_error'),
    );
    final controller = MomentLoopController(
      repository: repository,
      currentUserId: () => 1,
    );

    await controller.loadWeek(week);
    expect(controller.state.status, MomentLoopStatus.failure);

    repository.feedError = null;
    repository.feed = [_moment(id: 1, userId: 1)];
    await controller.loadWeek(week);

    expect(controller.state.status, MomentLoopStatus.ready);
    expect(controller.state.moments.single.id, 1);
  });

  test('author can edit and delete a moment', () async {
    final repository = FakeMomentLoopRepository(
      feed: [_moment(id: 1, userId: 1, caption: '처음')],
    );
    final controller = MomentLoopController(
      repository: repository,
      currentUserId: () => 1,
    );
    await controller.loadWeek(week);

    await controller.updateCaption(1, '수정');
    expect(controller.state.moments.single.caption, '수정');

    await controller.deleteMoment(1);
    expect(controller.state.moments, isEmpty);
    expect(repository.deletedIds, [1]);
  });

  test('partner cannot edit or delete an authored moment', () async {
    final repository = FakeMomentLoopRepository(
      feed: [_moment(id: 1, userId: 2)],
    );
    final controller = MomentLoopController(
      repository: repository,
      currentUserId: () => 1,
    );
    await controller.loadWeek(week);

    expect(
      () => controller.updateCaption(1, '수정'),
      throwsA(isA<MomentLoopAuthorizationException>()),
    );
    expect(
      () => controller.deleteMoment(1),
      throwsA(isA<MomentLoopAuthorizationException>()),
    );
    expect(repository.updatedIds, isEmpty);
    expect(repository.deletedIds, isEmpty);
  });

  test(
    'Today lock remains a domain error instead of being swallowed',
    () async {
      final repository = FakeMomentLoopRepository(
        feed: [_moment(id: 1, userId: 1)],
        designateError: const MomentLoopException('today_loop_locked'),
      );
      final controller = MomentLoopController(
        repository: repository,
        currentUserId: () => 1,
      );
      await controller.loadWeek(week);

      await expectLater(
        controller.designateToday(1),
        throwsA(
          isA<MomentLoopException>().having(
            (error) => error.code,
            'code',
            'today_loop_locked',
          ),
        ),
      );
      expect(controller.state.operationError, 'today_loop_locked');
    },
  );

  test('upload failure keeps the draft for retry', () async {
    final draft = MomentDraft(
      caption: '업로드할 순간',
      takenAt: DateTime(2026, 10, 8),
      capturedAt: DateTime(2026, 10, 8, 12),
      sessionId: 'session-1',
      todayMoment: true,
    );
    final repository = FakeMomentLoopRepository(
      createError: const MomentLoopException('upload_failed'),
    );
    final controller = MomentLoopController(
      repository: repository,
      currentUserId: () => 1,
    );

    await expectLater(
      controller.createMoment(draft),
      throwsA(
        isA<MomentLoopException>().having(
          (error) => error.code,
          'code',
          'upload_failed',
        ),
      ),
    );

    expect(controller.state.pendingDraft, same(draft));
    expect(controller.state.operationError, 'upload_failed');
  });
}

Moment _moment({required int id, required int userId, String caption = '순간'}) =>
    Moment(
      id: id,
      userId: userId,
      userName: userId == 1 ? '나' : '상대',
      mediaType: 'text',
      caption: caption,
      capturedAt: '2026-10-08T12:00:00.000Z',
      takenAt: '2026-10-08',
      sessionId: 'session-$id',
    );

class FakeMomentLoopRepository implements MomentLoopRepository {
  List<Moment> feed;
  Object? feedError;
  Object? createError;
  Object? designateError;
  DateTime? lastWeek;
  final List<int> updatedIds = [];
  final List<int> deletedIds = [];

  FakeMomentLoopRepository({
    List<Moment>? feed,
    this.feedError,
    this.createError,
    this.designateError,
  }) : feed = List.of(feed ?? const []);

  @override
  Future<List<Moment>> fetchFeed(DateTime weekStart) async {
    lastWeek = weekStart;
    final error = feedError;
    if (error != null) throw error;
    return List.of(feed);
  }

  @override
  Future<List<Moment>> create(MomentDraft draft) async {
    final error = createError;
    if (error != null) throw error;
    return const [];
  }

  @override
  Future<Moment> updateCaption(int id, String caption) async {
    updatedIds.add(id);
    final current = feed.singleWhere((moment) => moment.id == id);
    final updated = Moment(
      id: current.id,
      userId: current.userId,
      userName: current.userName,
      mediaType: current.mediaType,
      mediaUrl: current.mediaUrl,
      caption: caption,
      sessionId: current.sessionId,
      takenAt: current.takenAt,
      capturedAt: current.capturedAt,
      mapPinId: current.mapPinId,
      linkedPlaceName: current.linkedPlaceName,
      todayLocked: current.todayLocked,
      reactions: current.reactions,
      extra: current.extra,
    );
    feed = [updated];
    return updated;
  }

  @override
  Future<void> delete(int id) async => deletedIds.add(id);

  @override
  Future<List<MomentReaction>> toggleReaction({
    required String sessionId,
    required String emoji,
  }) async => [MomentReaction(emoji: emoji)];

  @override
  Future<void> designateToday(int postId) async {
    if (designateError != null) throw designateError!;
  }

  @override
  Future<void> removeTodayDesignation() async {}

  @override
  Future<List<MomentMapPin>> fetchMapPins() async => const [];

  @override
  Future<int> createMapPin(MomentMapPinDraft draft) async => 1;
}
