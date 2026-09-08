import 'dart:convert';

import 'package:http/http.dart' as http;

class CounselingMessage {
  final int id;
  final int sequence;
  final String role;
  final int? authorUserId;
  final String content;
  final String? generationStatus;
  final String? errorCode;
  final DateTime? createdAt;

  const CounselingMessage({
    required this.id,
    required this.sequence,
    required this.role,
    required this.authorUserId,
    required this.content,
    required this.generationStatus,
    required this.errorCode,
    required this.createdAt,
  });

  factory CounselingMessage.fromJson(Map<String, dynamic> json) =>
      CounselingMessage(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        sequence: int.tryParse('${json['sequence'] ?? 0}') ?? 0,
        role: '${json['role'] ?? ''}',
        authorUserId: json['authorUserId'] == null
            ? null
            : int.tryParse('${json['authorUserId']}'),
        content: '${json['content'] ?? ''}',
        generationStatus: json['generationStatus'] == null
            ? null
            : '${json['generationStatus']}',
        errorCode: json['errorCode'] == null ? null : '${json['errorCode']}',
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      );
}

class CounselingSession {
  final int id;
  final String scope;
  final String title;
  final String status;
  final int? coupleId;
  final int? messageCount;

  const CounselingSession({
    required this.id,
    required this.scope,
    required this.title,
    required this.status,
    required this.coupleId,
    required this.messageCount,
  });

  factory CounselingSession.fromJson(Map<String, dynamic> json) =>
      CounselingSession(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        scope: '${json['scope'] ?? ''}',
        title: '${json['title'] ?? ''}',
        status: '${json['status'] ?? ''}',
        coupleId: json['coupleId'] == null
            ? null
            : int.tryParse('${json['coupleId']}'),
        messageCount: json['messageCount'] == null
            ? null
            : int.tryParse('${json['messageCount']}'),
      );
}

class CounselingConversation {
  final CounselingSession session;
  final List<CounselingMessage> messages;

  const CounselingConversation({required this.session, required this.messages});

  factory CounselingConversation.fromJson(Map<String, dynamic> json) {
    final session = json['session'];
    if (session is! Map) {
      throw const FormatException('Missing counseling session');
    }
    final messages = json['messages'] as List? ?? const [];
    return CounselingConversation(
      session: CounselingSession.fromJson(Map<String, dynamic>.from(session)),
      messages: messages
          .map(
            (message) => CounselingMessage.fromJson(
              Map<String, dynamic>.from(message as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class CounselingInsight {
  final int id;
  final int privateSessionId;
  final String text;
  final String status;

  const CounselingInsight({
    required this.id,
    required this.privateSessionId,
    required this.text,
    required this.status,
  });

  factory CounselingInsight.fromJson(Map<String, dynamic> json) =>
      CounselingInsight(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        privateSessionId: int.tryParse('${json['privateSessionId'] ?? 0}') ?? 0,
        text: '${json['text'] ?? ''}',
        status: '${json['status'] ?? ''}',
      );
}

class CounselingApiException implements Exception {
  final String reason;

  const CounselingApiException(this.reason);

  @override
  String toString() => 'CounselingApiException($reason)';
}

class CounselingApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  CounselingApi({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void close() => _client.close();

  Future<CounselingConversation> createSession({
    required bool shared,
    String? title,
  }) async {
    final body = await _request(
      'POST',
      _sessionsEndpoint(shared),
      body: {
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
    );
    return CounselingConversation.fromJson(body);
  }

  Future<List<CounselingSession>> fetchSessions({required bool shared}) async {
    final body = await _request('GET', _sessionsEndpoint(shared));
    final sessions = body['sessions'] as List? ?? const [];
    return sessions
        .map(
          (session) => CounselingSession.fromJson(
            Map<String, dynamic>.from(session as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<CounselingConversation> fetchSession({
    required bool shared,
    required int id,
  }) async {
    final body = await _request('GET', '${_sessionsEndpoint(shared)}/$id');
    return CounselingConversation.fromJson(body);
  }

  Future<CounselingConversation> sendMessage({
    required bool shared,
    required int id,
    required String content,
  }) async {
    final body = await _request(
      'POST',
      '${_sessionsEndpoint(shared)}/$id/messages',
      body: {'content': content},
    );
    return CounselingConversation.fromJson(body);
  }

  Future<CounselingInsight> approveInsight({
    required int sessionId,
    required String text,
  }) async {
    final body = await _request(
      'POST',
      '${_sessionsEndpoint(false)}/$sessionId/insights',
      body: {'text': text},
    );
    final insight = body['insight'];
    if (insight is! Map) throw const CounselingApiException('invalid_response');
    return CounselingInsight.fromJson(Map<String, dynamic>.from(insight));
  }

  Future<List<CounselingInsight>> fetchInsights() async {
    final body = await _request(
      'GET',
      '$baseUrl/api/relationship/counseling/private/insights',
    );
    final insights = body['insights'] as List? ?? const [];
    return insights
        .map(
          (item) => CounselingInsight.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> revokeInsight(int id) async {
    await _request(
      'POST',
      '$baseUrl/api/relationship/counseling/insights/$id/revoke',
    );
  }

  Uri _sessionsEndpoint(bool shared) => Uri.parse(
    '$baseUrl/api/relationship/counseling/${shared ? 'shared' : 'private'}/sessions',
  );

  Future<Map<String, dynamic>> _request(
    String method,
    Object endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = endpoint is Uri ? endpoint : Uri.parse('$endpoint');
      final headers = {
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final response = switch (method) {
        'POST' => await _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        _ => await _client.get(uri, headers: headers),
      };
      Map<String, dynamic>? decoded;
      try {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) decoded = json;
      } on FormatException {
        decoded = null;
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded?['ok'] != true) {
        throw CounselingApiException(
          '${decoded?['reason'] ?? 'request_failed'}',
        );
      }
      return decoded!;
    } on http.ClientException {
      throw const CounselingApiException('network_error');
    }
  }
}
