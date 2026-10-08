import 'package:flutter/foundation.dart';

import '../data/media_upload_service.dart';
import '../data/moment_loop_repository.dart';
import '../domain/moment.dart';

enum MomentLoopStatus { idle, loading, ready, failure }

class MomentLoopState {
  final MomentLoopStatus status;
  final DateTime? weekStart;
  final List<Moment> moments;
  final Object? error;
  final bool operationInProgress;
  final String? operationError;
  final MomentDraft? pendingDraft;

  const MomentLoopState({
    this.status = MomentLoopStatus.idle,
    this.weekStart,
    this.moments = const [],
    this.error,
    this.operationInProgress = false,
    this.operationError,
    this.pendingDraft,
  });
}

class MomentLoopAuthorizationException extends MomentLoopException {
  const MomentLoopAuthorizationException() : super('moment_author_required');
}

class MomentLoopController extends ChangeNotifier {
  final MomentLoopRepository repository;
  final int? Function()? currentUserId;

  MomentLoopState _state = const MomentLoopState();
  int _loadVersion = 0;
  bool _disposed = false;

  MomentLoopController({required this.repository, this.currentUserId});

  MomentLoopState get state => _state;

  Future<void> loadWeek(DateTime weekStart) async {
    final version = ++_loadVersion;
    _setState(
      MomentLoopState(
        status: MomentLoopStatus.loading,
        weekStart: weekStart,
        moments: _state.moments,
      ),
    );
    try {
      final moments = await repository.fetchFeed(weekStart);
      if (version != _loadVersion) return;
      _setState(
        MomentLoopState(
          status: MomentLoopStatus.ready,
          weekStart: weekStart,
          moments: List.unmodifiable(moments),
        ),
      );
    } catch (error) {
      if (version != _loadVersion) return;
      _setState(
        MomentLoopState(
          status: MomentLoopStatus.failure,
          weekStart: weekStart,
          moments: _state.moments,
          error: error,
        ),
      );
    }
  }

  Future<List<Moment>> createMoment(MomentDraft draft) async {
    _setState(
      MomentLoopState(
        status: _state.status,
        weekStart: _state.weekStart,
        moments: _state.moments,
        operationInProgress: true,
        pendingDraft: draft,
      ),
    );
    try {
      final created = await repository.create(draft);
      _setState(
        MomentLoopState(
          status: _state.status,
          weekStart: _state.weekStart,
          moments: _state.moments,
        ),
      );
      return created;
    } catch (error) {
      final mapped = mapMomentLoopError(error);
      _setState(
        MomentLoopState(
          status: _state.status,
          weekStart: _state.weekStart,
          moments: _state.moments,
          operationError: mapped.code,
          pendingDraft: draft,
        ),
      );
      throw mapped;
    }
  }

  Future<Moment> updateCaption(int id, String caption) async {
    _requireAuthor(id);
    try {
      final updated = await repository.updateCaption(id, caption);
      _replaceMoment(updated);
      return updated;
    } catch (error) {
      throw _recordOperationError(error);
    }
  }

  Future<void> deleteMoment(int id) async {
    _requireAuthor(id);
    try {
      await repository.delete(id);
      final moments = _state.moments
          .where((moment) => moment.id != id)
          .toList();
      _setState(
        MomentLoopState(
          status: _state.status,
          weekStart: _state.weekStart,
          moments: List.unmodifiable(moments),
        ),
      );
    } catch (error) {
      throw _recordOperationError(error);
    }
  }

  Future<List<MomentReaction>> toggleReaction({
    required String sessionId,
    required String emoji,
  }) async {
    try {
      final reactions = await repository.toggleReaction(
        sessionId: sessionId,
        emoji: emoji,
      );
      final moments = _state.moments.map((moment) {
        return moment.sessionKey == sessionId
            ? Moment(
                id: moment.id,
                userId: moment.userId,
                userName: moment.userName,
                mediaType: moment.mediaType,
                mediaUrl: moment.mediaUrl,
                caption: moment.caption,
                sessionId: moment.sessionId,
                takenAt: moment.takenAt,
                capturedAt: moment.capturedAt,
                mapPinId: moment.mapPinId,
                linkedPlaceName: moment.linkedPlaceName,
                todayLocked: moment.todayLocked,
                reactions: reactions,
                extra: moment.extra,
              )
            : moment;
      }).toList();
      _setState(
        MomentLoopState(
          status: _state.status,
          weekStart: _state.weekStart,
          moments: List.unmodifiable(moments),
        ),
      );
      return reactions;
    } catch (error) {
      throw _recordOperationError(error);
    }
  }

  Future<void> designateToday(int id) async {
    _requireAuthor(id);
    try {
      await repository.designateToday(id);
    } catch (error) {
      throw _recordOperationError(error);
    }
  }

  Future<void> removeTodayDesignation() async {
    try {
      await repository.removeTodayDesignation();
    } catch (error) {
      throw _recordOperationError(error);
    }
  }

  Future<List<MomentMapPin>> loadMapPins() => repository.fetchMapPins();

  Future<int> createMapPin(MomentMapPinDraft draft) =>
      repository.createMapPin(draft);

  void replaceReactions(String sessionId, List<Map<String, dynamic>> raw) {
    final reactions = raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return MomentReaction(
            userId: int.tryParse('${map['user_id']}'),
            emoji: '${map['emoji'] ?? ''}',
          );
        })
        .where((reaction) => reaction.emoji.isNotEmpty)
        .toList();
    final moments = _state.moments.map((moment) {
      if (moment.sessionKey != sessionId) return moment;
      return Moment(
        id: moment.id,
        userId: moment.userId,
        userName: moment.userName,
        mediaType: moment.mediaType,
        mediaUrl: moment.mediaUrl,
        caption: moment.caption,
        sessionId: moment.sessionId,
        takenAt: moment.takenAt,
        capturedAt: moment.capturedAt,
        mapPinId: moment.mapPinId,
        linkedPlaceName: moment.linkedPlaceName,
        todayLocked: moment.todayLocked,
        reactions: reactions,
        extra: moment.extra,
      );
    }).toList();
    _setState(
      MomentLoopState(
        status: _state.status,
        weekStart: _state.weekStart,
        moments: List.unmodifiable(moments),
      ),
    );
  }

  void _requireAuthor(int id) {
    final moment = _state.moments.where((item) => item.id == id).firstOrNull;
    final userId = currentUserId?.call();
    if (moment == null || userId == null || moment.userId != userId) {
      throw const MomentLoopAuthorizationException();
    }
  }

  void _replaceMoment(Moment updated) {
    final moments = _state.moments
        .map((moment) => moment.id == updated.id ? updated : moment)
        .toList();
    _setState(
      MomentLoopState(
        status: _state.status,
        weekStart: _state.weekStart,
        moments: List.unmodifiable(moments),
      ),
    );
  }

  MomentLoopException _recordOperationError(Object error) {
    final mapped = mapMomentLoopError(error);
    _setState(
      MomentLoopState(
        status: _state.status,
        weekStart: _state.weekStart,
        moments: _state.moments,
        operationError: mapped.code,
        pendingDraft: _state.pendingDraft,
      ),
    );
    return mapped;
  }

  void _setState(MomentLoopState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

extension on Iterable<Moment> {
  Moment? get firstOrNull => isEmpty ? null : first;
}
