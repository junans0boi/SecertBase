import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef TokenProvider = String? Function();

class ApiClient {
  final Uri _baseUri;
  final TokenProvider _tokenProvider;
  final http.Client _client;
  final bool _ownsClient;

  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    http.Client? client,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _tokenProvider = tokenProvider,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  Future<dynamic> getJson(String path, {Map<String, String>? headers}) {
    return _sendJson('GET', path, headers: headers);
  }

  Future<dynamic> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _sendJson('POST', path, body: body, headers: headers);
  }

  Future<dynamic> putJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _sendJson('PUT', path, body: body, headers: headers);
  }

  Future<dynamic> deleteJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _sendJson('DELETE', path, body: body, headers: headers);
  }

  Future<dynamic> patchJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _sendJson('PATCH', path, body: body, headers: headers);
  }

  Future<dynamic> sendMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
    Map<String, String>? headers,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path));
    request.headers.addAll(_requestHeaders(headers));
    request.fields.addAll(fields);
    request.files.addAll(files);

    try {
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      throw ApiException(
        statusCode: null,
        code: 'network_error',
        message: 'Network request failed',
        cause: error,
      );
    }
  }

  Uri buildUri(String path) => _buildUri(path);

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<dynamic> _sendJson(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final request = http.Request(method, _buildUri(path));
    request.headers.addAll(_requestHeaders(headers, hasJsonBody: body != null));
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      throw ApiException(
        statusCode: null,
        code: 'network_error',
        message: 'Network request failed',
        cause: error,
      );
    }
  }

  Map<String, String> _requestHeaders(
    Map<String, String>? headers, {
    bool hasJsonBody = false,
  }) {
    final result = <String, String>{'Accept': 'application/json'};
    if (hasJsonBody) result['Content-Type'] = 'application/json';
    if (headers != null) result.addAll(headers);

    final hasAuthorization = result.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
    final token = _tokenProvider();
    if (!hasAuthorization && token != null && token.isNotEmpty) {
      result['Authorization'] = 'Bearer $token';
    }
    return result;
  }

  dynamic _decodeResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final body = response.body.trim();
    dynamic decoded;

    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        if (isSuccess) {
          throw ApiException(
            statusCode: response.statusCode,
            code: 'invalid_response',
            message: 'Server returned an invalid JSON response',
          );
        }
      }
    }

    if (!isSuccess) {
      final json = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      throw ApiException(
        statusCode: response.statusCode,
        code: _errorCode(response.statusCode, json),
        message: _errorMessage(response.statusCode, json),
      );
    }

    return decoded;
  }

  String _errorCode(int statusCode, Map<String, dynamic>? body) {
    final code = body?['code'] ?? body?['reason'];
    if (code is String && code.trim().isNotEmpty) return code;
    return switch (statusCode) {
      401 => 'unauthorized',
      403 => 'forbidden',
      >= 500 => 'server_error',
      _ => 'request_failed',
    };
  }

  String _errorMessage(int statusCode, Map<String, dynamic>? body) {
    final message = body?['message'] ?? body?['error'];
    if (message is String && message.trim().isNotEmpty) return message;
    return switch (statusCode) {
      401 => 'Authentication is required',
      403 => 'Access is forbidden',
      >= 500 => 'Server request failed',
      _ => 'Request failed',
    };
  }

  Uri _buildUri(String path) {
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.resolve(relativePath);
  }

  static Uri _normalizeBaseUri(String value) {
    final parsed = Uri.parse(value);
    final path = parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/';
    return parsed.replace(path: path, query: '', fragment: '');
  }
}
