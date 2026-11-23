import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/http/api_client.dart';
import '../../../core/http/api_exception.dart';
import '../domain/note.dart';

abstract class NotesRepository {
  Future<NotesPage> list({int? before, int limit = 30});
  Future<int> unreadCount();
  Future<Note> send(PendingNote draft);
  Future<int> markRead(int lastReadId);
  Future<void> delete(int id);
  Future<Note> react(int id, String? emoji);
}

class HttpNotesRepository implements NotesRepository {
  final ApiClient apiClient;
  const HttpNotesRepository(this.apiClient);

  Map<String, dynamic> _object(dynamic body) {
    if (body is Map && body['ok'] == true) {
      return Map<String, dynamic>.from(body);
    }
    throw const ApiException(
      statusCode: null,
      code: 'invalid_response',
      message: 'invalid response',
    );
  }

  @override
  Future<NotesPage> list({int? before, int limit = 30}) async {
    final query = {'limit': '$limit', if (before != null) 'before': '$before'};
    final path = Uri(path: '/api/notes', queryParameters: query).toString();
    final body = _object(await apiClient.getJson(path));
    return NotesPage(
      notes: [
        for (final n in body['notes'] as List)
          Note.fromJson(Map<String, dynamic>.from(n as Map)),
      ],
      nextBefore: (body['next_before'] as num?)?.toInt(),
      unreadCount: (body['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<int> unreadCount() async {
    final body = _object(await apiClient.getJson('/api/notes/unread'));
    return (body['unread_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Note> send(PendingNote draft) async {
    final fields = {
      'body': draft.body,
      'client_request_id': draft.clientRequestId,
      if (draft.openAt != null)
        'open_at': draft.openAt!.toUtc().toIso8601String(),
      if (draft.mapPinId != null) 'map_pin_id': '${draft.mapPinId}',
      if (draft.setlogPostId != null) 'setlog_post_id': '${draft.setlogPostId}',
    };
    final dynamic response;
    if (draft.photo != null) {
      final name = draft.photo!.name;
      final ext = name.split('.').last.toLowerCase();
      response = await apiClient.sendMultipart(
        '/api/notes',
        fields: fields,
        files: [
          http.MultipartFile.fromBytes(
            'media',
            draft.photo!.bytes,
            filename: name,
            contentType: MediaType.parse(switch (ext) {
              'png' => 'image/png',
              'webp' => 'image/webp',
              _ => 'image/jpeg',
            }),
          ),
        ],
      );
    } else {
      response = await apiClient.postJson('/api/notes', body: fields);
    }
    return Note.fromJson(Map<String, dynamic>.from(_object(response)['note']));
  }

  @override
  Future<int> markRead(int lastReadId) async {
    final body = _object(
      await apiClient.postJson(
        '/api/notes/read',
        body: {'last_read_id': lastReadId},
      ),
    );
    return (body['unread_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> delete(int id) async {
    await apiClient.deleteJson('/api/notes/$id');
  }

  @override
  Future<Note> react(int id, String? emoji) async {
    final body = _object(
      await apiClient.postJson(
        '/api/notes/$id/reaction',
        body: {'emoji': emoji},
      ),
    );
    return Note.fromJson(Map<String, dynamic>.from(body['note']));
  }
}
