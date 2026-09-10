import 'dart:convert';

import 'package:http/http.dart' as http;

class TarotCard {
  final String key;
  final String title;
  final String orientation;
  final String plain;
  final String reflection;

  const TarotCard({
    required this.key,
    required this.title,
    required this.orientation,
    required this.plain,
    required this.reflection,
  });

  factory TarotCard.fromJson(Map<String, dynamic> json) => TarotCard(
    key: '${json['key'] ?? ''}',
    title: '${json['title'] ?? ''}',
    orientation: '${json['orientation'] ?? 'upright'}',
    plain: '${json['plain'] ?? ''}',
    reflection: '${json['reflection'] ?? ''}',
  );
}

class TarotReading {
  final String scope;
  final TarotCard card;
  final String disclaimer;

  const TarotReading({
    required this.scope,
    required this.card,
    required this.disclaimer,
  });

  factory TarotReading.fromJson(Map<String, dynamic> json) => TarotReading(
    scope: '${json['scope'] ?? 'user'}',
    card: TarotCard.fromJson(
      json['card'] is Map
          ? Map<String, dynamic>.from(json['card'] as Map)
          : const <String, dynamic>{},
    ),
    disclaimer: '${json['disclaimer'] ?? ''}',
  );
}

class TarotToday {
  final String date;
  final String catalogVersion;
  final bool redrawAvailable;
  final TarotReading? personal;
  final TarotReading? relationship;

  const TarotToday({
    required this.date,
    required this.catalogVersion,
    required this.redrawAvailable,
    required this.personal,
    required this.relationship,
  });

  factory TarotToday.fromJson(Map<String, dynamic> json) {
    TarotReading? parse(Object? value) => value is Map
        ? TarotReading.fromJson(Map<String, dynamic>.from(value))
        : null;
    return TarotToday(
      date: '${json['date'] ?? ''}',
      catalogVersion: '${json['catalogVersion'] ?? ''}',
      redrawAvailable: json['redrawAvailable'] == true,
      personal: parse(json['personal']),
      relationship: parse(json['relationship']),
    );
  }
}

class TarotApiException implements Exception {
  final String reason;

  const TarotApiException(this.reason);

  @override
  String toString() => 'TarotApiException($reason)';
}

class TarotApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  TarotApi({required this.baseUrl, required this.token, http.Client? client})
    : _client = client ?? http.Client();

  void close() => _client.close();

  Future<TarotToday> fetchToday() async {
    try {
      final response = await _client.get(
        _endpoint,
        headers: {'Authorization': 'Bearer $token'},
      );
      return TarotToday.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const TarotApiException('network_error');
    } on FormatException {
      throw const TarotApiException('invalid_response');
    }
  }

  Uri get _endpoint => Uri.parse('$baseUrl/api/relationship/tarot/today');

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
      throw TarotApiException('${body?['reason'] ?? 'request_failed'}');
    }
    return body!;
  }
}
