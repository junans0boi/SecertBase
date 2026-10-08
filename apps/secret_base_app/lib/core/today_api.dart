import 'package:http/http.dart' as http;

import 'http/api_client.dart';
import 'http/api_exception.dart';

enum TodayStatus { empty, partnerWaiting, selfWaiting, complete, viewed }

TodayStatus _todayStatusFromJson(Object? value) => switch (value) {
  'empty' => TodayStatus.empty,
  'partner_waiting' => TodayStatus.partnerWaiting,
  'self_waiting' => TodayStatus.selfWaiting,
  'complete' => TodayStatus.complete,
  'viewed' => TodayStatus.viewed,
  _ => throw FormatException('Unknown Today status: $value'),
};

int? _optionalInt(Object? value) {
  if (value is int) return value;
  return int.tryParse('$value');
}

String? _optionalString(Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? null : text;
}

class TodayMoment {
  final int? id;
  final int userId;
  final String? userName;
  final String? mediaType;
  final String? mediaUrl;
  final String? caption;
  final List<String> tags;
  final String? takenAt;
  final String? capturedAt;
  final int? mapPinId;
  final String? linkedPlaceName;
  final bool deleted;

  const TodayMoment({
    this.id,
    required this.userId,
    this.userName,
    this.mediaType,
    this.mediaUrl,
    this.caption,
    this.tags = const [],
    this.takenAt,
    this.capturedAt,
    this.mapPinId,
    this.linkedPlaceName,
    this.deleted = false,
  });

  factory TodayMoment.fromJson(Map<String, dynamic> json) => TodayMoment(
    id: _optionalInt(json['id']),
    userId: _optionalInt(json['user_id']) ?? 0,
    userName: _optionalString(json['UserName']),
    mediaType: _optionalString(json['media_type']),
    mediaUrl: _optionalString(json['media_url']),
    caption: _optionalString(json['caption']),
    tags: (json['tags'] as List? ?? const [])
        .map((tag) => '$tag')
        .toList(growable: false),
    takenAt: _optionalString(json['taken_at']),
    capturedAt: _optionalString(json['captured_at']),
    mapPinId: _optionalInt(json['map_pin_id']),
    linkedPlaceName: _optionalString(json['linked_place_name']),
    deleted: json['deleted'] == true || json['deleted'] == 1,
  );
}

class TodayState {
  final String date;
  final TodayStatus status;
  final bool hasPartnerMoment;
  final String? revealedAt;
  final String? viewedAt;
  final TodayMoment? myMoment;
  final TodayMoment? partnerMoment;

  const TodayState({
    required this.date,
    required this.status,
    this.hasPartnerMoment = false,
    this.revealedAt,
    this.viewedAt,
    this.myMoment,
    this.partnerMoment,
  });

  bool get canOpenLoop =>
      status == TodayStatus.complete || status == TodayStatus.viewed;

  factory TodayState.fromJson(Map<String, dynamic> json) => TodayState(
    date: '${json['date'] ?? ''}',
    status: _todayStatusFromJson(json['status']),
    hasPartnerMoment: json['hasPartnerMoment'] == true,
    revealedAt: _optionalString(json['revealedAt']),
    viewedAt: _optionalString(json['viewedAt']),
    myMoment: json['myMoment'] is Map
        ? TodayMoment.fromJson(
            Map<String, dynamic>.from(json['myMoment'] as Map),
          )
        : null,
    partnerMoment: json['partnerMoment'] is Map
        ? TodayMoment.fromJson(
            Map<String, dynamic>.from(json['partnerMoment'] as Map),
          )
        : null,
  );
}

class TodayMomentSelection {
  final int postId;

  const TodayMomentSelection({required this.postId});

  Map<String, dynamic> toJson() => {'post_id': postId};
}

class TodayApiException implements Exception {
  final String reason;

  const TodayApiException(this.reason);

  @override
  String toString() => 'TodayApiException($reason)';
}

class TodayApi {
  final String baseUrl;
  final String token;
  final ApiClient _apiClient;

  TodayApi({
    required this.baseUrl,
    required this.token,
    http.Client? client,
    ApiClient? apiClient,
  }) : _apiClient =
           apiClient ??
           ApiClient(
             baseUrl: baseUrl,
             tokenProvider: () => token,
             client: client,
           );

  void close() => _apiClient.close();

  Future<TodayState> fetchState() async {
    try {
      final body = _successfulBody(
        await _apiClient.getJson('/api/retention/today'),
      );
      return TodayState.fromJson(body);
    } on FormatException {
      throw const TodayApiException('invalid_response');
    } on ApiException catch (error) {
      throw TodayApiException(error.code);
    }
  }

  Future<void> designateMoment(TodayMomentSelection selection) async {
    try {
      _successfulBody(
        await _apiClient.putJson(
          '/api/retention/today/moment',
          body: selection.toJson(),
        ),
      );
    } on ApiException catch (error) {
      throw TodayApiException(error.code);
    }
  }

  Future<void> removeDesignation() async {
    try {
      _successfulBody(
        await _apiClient.deleteJson('/api/retention/today/moment'),
      );
    } on ApiException catch (error) {
      throw TodayApiException(error.code);
    }
  }

  Future<String?> markViewed() async {
    try {
      return _optionalString(
        _successfulBody(
          await _apiClient.postJson('/api/retention/today/view'),
        )['viewedAt'],
      );
    } on ApiException catch (error) {
      throw TodayApiException(error.code);
    }
  }

  Map<String, dynamic> _successfulBody(dynamic value) {
    if (value is! Map) {
      throw const TodayApiException('invalid_response');
    }
    final body = Map<String, dynamic>.from(value);
    if (body['ok'] != true) {
      throw TodayApiException('${body['reason'] ?? 'request_failed'}');
    }
    return body;
  }
}
