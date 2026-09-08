import 'dart:convert';

import 'package:http/http.dart' as http;

enum BirthCalendarType { solar, lunar }

BirthCalendarType _calendarTypeFromJson(Object? value) => switch (value) {
  'solar' => BirthCalendarType.solar,
  'lunar' => BirthCalendarType.lunar,
  _ => throw const FormatException('Unknown birth calendar type'),
};

String _calendarTypeToJson(BirthCalendarType value) => switch (value) {
  BirthCalendarType.solar => 'solar',
  BirthCalendarType.lunar => 'lunar',
};

class BirthProfile {
  final BirthCalendarType calendarType;
  final String birthDate;
  final String? birthTime;
  final String timezone;
  final String? birthPlace;

  const BirthProfile({
    required this.calendarType,
    required this.birthDate,
    required this.birthTime,
    required this.timezone,
    required this.birthPlace,
  });

  factory BirthProfile.fromJson(Map<String, dynamic> json) => BirthProfile(
    calendarType: _calendarTypeFromJson(json['calendarType']),
    birthDate: '${json['birthDate'] ?? ''}',
    birthTime: _optionalString(json['birthTime']),
    timezone: '${json['timezone'] ?? ''}',
    birthPlace: _optionalString(json['birthPlace']),
  );
}

class BirthProfileInput {
  final BirthCalendarType calendarType;
  final String birthDate;
  final String? birthTime;
  final String timezone;
  final String? birthPlace;

  const BirthProfileInput({
    required this.calendarType,
    required this.birthDate,
    this.birthTime,
    required this.timezone,
    this.birthPlace,
  });

  Map<String, dynamic> toJson() => {
    'calendarType': _calendarTypeToJson(calendarType),
    'birthDate': birthDate,
    'birthTime': birthTime,
    'timezone': timezone,
    'birthPlace': birthPlace,
  };
}

class BirthProfileApiException implements Exception {
  final String reason;

  const BirthProfileApiException(this.reason);

  @override
  String toString() => 'BirthProfileApiException($reason)';
}

class BirthProfileApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  BirthProfileApi({required this.baseUrl, required this.token, http.Client? client})
    : _client = client ?? http.Client();

  void close() => _client.close();

  Future<BirthProfile> fetch() async {
    try {
      final response = await _client.get(
        _endpoint,
        headers: {'Authorization': 'Bearer $token'},
      );
      return BirthProfile.fromJson(
        Map<String, dynamic>.from(_successfulBody(response)['birthProfile'] as Map),
      );
    } on http.ClientException {
      throw const BirthProfileApiException('network_error');
    } on FormatException {
      throw const BirthProfileApiException('invalid_response');
    }
  }

  Future<BirthProfile> update(BirthProfileInput input) async {
    try {
      final response = await _client.patch(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(input.toJson()),
      );
      return BirthProfile.fromJson(
        Map<String, dynamic>.from(_successfulBody(response)['birthProfile'] as Map),
      );
    } on http.ClientException {
      throw const BirthProfileApiException('network_error');
    } on FormatException {
      throw const BirthProfileApiException('invalid_response');
    }
  }

  Uri get _endpoint => Uri.parse('$baseUrl/api/relationship/birth-profile');

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
      throw BirthProfileApiException('${body?['reason'] ?? 'request_failed'}');
    }
    final profile = body?['birthProfile'];
    if (profile is! Map) throw const FormatException('Missing birth profile');
    return {...body!, 'birthProfile': Map<String, dynamic>.from(profile)};
  }
}

String? _optionalString(Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? null : text;
}
