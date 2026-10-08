import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/http/api_client.dart';
import '../../../core/http/api_exception.dart';
import '../domain/moment.dart';

abstract class MediaUploadService {
  Future<List<Map<String, dynamic>>> upload(MomentDraft draft);
}

class HttpMediaUploadService implements MediaUploadService {
  static const maxFileBytes = 30 * 1024 * 1024;

  final ApiClient apiClient;

  const HttpMediaUploadService(this.apiClient);

  @override
  Future<List<Map<String, dynamic>>> upload(MomentDraft draft) async {
    final mediaItems = draft.media.isEmpty ? <MomentMedia?>[null] : draft.media;
    final uploaded = <Map<String, dynamic>>[];

    for (var index = 0; index < mediaItems.length; index++) {
      final media = mediaItems[index];
      if (media != null && media.bytes.length > maxFileBytes) {
        throw const MomentLoopException('media_too_large');
      }

      final fields = <String, String>{
        'caption': draft.caption,
        'tags': '["#momentloop"]',
        'taken_at': _dateOnly(draft.takenAt),
        'captured_at': _mysqlDateTime(draft.capturedAt),
        'session_id': draft.sessionId,
        if (draft.todayMoment && index == 0) 'today_moment': 'true',
        if (draft.mapPinId != null) 'map_pin_id': '${draft.mapPinId}',
      };
      final files = media == null
          ? const <http.MultipartFile>[]
          : [
              http.MultipartFile.fromBytes(
                'media',
                media.bytes,
                filename: media.name,
                contentType: MediaType.parse(
                  _mimeFor(media.name, media.isVideo),
                ),
              ),
            ];

      final body = await apiClient.sendMultipart(
        '/api/setlog',
        fields: fields,
        files: files,
      );
      if (body is! Map || body['ok'] != true || body['post'] is! Map) {
        throw const MomentLoopException('invalid_response');
      }
      uploaded.add(Map<String, dynamic>.from(body['post'] as Map));
    }
    return uploaded;
  }

  String _mimeFor(String name, bool isVideo) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'm4v': 'video/mp4',
      'webm': 'video/webm',
    };
    return map[ext] ?? (isVideo ? 'video/mp4' : 'image/jpeg');
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _mysqlDateTime(DateTime value) =>
      '${_dateOnly(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}

class MomentLoopException implements Exception {
  final String code;
  final Object? cause;

  const MomentLoopException(this.code, {this.cause});

  @override
  String toString() => 'MomentLoopException($code)';
}

MomentLoopException mapMomentLoopError(Object error) {
  if (error is MomentLoopException) return error;
  if (error is ApiException) {
    return MomentLoopException(error.code, cause: error);
  }
  return MomentLoopException('network_error', cause: error);
}
