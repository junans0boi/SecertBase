import 'dart:convert';

import 'package:http/http.dart' as http;

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
  final http.Client _client;

  TodayApi({required this.baseUrl, required this.token, http.Client? client})
    : _client = client ?? http.Client();

  void close() => _client.close();

  Future<void> designateMoment(TodayMomentSelection selection) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/retention/today/moment'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(selection.toJson()),
    );

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
      throw TodayApiException('${body?['reason'] ?? 'request_failed'}');
    }
  }

  Future<void> removeDesignation() async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/retention/today/moment'),
      headers: {'Authorization': 'Bearer $token'},
    );

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
      throw TodayApiException('${body?['reason'] ?? 'request_failed'}');
    }
  }
}
