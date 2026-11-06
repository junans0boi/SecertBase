import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth_service.dart';
import 'map_logic.dart';

class MapApiException implements Exception {
  final String code;
  final int? status;
  const MapApiException(this.code, [this.status]);

  /// 409 / ok:false active_couple_required: the user has no partner yet.
  bool get unpaired => code == 'active_couple_required';
  bool get offline => code == 'network_error';

  @override
  String toString() => 'MapApiException($code)';
}

/// Thin wrapper over the 비밀지도 endpoints. A 409 or `ok:false` is surfaced as
/// an error (never silently treated as "no pins").
class MapApi {
  final AuthService auth;
  final http.Client _client;
  final bool _ownsClient;

  MapApi({AuthService? auth, http.Client? client})
    : auth = auth ?? AuthService(),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  void close() {
    if (_ownsClient) _client.close();
  }

  String get baseUrl => auth.baseUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
  };

  Map<String, String> get _authOnly => {
    if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
  };

  Map<String, dynamic> _decode(http.Response res) {
    Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    final map = body is Map ? Map<String, dynamic>.from(body) : null;
    final code = '${map?['reason'] ?? map?['code'] ?? map?['error'] ?? ''}';
    if (res.statusCode == 409 && code.isEmpty) {
      throw MapApiException('active_couple_required', 409);
    }
    if (res.statusCode < 200 || res.statusCode >= 300 || map == null) {
      throw MapApiException(
        code.isEmpty ? 'request_failed' : code,
        res.statusCode,
      );
    }
    if (map['ok'] == false) {
      throw MapApiException(
        code.isEmpty ? 'request_failed' : code,
        res.statusCode,
      );
    }
    return map;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on MapApiException {
      rethrow;
    } catch (_) {
      throw const MapApiException('network_error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPins() => _guard(() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/map'),
      headers: _headers,
    );
    final data = _decode(res);
    return (data['pins'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  });

  /// Best effort: linked memories are decoration for the pin detail.
  Future<List<Map<String, dynamic>>> fetchPosts(int userId) async {
    try {
      final res = await _client.get(
        Uri.parse(
          '$baseUrl/api/setlog',
        ).replace(queryParameters: {'user_id': '$userId'}),
        headers: _headers,
      );
      final data = _decode(res);
      return (data['posts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    required double lat,
    required double lng,
  }) => _guard(() async {
    final url = Uri.parse('$baseUrl/api/places/search').replace(
      queryParameters: {
        'q': query,
        'limit': '10',
        'lat': '$lat',
        'lng': '$lng',
      },
    );
    final res = await _client.get(url, headers: _headers);
    if (res.statusCode != 200) {
      throw MapApiException('search_failed', res.statusCode);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['places'] as List? ?? [])
        .map(
          (e) =>
              normalizePlaceResultForMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  });

  /// Returns the new pin id when the server reports one.
  Future<int?> createPin({
    required String name,
    required String status,
    required String category,
    required double lat,
    required double lng,
    DateTime? visitDate,
  }) => _guard(() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/map'),
      headers: _headers,
      body: jsonEncode({
        'place_name': name,
        'category': category,
        'rating': null,
        'visit_date': status == 'visited'
            ? dateValue(visitDate ?? DateTime.now())
            : null,
        'memo': null,
        'latitude': lat,
        'longitude': lng,
        'status': status,
        'emotion_tags': <String>[],
      }),
    );
    final data = _decode(res);
    return placeIntForMap(data['id'] ?? (data['pin'] as Map?)?['id']);
  });

  Future<void> updatePin(
    Object id, {
    required Map<String, dynamic> fields,
    XFile? newImage,
  }) => _guard(() async {
    if (newImage != null) {
      final req = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/api/map/$id'),
      )..headers.addAll(_authOnly);
      fields.forEach((k, v) {
        if (v == null) return;
        req.fields[k] = v is List ? jsonEncode(v) : '$v';
      });
      req.files.add(
        http.MultipartFile.fromBytes(
          'media',
          await newImage.readAsBytes(),
          filename: newImage.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      _decode(await http.Response.fromStream(await _client.send(req)));
      return;
    }
    final res = await _client.patch(
      Uri.parse('$baseUrl/api/map/$id'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    _decode(res);
  });

  Future<void> deletePin(Object id) => _guard(() async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/map/$id'),
      headers: _headers,
    );
    _decode(res);
  });

  Future<List<Map<String, dynamic>>> fetchReviews(Object pinId) =>
      _guard(() async {
        final res = await _client.get(
          Uri.parse('$baseUrl/api/map/$pinId/reviews'),
          headers: _headers,
        );
        final data = _decode(res);
        return (data['reviews'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });

  Future<void> addReview(Object pinId, {String? content, XFile? image}) =>
      _guard(() async {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/map/$pinId/reviews'),
        )..headers.addAll(_authOnly);
        if (content != null && content.isNotEmpty) {
          req.fields['content'] = content;
        }
        if (image != null) {
          req.files.add(
            http.MultipartFile.fromBytes(
              'media',
              await image.readAsBytes(),
              filename: image.name,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
        _decode(await http.Response.fromStream(await _client.send(req)));
      });

  Future<void> deleteReview(Object pinId, Object reviewId) => _guard(() async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/map/$pinId/reviews/$reviewId'),
      headers: _headers,
    );
    _decode(res);
  });

  Future<void> linkPost(Object postId, Object? pinId) => _guard(() async {
    final res = await _client.patch(
      Uri.parse('$baseUrl/api/setlog/$postId'),
      headers: _headers,
      body: jsonEncode({'map_pin_id': pinId}),
    );
    _decode(res);
  });
}
