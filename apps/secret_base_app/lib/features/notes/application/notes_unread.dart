import 'package:flutter/foundation.dart';

import '../../../core/auth_service.dart';
import '../data/notes_repository.dart';
import 'notes_events.dart';

/// 홈 상단 쪽지 진입의 "읽지 않은 수 점". 서버 값과 소켓 이벤트로만 갱신한다.
class NotesUnread extends ChangeNotifier {
  final NotesRepository? repository;
  final NotesEventSource? events;
  VoidCallback? _unsubscribe;
  int count = 0;
  bool _disposed = false;

  NotesUnread({this.repository, this.events});

  /// 로그인 전이면 아무것도 하지 않는다.
  factory NotesUnread.forAuth(AuthService auth) {
    if (auth.token == null) return NotesUnread();
    return NotesUnread(
      repository: HttpNotesRepository(auth.apiClient),
      events: socketNotesEvents,
    );
  }

  bool get hasUnread => count > 0;

  Future<void> start() async {
    final source = events;
    if (source != null && _unsubscribe == null) {
      _unsubscribe = source((event, data) {
        if (event == 'note:new') {
          final note = data['note'];
          if (note is Map &&
              note['mine'] != true &&
              note['status'] == 'visible') {
            count += 1;
            _notify();
          }
        } else if (event == 'note:deleted') {
          refresh();
        }
      });
    }
    await refresh();
  }

  Future<void> refresh() async {
    final repo = repository;
    if (repo == null) return;
    try {
      count = await repo.unreadCount();
      _notify();
    } catch (_) {
      // 점은 보조 표시이므로 실패하면 이전 값을 유지한다.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _unsubscribe?.call();
    super.dispose();
  }
}
