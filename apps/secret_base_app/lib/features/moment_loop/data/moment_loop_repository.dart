import 'dart:convert';

import '../../../core/today_api.dart';
import '../../../core/http/api_client.dart';
import '../domain/moment.dart';
import 'media_upload_service.dart';

export 'media_upload_service.dart' show MomentLoopException;

abstract class MomentLoopRepository {
  Future<List<Moment>> fetchFeed(DateTime weekStart);

  Future<List<Moment>> create(MomentDraft draft);

  Future<Moment> updateCaption(int id, String caption);

  Future<void> delete(int id);

  Future<List<MomentReaction>> toggleReaction({
    required String sessionId,
    required String emoji,
  });

  Future<void> designateToday(int postId);

  Future<void> removeTodayDesignation();

  Future<List<MomentMapPin>> fetchMapPins();

  Future<int> createMapPin(MomentMapPinDraft draft);
}

class HttpMomentLoopRepository implements MomentLoopRepository {
  final ApiClient apiClient;
  final MediaUploadService mediaUploadService;
  final TodayApi todayApi;

  HttpMomentLoopRepository({
    required this.apiClient,
    MediaUploadService? mediaUploadService,
    TodayApi? todayApi,
  }) : mediaUploadService =
           mediaUploadService ?? HttpMediaUploadService(apiClient),
       todayApi =
           todayApi ??
           TodayApi(
             baseUrl: apiClient.buildUri('/').origin,
             token: '',
             apiClient: apiClient,
           );

  @override
  Future<List<Moment>> fetchFeed(DateTime weekStart) async {
    try {
      final body = await apiClient.getJson('/api/setlog');
      final object = _object(body);
      if (object['ok'] != true || object['posts'] is! List) {
        throw const MomentLoopException('invalid_response');
      }
      return (object['posts'] as List).map(_moment).toList();
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<List<Moment>> create(MomentDraft draft) async {
    try {
      final rawPosts = await mediaUploadService.upload(draft);
      return rawPosts.map(_moment).toList();
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<Moment> updateCaption(int id, String caption) async {
    try {
      final body = _object(
        await apiClient.patchJson(
          '/api/setlog/$id',
          body: {'caption': caption},
        ),
      );
      if (body['ok'] != true || body['post'] is! Map) {
        throw const MomentLoopException('invalid_response');
      }
      return _moment(body['post']);
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      final body = _object(await apiClient.deleteJson('/api/setlog/$id'));
      if (body['ok'] != true) {
        throw const MomentLoopException('invalid_response');
      }
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<List<MomentReaction>> toggleReaction({
    required String sessionId,
    required String emoji,
  }) async {
    try {
      final body = _object(
        await apiClient.postJson(
          '/api/setlog/reaction',
          body: {'session_id': sessionId, 'emoji': emoji},
        ),
      );
      if (body['ok'] != true || body['reactions'] is! List) {
        throw const MomentLoopException('invalid_response');
      }
      return _reactions(body['reactions']);
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<void> designateToday(int postId) async {
    try {
      await todayApi.designateMoment(TodayMomentSelection(postId: postId));
    } on TodayApiException catch (error) {
      throw MomentLoopException(error.reason, cause: error);
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<void> removeTodayDesignation() async {
    try {
      await todayApi.removeDesignation();
    } on TodayApiException catch (error) {
      throw MomentLoopException(error.reason, cause: error);
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<List<MomentMapPin>> fetchMapPins() async {
    try {
      final body = _object(await apiClient.getJson('/api/map'));
      if (body['ok'] != true || body['pins'] is! List) {
        throw const MomentLoopException('invalid_response');
      }
      return (body['pins'] as List).map(_mapPin).toList();
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  @override
  Future<int> createMapPin(MomentMapPinDraft draft) async {
    try {
      final body = _object(
        await apiClient.postJson(
          '/api/map',
          body: {
            'place_name': draft.name,
            'category': draft.category ?? 'MomentLoop',
            'visit_date': _dateOnly(draft.visitDate),
            'memo': draft.memo,
            'latitude': 0,
            'longitude': 0,
            'status': 'visited',
            'emotion_tags': <String>[],
          },
        ),
      );
      if (body['ok'] != true) {
        throw const MomentLoopException('invalid_response');
      }
      final id = int.tryParse('${body['id']}');
      if (id == null) throw const MomentLoopException('invalid_response');
      return id;
    } catch (error) {
      throw mapMomentLoopError(error);
    }
  }

  Map<String, dynamic> _object(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const MomentLoopException('invalid_response');
  }

  Moment _moment(dynamic value) {
    final raw = _object(value);
    return Moment(
      id: _int(raw['id']) ?? 0,
      userId: _int(raw['user_id']) ?? 0,
      userName: _string(
        raw['Nickname'] ??
            raw['nickname'] ??
            raw['UserName'] ??
            raw['userName'],
      ),
      mediaType: _string(raw['media_type']),
      mediaUrl: _string(raw['media_url']),
      caption: _string(raw['caption']),
      sessionId: _string(raw['session_id']),
      takenAt: _string(raw['taken_at']),
      capturedAt: _string(raw['captured_at']),
      mapPinId: _int(raw['map_pin_id']),
      linkedPlaceName: _string(raw['linked_place_name']),
      todayLocked: raw['today_locked'] == true || raw['today_locked'] == 1,
      reactions: _reactions(raw['session_reactions']),
      extra: raw,
    );
  }

  List<MomentReaction> _reactions(Object? value) {
    if (value is String) {
      try {
        // MariaDB can return JSON_ARRAYAGG as a JSON string through older drivers.
        return _reactions(jsonDecode(value));
      } catch (_) {
        return const [];
      }
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) {
          final raw = Map<String, dynamic>.from(item);
          return MomentReaction(
            userId: _int(raw['user_id']),
            emoji: '${raw['emoji'] ?? ''}',
          );
        })
        .where((reaction) => reaction.emoji.isNotEmpty)
        .toList();
  }

  MomentMapPin _mapPin(dynamic value) {
    final raw = _object(value);
    final id = _int(raw['id']);
    if (id == null) throw const MomentLoopException('invalid_response');
    return MomentMapPin(
      id: id,
      name: '${raw['place_name'] ?? '이름 없는 위치'}',
      category: _string(raw['category']),
    );
  }

  int? _int(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }

  String? _string(Object? value) {
    final text = value == null ? '' : '$value'.trim();
    return text.isEmpty ? null : text;
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
