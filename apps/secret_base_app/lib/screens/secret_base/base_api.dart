import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Failure of a 비밀기지 request. [reason] is the server's `reason` when it
/// sent one (`active_couple_required`, `couple_not_found`, ...).
class BaseApiException implements Exception {
  const BaseApiException(this.reason, {this.statusCode});
  final String reason;
  final int? statusCode;

  /// The couple link is missing (unpaired) rather than a transient failure.
  bool get unpaired =>
      reason == 'active_couple_required' || reason == 'couple_not_found';

  @override
  String toString() => 'BaseApiException($reason, $statusCode)';
}

/// Tiny JSON client for the 비밀기지 hub (milestones, anniversaries,
/// postcards, memories, couple info). Every response must be `{ok: true}`.
class BaseApi {
  BaseApi({required this.baseUrl, required this.headers, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final String baseUrl;
  final Map<String, String> headers;
  final http.Client _client;
  final bool _ownsClient;

  static const _timeout = Duration(seconds: 20);

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => _client.get(_uri(path), headers: headers));

  Future<Map<String, dynamic>> post(String path, [Object? body]) => _send(
    () => _client.post(_uri(path), headers: _jsonHeaders, body: _encode(body)),
  );

  Future<Map<String, dynamic>> patch(String path, Object body) => _send(
    () => _client.patch(_uri(path), headers: _jsonHeaders, body: _encode(body)),
  );

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: headers));

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  Map<String, String> get _jsonHeaders => {
    ...headers,
    'Content-Type': 'application/json',
  };

  String? _encode(Object? body) => body == null ? null : jsonEncode(body);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on TimeoutException {
      throw const BaseApiException('timeout');
    } catch (_) {
      throw const BaseApiException('network');
    }
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      body = null;
    }
    final ok =
        res.statusCode >= 200 && res.statusCode < 300 && body?['ok'] == true;
    if (!ok) {
      throw BaseApiException(
        '${body?['reason'] ?? 'request_failed'}',
        statusCode: res.statusCode,
      );
    }
    return body!;
  }
}
