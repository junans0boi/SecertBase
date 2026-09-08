import 'dart:convert';

import 'package:http/http.dart' as http;

class FortuneContent {
  final int id;
  final String type;
  final String date;
  final String version;
  final String status;
  final String title;
  final String summary;
  final List<String> signals;
  final String suggestion;
  final String generatedText;
  final String disclaimer;

  const FortuneContent({
    required this.id,
    required this.type,
    required this.date,
    required this.version,
    required this.status,
    required this.title,
    required this.summary,
    required this.signals,
    required this.suggestion,
    required this.generatedText,
    required this.disclaimer,
  });

  factory FortuneContent.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'] as Map)
        : json;
    return FortuneContent(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      type: '${json['type'] ?? result['fortuneType'] ?? ''}',
      date: '${json['date'] ?? result['date'] ?? ''}',
      version: '${json['version'] ?? result['contentVersion'] ?? ''}',
      status: '${json['status'] ?? 'fallback'}',
      title: '${result['title'] ?? ''}',
      summary: '${result['summary'] ?? ''}',
      signals: (result['signals'] as List? ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
      suggestion: '${result['suggestion'] ?? ''}',
      generatedText: '${result['generatedText'] ?? ''}',
      disclaimer: '${result['disclaimer'] ?? ''}',
    );
  }
}

class FortuneToday {
  final String date;
  final String contentVersion;
  final bool profileReady;
  final FortuneContent? personal;
  final FortuneContent? emotionalFlow;
  final FortuneContent? relationship;

  const FortuneToday({
    required this.date,
    required this.contentVersion,
    required this.profileReady,
    required this.personal,
    required this.emotionalFlow,
    required this.relationship,
  });

  factory FortuneToday.fromJson(Map<String, dynamic> json) {
    final raw = json['fortunes'] is Map
        ? Map<String, dynamic>.from(json['fortunes'] as Map)
        : const <String, dynamic>{};
    FortuneContent? parse(Object? value) => value is Map
        ? FortuneContent.fromJson(Map<String, dynamic>.from(value))
        : null;
    return FortuneToday(
      date: '${json['date'] ?? ''}',
      contentVersion: '${json['contentVersion'] ?? ''}',
      profileReady: json['profileReady'] == true,
      personal: parse(raw['personal']),
      emotionalFlow: parse(raw['emotional_flow']),
      relationship: parse(raw['relationship']),
    );
  }
}

class FortuneApiException implements Exception {
  final String reason;

  const FortuneApiException(this.reason);

  @override
  String toString() => 'FortuneApiException($reason)';
}

class FortuneApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  FortuneApi({required this.baseUrl, required this.token, http.Client? client})
    : _client = client ?? http.Client();

  void close() => _client.close();

  Future<FortuneToday> fetchToday() async {
    try {
      final response = await _client.get(
        _todayEndpoint,
        headers: {'Authorization': 'Bearer $token'},
      );
      return FortuneToday.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const FortuneApiException('network_error');
    } on FormatException {
      throw const FortuneApiException('invalid_response');
    }
  }

  Future<FortuneToday> regenerate({String? type}) async {
    try {
      final response = await _client.post(
        _regenerateEndpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'type': ?type}),
      );
      return FortuneToday.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const FortuneApiException('network_error');
    } on FormatException {
      throw const FortuneApiException('invalid_response');
    }
  }

  Uri get _todayEndpoint =>
      Uri.parse('$baseUrl/api/relationship/fortune/today');

  Uri get _regenerateEndpoint =>
      Uri.parse('$baseUrl/api/relationship/fortune/today/regenerate');

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
      throw FortuneApiException('${body?['reason'] ?? 'request_failed'}');
    }
    return body!;
  }
}
