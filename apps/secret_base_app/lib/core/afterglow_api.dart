import 'dart:convert';

import 'package:http/http.dart' as http;

int? _int(Object? value) => value is int ? value : int.tryParse('$value');
String? _text(Object? value) {
  final result = value == null ? '' : '$value'.trim();
  return result.isEmpty ? null : result;
}

class AfterglowVisit {
  final int id;
  final int mapPinId;
  final String visitDate;

  const AfterglowVisit({
    required this.id,
    required this.mapPinId,
    required this.visitDate,
  });

  factory AfterglowVisit.fromJson(Map<String, dynamic> json) => AfterglowVisit(
    id: _int(json['id']) ?? 0,
    mapPinId: _int(json['mapPinId']) ?? 0,
    visitDate: '${json['visitDate'] ?? ''}',
  );
}

class AfterglowContribution {
  final int userId;
  final String userName;
  final bool contributed;
  final bool deleted;
  final int? postId;
  final String? caption;
  final String? emotionTag;
  final String? mediaType;
  final String? mediaUrl;
  final String? momentCaption;

  const AfterglowContribution({
    required this.userId,
    required this.userName,
    required this.contributed,
    required this.deleted,
    this.postId,
    this.caption,
    this.emotionTag,
    this.mediaType,
    this.mediaUrl,
    this.momentCaption,
  });

  factory AfterglowContribution.fromJson(Map<String, dynamic> json) =>
      AfterglowContribution(
        userId: _int(json['userId']) ?? 0,
        userName: '${json['userName'] ?? '우리'}',
        contributed: json['contributed'] == true,
        deleted: json['deleted'] == true,
        postId: _int(json['postId']),
        caption: _text(json['caption']),
        emotionTag: _text(json['emotionTag']),
        mediaType: _text(json['mediaType']),
        mediaUrl: _text(json['mediaUrl']),
        momentCaption: _text(json['momentCaption']),
      );
}

class AfterglowState {
  final String placeName;
  final AfterglowVisit? visit;
  final List<AfterglowContribution> contributions;

  const AfterglowState({
    required this.placeName,
    this.visit,
    this.contributions = const [],
  });

  factory AfterglowState.fromJson(Map<String, dynamic> json) => AfterglowState(
    placeName: '${(json['pin'] as Map?)?['placeName'] ?? ''}',
    visit: json['visit'] is Map
        ? AfterglowVisit.fromJson(
            Map<String, dynamic>.from(json['visit'] as Map),
          )
        : null,
    contributions: (json['contributions'] as List? ?? const [])
        .map(
          (item) => AfterglowContribution.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false),
  );
}

class AfterglowApiException implements Exception {
  final String reason;
  const AfterglowApiException(this.reason);
}

class AfterglowApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  AfterglowApi({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void close() => _client.close();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<AfterglowVisit> createVisit(int pinId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/retention/afterglow/$pinId/visit'),
      headers: _headers,
    );
    final body = _body(response);
    return AfterglowVisit.fromJson(
      Map<String, dynamic>.from(body['visit'] as Map),
    );
  }

  Future<AfterglowState> fetchForPin(int pinId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/retention/afterglow/pin/$pinId'),
      headers: _headers,
    );
    return AfterglowState.fromJson(_body(response));
  }

  Future<void> contribute({
    required int visitId,
    required int postId,
    String? caption,
    String? emotionTag,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/retention/afterglow/$visitId/contribution'),
      headers: _headers,
      body: jsonEncode({
        'post_id': postId,
        if (caption?.trim().isNotEmpty == true) 'caption': caption!.trim(),
        'emotion_tag': ?emotionTag,
      }),
    );
    _body(response);
  }

  Map<String, dynamic> _body(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      body = null;
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body?['ok'] != true) {
      throw AfterglowApiException('${body?['reason'] ?? 'request_failed'}');
    }
    return body!;
  }
}

List<Map<String, dynamic>> afterglowMomentCandidates({
  required int pinId,
  required String visitDate,
  required int userId,
  required List<Map<String, dynamic>> posts,
}) => posts
    .where((post) {
      final authorId = _int(post['user_id']);
      final date = '${post['taken_at'] ?? post['captured_at'] ?? ''}';
      return authorId == userId &&
          _int(post['map_pin_id']) == pinId &&
          date.startsWith(visitDate);
    })
    .toList(growable: false);
