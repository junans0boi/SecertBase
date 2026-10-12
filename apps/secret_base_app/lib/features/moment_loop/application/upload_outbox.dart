import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/auth_service.dart';
import '../../../core/http/api_client.dart';
import '../../../core/http/api_exception.dart';
import '../data/media_upload_service.dart';
import '../data/outbox_store.dart';
import '../domain/moment.dart';
import '../domain/moment_edit.dart';

enum UploadDraftStatus { pending, uploading, failed, complete }

class UploadDraft {
  final String id;
  final String caption;
  final UploadDraftStatus status;
  final String? error;
  final int uploadedCount;
  final int fileCount;
  final bool isEdit;

  UploadDraft(Map<String, dynamic> record)
    : id = record['id'] as String,
      caption = record['caption'] as String,
      status = UploadDraftStatus.values.byName(record['status'] as String),
      error = record['error'] as String?,
      uploadedCount = (record['items'] as List)
          .where((i) => i['post'] != null)
          .length,
      fileCount = (record['items'] as List).length,
      isEdit = record['original'] != null;
}

/// A process-wide worker. UI lifetime and HTTP completion are independent.
/// Files and checkpoints survive process death; tokens are never persisted.
class UploadOutbox extends ChangeNotifier {
  static final UploadOutbox instance = _forAuth();

  static UploadOutbox _forAuth() {
    final auth = AuthService();
    int? userId() =>
        int.tryParse('${auth.user?['UserId'] ?? auth.user?['id']}');
    return UploadOutbox(
      store: createOutboxStore(),
      apiClient: auth.apiClient,
      currentUserId: userId,
      currentScope: () => '${auth.user?['RoomCode'] ?? ''}',
      canUpload: () =>
          auth.token?.isNotEmpty == true &&
          '${auth.user?['RoomCode'] ?? ''}'.isNotEmpty,
    );
  }

  final OutboxStore store;
  final ApiClient apiClient;
  final int? Function() currentUserId;
  final String Function()? currentScope;
  final bool Function()? canUpload;
  final ValueNotifier<int> feedRevision = ValueNotifier(0);
  Future<void> Function(String draftId)? failureNotifier;
  final Map<String, Map<String, dynamic>> _records = {};
  Future<void>? _initializing;
  Future<void>? _running;
  bool _disposed = false;

  UploadOutbox({
    required this.store,
    required this.apiClient,
    required this.currentUserId,
    this.currentScope,
    this.canUpload,
    this.failureNotifier,
  });

  String get _scope => currentScope?.call() ?? 'user:${currentUserId()}';
  bool get _ready => currentUserId() != null && (canUpload?.call() ?? true);
  bool _owns(Map<String, dynamic> record) =>
      record['user_id'] == currentUserId() && record['scope'] == _scope;

  List<UploadDraft> get drafts => List.unmodifiable(
    _records.values
        .where((r) => _owns(r) && r['status'] != 'complete')
        .map(UploadDraft.new),
  );

  Future<void> initialize() => _initializing ??= () async {
    for (final record in await store.load()) {
      _records[record['id'] as String] = record;
    }
    for (final record in _records.values.where((r) => r['status'] == 'complete').toList()) {
      await _cleanupCompleted(record);
    }
    _changed();
  }();

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Returns after durable local writes. The caller can now close the editor.
  /// Call resume without awaiting it to start network work.
  Future<String> enqueue(MomentDraft draft) async {
    await initialize();
    final owner = currentUserId();
    if (owner == null) throw const MomentLoopException('unauthorized');
    final id = newId();
    final items = <Map<String, dynamic>>[];
    for (final media in draft.media) {
      final key = newId();
      await store.writeMedia(key, media.bytes);
      items.add({'key': key, 'name': media.name, 'is_video': media.isVideo});
    }
    if (items.isEmpty) items.add({'key': newId(), 'name': null});
    final record = <String, dynamic>{
      'id': id,
      'user_id': owner,
      'scope': _scope,
      'status': 'pending',
      'caption': draft.caption,
      'taken_at': draft.takenAt.toIso8601String(),
      'captured_at': draft.capturedAt.toIso8601String(),
      'session_id': draft.sessionId,
      'today_moment': draft.todayMoment,
      'map_pin_id': draft.mapPinId,
      'items': items,
      'tags': draft.tags,
    };
    await store.save(id, record);
    _records[id] = record;
    _changed();
    return id;
  }

  Future<String> enqueueEdit(MomentEdit edit) async {
    await initialize();
    if (edit.original.isEmpty ||
        edit.original.any((p) => p.userId != currentUserId())) {
      throw const MomentLoopException('moment_author_required');
    }
    final session = edit.original.first.sessionId ?? '';
    if (edit.original.any((p) => (p.sessionId ?? '') != session) ||
        edit.fields.sessionId != session) {
      throw const MomentLoopException('session_id_immutable');
    }
    final retainedIds = edit.items
        .where((i) => i.post != null)
        .map((i) => i.post!.id)
        .toList();
    if (retainedIds.toSet().length != retainedIds.length ||
        retainedIds.any((id) => !edit.original.any((p) => p.id == id))) {
      throw const MomentLoopException('invalid_order');
    }
    final removed = edit.original
        .where((p) => !retainedIds.contains(p.id))
        .map((p) => p.id)
        .toList();
    final additions = edit.items.where((i) => i.media != null).toList();
    if (edit.original.any((p) => p.mediaEditLocked)) {
      if (removed.isNotEmpty || additions.isNotEmpty) {
        throw const MomentLoopException('today_loop_locked');
      }
      final oldDate = DateTime.tryParse(edit.original.first.takenAt ?? '');
      if (oldDate != null &&
          _dateOnly(oldDate) != _dateOnly(edit.fields.takenAt)) {
        throw const MomentLoopException('today_loop_date_locked');
      }
    }
    if (session.isEmpty &&
        (removed.isNotEmpty ||
            additions.isNotEmpty ||
            edit.original.length != 1)) {
      throw const MomentLoopException('legacy_media_edit_unavailable');
    }
    final id = newId();
    final items = <Map<String, dynamic>>[];
    for (final item in edit.items) {
      if (item.post != null) {
        items.add({
          'key': 'post_${item.post!.id}',
          'post': item.post!.toLegacyMap(),
        });
      } else {
        final key = newId();
        await store.writeMedia(key, item.media!.bytes);
        items.add({
          'key': key,
          'name': item.media!.name,
          'is_video': item.media!.isVideo,
        });
      }
    }
    if (items.isEmpty) items.add({'key': newId(), 'name': null});
    final record = <String, dynamic>{
      'id': id,
      'user_id': currentUserId(),
      'scope': _scope,
      'status': 'pending',
      'caption': edit.fields.caption,
      'taken_at': edit.fields.takenAt.toIso8601String(),
      'captured_at': edit.fields.capturedAt.toIso8601String(),
      'session_id': session,
      'today_moment': false,
      'map_pin_id': edit.fields.mapPinId,
      'tags': edit.fields.tags,
      'items': items,
      'original': edit.original.map((p) => p.toLegacyMap()).toList(),
      'remove': removed,
      'deleted': <int>[],
    };
    await store.save(id, record);
    _records[id] = record;
    _changed();
    return id;
  }

  Future<MomentDraft?> readDraft(String id) async {
    await initialize();
    final record = _records[id];
    if (record == null || !_owns(record) || record['status'] == 'complete') {
      return null;
    }
    final media = <MomentMedia>[];
    for (final item in (record['items'] as List).cast<Map>()) {
      if (item['name'] == null) continue;
      media.add(
        MomentMedia(
          name: item['name'] as String,
          bytes: await store.readMedia(item['key'] as String),
          isVideo: item['is_video'] == true,
          clientRequestId: item['key'] as String,
        ),
      );
    }
    return _draft(record, media: media);
  }

  Future<MomentEdit?> readEdit(String id) async {
    await initialize();
    final record = _records[id];
    if (record == null ||
        !_owns(record) ||
        record['original'] == null ||
        record['status'] == 'complete') {
      return null;
    }
    final draft = (await readDraft(id))!;
    final items = <MomentEditItem>[];
    for (final item in (record['items'] as List).cast<Map>()) {
      if (item['name'] != null) {
        items.add(
          MomentEditItem.added(
            draft.media.firstWhere((m) => m.clientRequestId == item['key']),
          ),
        );
      } else if (item['post'] != null) {
        items.add(
          MomentEditItem.existing(
            _storedMoment(Map<String, dynamic>.from(item['post'] as Map)),
          ),
        );
      }
    }
    return MomentEdit(
      original: (record['original'] as List)
          .map((r) => _storedMoment(Map<String, dynamic>.from(r as Map)))
          .toList(),
      fields: draft,
      items: items,
    );
  }

  Moment _storedMoment(Map<String, dynamic> raw) => Moment(
    id: int.parse('${raw['id']}'),
    userId: int.parse('${raw['user_id']}'),
    sessionId: raw['session_id'] as String?,
    caption: raw['caption'] as String?,
    takenAt: raw['taken_at'] as String?,
    capturedAt: raw['captured_at'] as String?,
    mediaType: raw['media_type'] as String?,
    mediaUrl: raw['media_url'] as String?,
    mapPinId: raw['map_pin_id'] as int?,
    linkedPlaceName: raw['linked_place_name'] as String?,
    position: raw['position'] as int? ?? 0,
    mediaEditLocked: raw['media_edit_locked'] == true,
    todayMoment: raw['today_moment'] == true,
    extra: raw,
  );

  /// Editing a failed draft retains its file keys and acknowledged rows.
  Future<void> replace(
    String id,
    MomentDraft draft, {
    List<MomentEditItem>? editItems,
  }) async {
    await initialize();
    final previous = _records[id];
    if (previous == null ||
        !_owns(previous) ||
        previous['status'] == 'complete') {
      throw const MomentLoopException('draft_not_found');
    }
    if (previous['status'] == 'uploading') {
      throw const MomentLoopException('draft_busy');
    }
    if (previous['session_id'] != draft.sessionId) {
      throw const MomentLoopException('session_id_immutable');
    }
    final record = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(previous)) as Map,
    );
    final previousItems = (record['items'] as List).cast<Map>();
    final requested =
        editItems ?? draft.media.map(MomentEditItem.added).toList();
    final items = <Map<String, dynamic>>[];
    for (final item in requested) {
      final key = item.post != null
          ? 'post_${item.post!.id}'
          : item.media!.clientRequestId;
      final matching = previousItems.where((i) => i['key'] == key).toList();
      if (matching.isNotEmpty) {
        items.add(Map<String, dynamic>.from(matching.single));
      } else if (item.media != null) {
        final newKey = newId();
        await store.writeMedia(newKey, item.media!.bytes);
        items.add({
          'key': newKey,
          'name': item.media!.name,
          'is_video': item.media!.isVideo,
        });
      } else {
        throw const MomentLoopException('invalid_order');
      }
    }
    if (items.isEmpty) {
      final oldText = previousItems
          .where((i) => i['name'] == null && i['post'] == null)
          .toList();
      items.add(
        oldText.isEmpty
            ? {'key': newId(), 'name': null}
            : Map<String, dynamic>.from(oldText.first),
      );
    }
    final removedPosts = previousItems
        .where(
          (i) => i['post'] != null && !items.any((n) => n['key'] == i['key']),
        )
        .map((i) => int.parse('${i['post']['id']}'))
        .toList();
    if (record['original'] != null) {
      final locked = (record['original'] as List).any(
        (p) => p['media_edit_locked'] == true,
      );
      if (locked &&
          (removedPosts.isNotEmpty ||
              items.any(
                (i) => !previousItems.any((p) => p['key'] == i['key']),
              ))) {
        throw const MomentLoopException('today_loop_locked');
      }
      if (locked &&
          _dateOnly(draft.takenAt) !=
              _dateOnly(DateTime.parse(record['taken_at'] as String))) {
        throw const MomentLoopException('today_loop_date_locked');
      }
    }
    record.addAll({
      'caption': draft.caption,
      'taken_at': draft.takenAt.toIso8601String(),
      'captured_at': draft.capturedAt.toIso8601String(),
      'map_pin_id': draft.mapPinId,
      'tags': draft.tags,
      'today_moment': draft.todayMoment,
      'status': 'pending',
      'error': null,
      'items': items,
      'needs_patch': true,
      'remove': {
        ...(record['remove'] as List? ?? []).cast<int>(),
        ...removedPosts,
      }.toList(),
      'deleted': record['deleted'] ?? <int>[],
    });
    await store.save(id, record);
    _records[id] = record;
    _changed();
  }

  MomentDraft _draft(
    Map<String, dynamic> record, {
    List<MomentMedia> media = const [],
  }) => MomentDraft(
    caption: record['caption'] as String,
    takenAt: DateTime.parse(record['taken_at'] as String),
    capturedAt: DateTime.parse(record['captured_at'] as String),
    sessionId: record['session_id'] as String,
    todayMoment: record['today_moment'] == true,
    mapPinId: record['map_pin_id'] as int?,
    media: media,
    tags: (record['tags'] as List? ?? ['#momentloop']).cast<String>(),
  );

  Future<void> start() => resume();

  /// Retry pending/interrupted/failed drafts once, with the current auth only.
  Future<void> resume() async {
    await initialize();
    if (_running != null) return _running!;
    if (!_ready) return;
    final running = _drain();
    _running = running;
    try {
      await running;
    } finally {
      _running = null;
    }
  }

  Future<void> retry(String id) async {
    await initialize();
    final record = _records[id];
    if (record == null || !_owns(record)) {
      throw const MomentLoopException('draft_not_found');
    }
    await resume();
  }

  Future<void> _drain() async {
    final attempted = <String>{};
    while (_ready && !_disposed) {
      final candidates = _records.values
          .where(
            (r) =>
                _owns(r) &&
                r['status'] != 'complete' &&
                !attempted.contains(r['id']),
          )
          .toList();
      if (candidates.isEmpty) return;
      final record = candidates.first;
      attempted.add(record['id'] as String);
      try {
        record['status'] = 'uploading';
        record['error'] = null;
        await _checkpoint(record);
        if (record['today_moment'] == true) {
          final today = DateTime.now().toUtc().add(const Duration(hours: 9));
          final selected = DateTime.parse(record['taken_at'] as String);
          if (selected.year != today.year ||
              selected.month != today.month ||
              selected.day != today.day) {
            throw const MomentLoopException('today_moment_wrong_date');
          }
        }
        final items = (record['items'] as List).cast<Map>();
        if (record['original'] != null) {
          final session = record['session_id'] as String;
          final path = session.isEmpty
              ? '/api/setlog/${(record['original'] as List).first['id']}'
              : '/api/setlog/session/${Uri.encodeComponent(session)}';
          await _patch(path, {
            'caption': record['caption'],
            'taken_at': _dateOnly(DateTime.parse(record['taken_at'] as String)),
            'tags': record['tags'],
            'map_pin_id': record['map_pin_id'],
            if (session.isEmpty) 'position': 0,
          });
        }
        final service = HttpMediaUploadService(apiClient);
        for (var position = 0; position < items.length; position++) {
          if (!_ready || !_owns(record)) return;
          final item = items[position];
          if (item['post'] != null) continue;
          final media = item['name'] == null
              ? null
              : MomentMedia(
                  name: item['name'] as String,
                  bytes: await store.readMedia(item['key'] as String),
                  isVideo: item['is_video'] == true,
                );
          final post = await service.uploadOne(
            _draft(record),
            media: media,
            position: position,
            clientRequestId: item['key'] as String,
          );
          if (int.tryParse('${post['id']}') == null) {
            throw const MomentLoopException('invalid_response');
          }
          item['post'] = post;
          await _checkpoint(record);
          if (_owns(record)) feedRevision.value++;
        }
        if (record['original'] != null || record['needs_patch'] == true) {
          if (record['needs_patch'] == true) {
            final session = record['session_id'] as String;
            final path = session.isEmpty
                ? '/api/setlog/${items.first['post']['id']}'
                : '/api/setlog/session/${Uri.encodeComponent(session)}';
            await _patch(path, {
              'caption': record['caption'],
              'taken_at': _dateOnly(
                DateTime.parse(record['taken_at'] as String),
              ),
              'tags': record['tags'],
              'map_pin_id': record['map_pin_id'],
            });
          }
          for (final id in (record['remove'] as List).cast<int>()) {
            if (!_ready || !_owns(record)) return;
            if ((record['deleted'] as List).contains(id)) continue;
            try {
              final body = await apiClient.deleteJson('/api/setlog/$id');
              if (body is! Map || body['ok'] != true) {
                throw const MomentLoopException('invalid_response');
              }
            } on ApiException catch (error) {
              if (error.statusCode != 404) rethrow;
            }
            (record['deleted'] as List).add(id);
            await _checkpoint(record);
          }
          final session = record['session_id'] as String;
          if (session.isNotEmpty) {
            if (!_ready || !_owns(record)) return;
            await _patch(
              '/api/setlog/session/${Uri.encodeComponent(session)}/order',
              {
                'order': items
                    .map((i) => int.parse('${i['post']['id']}'))
                    .toList(),
              },
            );
          }
          if (_owns(record)) feedRevision.value++;
        }
        record['status'] = 'complete';
        await _checkpoint(record);
        await _cleanupCompleted(record);
      } catch (error) {
        record['status'] = 'failed';
        record['error'] = mapMomentLoopError(error).code;
        await _checkpoint(record);
        if (_owns(record)) {
          try {
            await failureNotifier?.call(record['id'] as String);
          } catch (_) {
            // Notification failure must never destroy the persisted draft.
          }
        }
      }
    }
  }

  Future<void> _checkpoint(Map<String, dynamic> record) async {
    await store.save(record['id'] as String, record);
    _changed();
  }

  Future<void> _cleanupCompleted(Map<String, dynamic> record) async {
    try {
      for (final item in (record['items'] as List).cast<Map>()) {
        if (item['name'] != null) await store.removeMedia(item['key'] as String);
      }
      final id = record['id'] as String;
      await store.removeDraft(id);
      _records.remove(id);
      _changed();
    } catch (_) {
      // The durable completion checkpoint lets the next startup retry cleanup.
    }
  }

  Future<void> _patch(String path, Map<String, dynamic> fields) async {
    final body = await apiClient.patchJson(path, body: fields);
    if (body is! Map || body['ok'] != true) {
      throw const MomentLoopException('invalid_response');
    }
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    feedRevision.dispose();
    super.dispose();
  }
}
