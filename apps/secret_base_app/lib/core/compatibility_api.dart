import 'dart:convert';

import 'package:http/http.dart' as http;

class CompatibilityDimension {
  final String key;
  final String title;
  final int scoreDifference;

  const CompatibilityDimension({
    required this.key,
    required this.title,
    required this.scoreDifference,
  });

  factory CompatibilityDimension.fromJson(Map<String, dynamic> json) =>
      CompatibilityDimension(
        key: '${json['key'] ?? ''}',
        title: '${json['title'] ?? ''}',
        scoreDifference: int.tryParse('${json['scoreDifference']}') ?? 0,
      );
}

class CompatibilityAnalysis {
  final String analysisCode;
  final String analysisVersion;
  final List<CompatibilityDimension> dimensions;
  final String complementaryPatternKey;
  final String complementaryPattern;
  final List<String> cautionInteractions;
  final List<String> conversationPrompts;
  final String? conflictPatternKey;
  final String disclaimer;

  const CompatibilityAnalysis({
    required this.analysisCode,
    required this.analysisVersion,
    required this.dimensions,
    required this.complementaryPatternKey,
    required this.complementaryPattern,
    required this.cautionInteractions,
    required this.conversationPrompts,
    required this.conflictPatternKey,
    required this.disclaimer,
  });

  factory CompatibilityAnalysis.fromJson(Map<String, dynamic> json) =>
      CompatibilityAnalysis(
        analysisCode: '${json['analysisCode'] ?? ''}',
        analysisVersion: '${json['analysisVersion'] ?? ''}',
        dimensions: (json['dimensions'] as List? ?? const [])
            .map(
              (dimension) => CompatibilityDimension.fromJson(
                Map<String, dynamic>.from(dimension as Map),
              ),
            )
            .toList(growable: false),
        complementaryPatternKey: '${json['complementaryPatternKey'] ?? ''}',
        complementaryPattern: '${json['complementaryPattern'] ?? ''}',
        cautionInteractions: (json['cautionInteractions'] as List? ?? const [])
            .map((item) => '$item')
            .toList(growable: false),
        conversationPrompts: (json['conversationPrompts'] as List? ?? const [])
            .map((item) => '$item')
            .toList(growable: false),
        conflictPatternKey: json['conflictPatternKey'] == null
            ? null
            : '${json['conflictPatternKey']}',
        disclaimer: '${json['disclaimer'] ?? ''}',
      );
}

class CompatibilityState {
  final String status;
  final Map<String, int> dependencyStatus;
  final CompatibilityAnalysis? result;

  const CompatibilityState({
    required this.status,
    required this.dependencyStatus,
    required this.result,
  });

  factory CompatibilityState.fromJson(Map<String, dynamic> json) {
    final rawDependencies = json['dependencyStatus'];
    final dependencies = rawDependencies is Map
        ? rawDependencies.map(
            (key, value) =>
                MapEntry(key.toString(), int.tryParse('$value') ?? 0),
          )
        : <String, int>{};
    final rawResult = json['result'];
    return CompatibilityState(
      status: '${json['status'] ?? 'pending'}',
      dependencyStatus: dependencies,
      result: rawResult is Map
          ? CompatibilityAnalysis.fromJson(Map<String, dynamic>.from(rawResult))
          : null,
    );
  }
}

class CompatibilityApiException implements Exception {
  final String reason;

  const CompatibilityApiException(this.reason);

  @override
  String toString() => 'CompatibilityApiException($reason)';
}

class CompatibilityApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  CompatibilityApi({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void close() => _client.close();

  Future<CompatibilityState> fetchAttachmentConflict() async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api/relationship/compatibility/attachment-conflict/current',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      return CompatibilityState.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const CompatibilityApiException('network_error');
    } on FormatException {
      throw const CompatibilityApiException('invalid_response');
    }
  }

  Map<String, dynamic> _successfulBody(http.Response response) {
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
      throw CompatibilityApiException('${body?['reason'] ?? 'request_failed'}');
    }
    return body!;
  }
}
