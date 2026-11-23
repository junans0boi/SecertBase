import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/http/api_exception.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

/// dart2js에서는 `1 << 32`가 0이라 Random.nextInt가 RangeError를 던진다.
/// 웹에서도 안전한 상수(2^32)를 쓴다.
const int kRandomSuffixBound = 0x100000000;

String newClientRequestId({Random? random}) {
  final r = random ?? Random.secure();
  return 'n${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(kRandomSuffixBound).toRadixString(36)}';
}

int _fallbackSeq = 0;

/// 쪽지 대화 상태. 보내기는 먼저 큐에 넣고(client_request_id 고정) 네트워크 실패 시
/// 그대로 남겨 두었다가 다시 보낸다. 서버가 같은 id를 한 번만 만든다.
class NotesController extends ChangeNotifier {
  final NotesRepository repository;
  final String Function() requestId;
  final DateTime Function() now;

  NotesController({
    required this.repository,
    String Function()? requestId,
    DateTime Function()? now,
  }) : requestId = requestId ?? newClientRequestId,
       now = now ?? DateTime.now;

  final Map<int, Note> _byId = {};
  final List<PendingNote> _pending = [];
  bool loading = false;
  bool loadingMore = false;
  bool loadFailed = false;
  int unread = 0;
  int? _nextBefore;
  bool _visible = true;
  bool _disposed = false;
  bool _flushing = false;

  bool get hasMore => _nextBefore != null;

  /// 오래된 것이 위, 최신이 아래.
  List<Note> get notes {
    final list = _byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  List<PendingNote> get pending => List.unmodifiable(_pending);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 화면이 앞에 있을 때만 받은 쪽지를 읽음 처리한다.
  void setVisible(bool visible) {
    _visible = visible;
    if (visible) markRead();
  }

  Future<void> load() async {
    loading = true;
    loadFailed = false;
    _notify();
    try {
      final page = await repository.list();
      for (final n in page.notes) {
        _byId[n.id] = n;
      }
      _nextBefore = page.nextBefore;
      unread = page.unreadCount;
    } catch (_) {
      loadFailed = true;
    } finally {
      loading = false;
      _notify();
    }
    if (!loadFailed) {
      await markRead();
      await flushPending();
    }
  }

  Future<void> loadMore() async {
    final before = _nextBefore;
    if (before == null || loadingMore) return;
    loadingMore = true;
    _notify();
    try {
      final page = await repository.list(before: before);
      for (final n in page.notes) {
        _byId.putIfAbsent(n.id, () => n);
      }
      _nextBefore = page.nextBefore;
    } catch (_) {
      // 다음 스크롤에서 다시 시도한다.
    } finally {
      loadingMore = false;
      _notify();
    }
  }

  Future<void> markRead() async {
    if (!_visible) return;
    final incoming = _byId.values
        .where((n) => !n.mine && n.status == NoteStatus.visible && !n.isRead)
        .map((n) => n.id);
    if (unread == 0 && incoming.isEmpty) return;
    final upTo = incoming.isEmpty
        ? (_byId.keys.fold(0, max))
        : incoming.reduce(max);
    if (upTo == 0) return;
    try {
      unread = await repository.markRead(upTo);
      for (final n in _byId.values.toList()) {
        if (!n.mine && n.id <= upTo && !n.isRead) {
          _byId[n.id] = n.copyWith(readAt: now());
        }
      }
    } catch (_) {
      // 읽음 표시는 다음 기회에 다시 보낸다.
    }
    _notify();
  }

  Future<void> send(
    String body, {
    DateTime? openAt,
    NotePhoto? photo,
    int? mapPinId,
    int? setlogPostId,
  }) async {
    final text = body.trim();
    if (text.isEmpty &&
        photo == null &&
        mapPinId == null &&
        setlogPostId == null) {
      return;
    }
    String id;
    try {
      id = requestId();
    } catch (_) {
      // id 생성이 실패해도 글을 잃지 않는다: 대체 id로 큐에 넣고 실패 말풍선을 남긴다.
      id = 'n${now().microsecondsSinceEpoch}-f${_fallbackSeq++}';
      _pending.add(
        PendingNote(
          clientRequestId: id,
          body: text,
          openAt: openAt,
          photo: photo,
          mapPinId: mapPinId,
          setlogPostId: setlogPostId,
          failed: true,
        ),
      );
      _notify();
      return;
    }
    _pending.add(
      PendingNote(
        clientRequestId: id,
        body: text,
        openAt: openAt,
        photo: photo,
        mapPinId: mapPinId,
        setlogPostId: setlogPostId,
      ),
    );
    _notify();
    await flushPending();
  }

  bool _isRetryable(Object error) {
    if (error is ApiException) {
      final code = error.statusCode;
      return code == null || code >= 500 || code == 429;
    }
    return true;
  }

  String _reasonText(Object error) {
    final code = error is ApiException ? error.code : '';
    return switch (code) {
      'active_couple_required' => '연결이 해제되어 보낼 수 없어요',
      'open_at_not_future' => '열리는 시각이 이미 지났어요',
      'reference_not_found' => '첨부한 장소나 순간을 찾을 수 없어요',
      'note_too_long' => '쪽지가 너무 길어요',
      'invalid_media' || 'media_too_large' => '사진을 보낼 수 없어요',
      _ => '보내지 못했어요',
    };
  }

  /// 순서대로 한 통씩 보낸다. 실패한 것은 남겨 두고(재시도 가능) 영구 거부는 표시만 한다.
  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      for (var i = 0; i < _pending.length; i++) {
        final item = _pending[i];
        if (item.error != null) continue; // 영구 거부: 사용자가 다시 보내기/지우기 할 때까지
        try {
          final note = await repository.send(item);
          _byId[note.id] = note;
          _pending.removeAt(i);
          i--;
        } catch (error) {
          final retryable = _isRetryable(error);
          _pending[i] = item.copyWith(
            failed: true,
            error: retryable ? null : _reasonText(error),
          );
          if (retryable) break; // 순서를 지키려고 네트워크가 돌아올 때까지 멈춘다.
        }
      }
    } finally {
      _flushing = false;
      _notify();
    }
  }

  /// 사용자가 다시 보내기를 눌렀다.
  Future<void> retry(String clientRequestId) async {
    final i = _pending.indexWhere((p) => p.clientRequestId == clientRequestId);
    if (i < 0) return;
    _pending[i] = PendingNote(
      clientRequestId: clientRequestId,
      body: _pending[i].body,
      openAt: _pending[i].openAt,
      photo: _pending[i].photo,
      mapPinId: _pending[i].mapPinId,
      setlogPostId: _pending[i].setlogPostId,
    );
    _notify();
    await flushPending();
  }

  void discardPending(String clientRequestId) {
    _pending.removeWhere((p) => p.clientRequestId == clientRequestId);
    _notify();
  }

  Future<void> react(Note note, String? emoji) async {
    final next = note.reaction == emoji ? null : emoji;
    try {
      _byId[note.id] = await repository.react(note.id, next);
      _notify();
    } catch (_) {
      // 반응은 실패해도 대화를 막지 않는다.
    }
  }

  Future<bool> delete(Note note) async {
    try {
      await repository.delete(note.id);
      _byId[note.id] = note.copyWith(status: NoteStatus.deleted);
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 소켓 이벤트: 서버가 활성 Couple 상대에게만 보낸다.
  void applyEvent(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'note:new':
        final raw = data['note'];
        if (raw is! Map) return;
        final note = Note.fromJson(Map<String, dynamic>.from(raw));
        _byId[note.id] = note;
        if (!note.mine && note.status == NoteStatus.visible) {
          unread += 1;
          if (_visible) markRead();
        }
      case 'note:read':
        final upTo = (data['up_to_id'] as num?)?.toInt() ?? 0;
        final at = DateTime.tryParse('${data['read_at']}')?.toLocal() ?? now();
        for (final n in _byId.values.toList()) {
          if (n.mine && n.id <= upTo && !n.isRead) {
            _byId[n.id] = n.copyWith(readAt: at);
          }
        }
      case 'note:deleted':
        final id = (data['id'] as num?)?.toInt();
        final n = id == null ? null : _byId[id];
        if (n != null) _byId[n.id] = n.copyWith(status: NoteStatus.deleted);
      case 'note:reaction':
        final id = (data['id'] as num?)?.toInt();
        final n = id == null ? null : _byId[id];
        if (n != null) {
          _byId[n.id] = n.copyWith(reaction: data['reaction'] as String?);
        }
    }
    _notify();
  }
}
