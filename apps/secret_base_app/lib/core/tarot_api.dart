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

class TarotDeckCard {
  final String key;
  final int position;

  const TarotDeckCard({required this.key, required this.position});

  factory TarotDeckCard.fromJson(Map<String, dynamic> json) => TarotDeckCard(
    key: '${json['key'] ?? ''}',
    position: int.tryParse('${json['position'] ?? 0}') ?? 0,
  );
}

class TarotReading {
  final String scope;
  final bool drawn;
  final bool drawRequired;
  final TarotCard? card;
  final List<TarotDeckCard> cards;
  final String disclaimer;

  const TarotReading({
    required this.scope,
    required this.drawn,
    required this.drawRequired,
    required this.card,
    required this.cards,
    required this.disclaimer,
  });

  factory TarotReading.fromJson(Map<String, dynamic> json) => TarotReading(
    scope: '${json['scope'] ?? 'user'}',
    drawn: json['drawn'] == true || json['card'] is Map,
    drawRequired: json['drawRequired'] == true,
    card: json['card'] is Map
        ? TarotCard.fromJson(Map<String, dynamic>.from(json['card'] as Map))
        : null,
    cards: (json['cards'] as List? ?? const [])
        .whereType<Map>()
        .map((card) => TarotDeckCard.fromJson(Map<String, dynamic>.from(card)))
        .toList(growable: false),
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

  Future<TarotToday> drawToday({
    required String scope,
    required String cardKey,
  }) async {
    try {
      final response = await _client.post(
        _drawEndpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'scope': scope, 'cardKey': cardKey}),
      );
      return TarotToday.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const TarotApiException('network_error');
    } on FormatException {
      throw const TarotApiException('invalid_response');
    }
  }

  Uri get _endpoint => Uri.parse('$baseUrl/api/relationship/tarot/today');

  Uri get _drawEndpoint =>
      Uri.parse('$baseUrl/api/relationship/tarot/today/draw');

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
