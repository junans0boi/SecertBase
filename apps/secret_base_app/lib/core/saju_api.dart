import 'dart:convert';

import 'package:http/http.dart' as http;

enum SajuStatus { ready, limited, requiresProfile, unsupportedRange }

enum SajuMode { complete, limited }

SajuStatus _statusFromJson(Object? value) => switch ('$value') {
  'ready' => SajuStatus.ready,
  'limited' => SajuStatus.limited,
  'requires_profile' => SajuStatus.requiresProfile,
  'unsupported_range' => SajuStatus.unsupportedRange,
  _ => throw const FormatException('Unknown Saju status'),
};

String _modeToJson(SajuMode value) => switch (value) {
  SajuMode.complete => 'complete',
  SajuMode.limited => 'limited',
};

class SajuPersonal {
  final String scope;
  final String mode;
  final String plainTitle;
  final String plainSummary;
  final Map<String, dynamic> plain;
  final Map<String, dynamic> technical;
  final Map<String, dynamic> inputSummary;
  final List<String> basis;
  final List<String> limitations;

  const SajuPersonal({
    required this.scope,
    required this.mode,
    required this.plainTitle,
    required this.plainSummary,
    required this.plain,
    required this.technical,
    required this.inputSummary,
    required this.basis,
    required this.limitations,
  });

  factory SajuPersonal.fromJson(Map<String, dynamic> json) {
    final rawPlain = json['plain'] is Map
        ? Map<String, dynamic>.from(json['plain'] as Map)
        : <String, dynamic>{};
    final rawTechnical = json['technical'] is Map
        ? Map<String, dynamic>.from(json['technical'] as Map)
        : <String, dynamic>{};
    final rawInput = json['inputSummary'] is Map
        ? Map<String, dynamic>.from(json['inputSummary'] as Map)
        : <String, dynamic>{};
    return SajuPersonal(
      scope: '${json['scope'] ?? 'user'}',
      mode: '${json['mode'] ?? 'complete'}',
      plainTitle: '${rawPlain['title'] ?? ''}',
      plainSummary: '${rawPlain['summary'] ?? ''}',
      plain: rawPlain,
      technical: rawTechnical,
      inputSummary: rawInput,
      basis: (json['basis'] as List? ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
      limitations: (json['limitations'] as List? ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
    );
  }
}

class SajuResult {
  final SajuStatus status;
  final String calculationVersion;
  final SajuPersonal? personal;
  final Map<String, dynamic>? relationship;

  const SajuResult({
    required this.status,
    required this.calculationVersion,
    required this.personal,
    required this.relationship,
  });

  factory SajuResult.fromJson(Map<String, dynamic> json) => SajuResult(
    status: _statusFromJson(json['status']),
    calculationVersion: '${json['calculationVersion'] ?? ''}',
    personal: json['personal'] is Map
        ? SajuPersonal.fromJson(
            Map<String, dynamic>.from(json['personal'] as Map),
          )
        : null,
    relationship: json['relationship'] is Map
        ? Map<String, dynamic>.from(json['relationship'] as Map)
        : null,
  );
}

class SajuApiException implements Exception {
  final String reason;
  final List<String> missingFields;
  final List<String> limitations;

  const SajuApiException(
    this.reason, {
    this.missingFields = const [],
    this.limitations = const [],
  });

  @override
  String toString() => 'SajuApiException($reason)';
}

class SajuApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  SajuApi({required this.baseUrl, required this.token, http.Client? client})
    : _client = client ?? http.Client();

  void close() => _client.close();

  Future<SajuResult> fetch() async {
    try {
      final response = await _client.get(
        _endpoint,
        headers: {'Authorization': 'Bearer $token'},
      );
      return SajuResult.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const SajuApiException('network_error');
    } on FormatException {
      throw const SajuApiException('invalid_response');
    }
  }

  Future<SajuResult> calculate({required SajuMode mode}) async {
    try {
      final response = await _client.post(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'mode': _modeToJson(mode)}),
      );
      return SajuResult.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const SajuApiException('network_error');
    } on FormatException {
      throw const SajuApiException('invalid_response');
    }
  }

  Uri get _endpoint => Uri.parse('$baseUrl/api/relationship/saju');

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
      throw SajuApiException(
        '${body?['reason'] ?? 'request_failed'}',
        missingFields: (body?['missingFields'] as List? ?? const [])
            .map((item) => '$item')
            .toList(growable: false),
        limitations: (body?['limitations'] as List? ?? const [])
            .map((item) => '$item')
            .toList(growable: false),
      );
    }
    return body!;
  }
}
