import 'dart:convert';

import 'package:http/http.dart' as http;

class MindcareChoice {
  final String key;
  final String label;

  const MindcareChoice({required this.key, required this.label});

  factory MindcareChoice.fromJson(Map<String, dynamic> json) => MindcareChoice(
    key: '${json['key'] ?? ''}',
    label: '${json['label'] ?? ''}',
  );
}

class MindcareQuestion {
  final String key;
  final String text;
  final bool allowFreeText;

  const MindcareQuestion({
    required this.key,
    required this.text,
    required this.allowFreeText,
  });

  factory MindcareQuestion.fromJson(Map<String, dynamic> json) =>
      MindcareQuestion(
        key: '${json['key'] ?? ''}',
        text: '${json['text'] ?? ''}',
        allowFreeText: json['allowFreeText'] == true,
      );
}

class MindcareMessage {
  final int id;
  final int sequence;
  final String role;
  final String content;
  final String? inputType;
  final String? choiceKey;
  final String? riskCandidate;

  const MindcareMessage({
    required this.id,
    required this.sequence,
    required this.role,
    required this.content,
    required this.inputType,
    required this.choiceKey,
    required this.riskCandidate,
  });

  factory MindcareMessage.fromJson(Map<String, dynamic> json) =>
      MindcareMessage(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        sequence: int.tryParse('${json['sequence'] ?? 0}') ?? 0,
        role: '${json['role'] ?? ''}',
        content: '${json['content'] ?? ''}',
        inputType: json['inputType'] == null ? null : '${json['inputType']}',
        choiceKey: json['choiceKey'] == null ? null : '${json['choiceKey']}',
        riskCandidate: json['riskCandidate'] == null
            ? null
            : '${json['riskCandidate']}',
      );
}

class MindcareSession {
  final int id;
  final String status;
  final String currentState;
  final int userResponseCount;
  final String contentVersion;
  final bool ownerOnly;

  const MindcareSession({
    required this.id,
    required this.status,
    required this.currentState,
    required this.userResponseCount,
    required this.contentVersion,
    required this.ownerOnly,
  });

  factory MindcareSession.fromJson(Map<String, dynamic> json) =>
      MindcareSession(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        status: '${json['status'] ?? ''}',
        currentState: '${json['currentState'] ?? ''}',
        userResponseCount:
            int.tryParse('${json['userResponseCount'] ?? 0}') ?? 0,
        contentVersion: '${json['contentVersion'] ?? ''}',
        ownerOnly: json['ownerOnly'] != false,
      );
}

class MindcareConversation {
  final MindcareSession session;
  final List<MindcareMessage> messages;
  final List<MindcareChoice> choices;
  final MindcareQuestion? nextQuestion;
  final String? safetyStatus;
  final SafetyResources? safetyResources;

  const MindcareConversation({
    required this.session,
    required this.messages,
    required this.choices,
    required this.nextQuestion,
    required this.safetyStatus,
    required this.safetyResources,
  });

  factory MindcareConversation.fromJson(Map<String, dynamic> json) {
    final session = json['session'];
    if (session is! Map) {
      throw const FormatException('Missing mindcare session');
    }
    final messages = json['messages'] as List? ?? const [];
    final choices = json['choices'] as List? ?? const [];
    final question = json['nextQuestion'];
    final safety = json['safety'];
    return MindcareConversation(
      session: MindcareSession.fromJson(Map<String, dynamic>.from(session)),
      messages: messages
          .map(
            (item) => MindcareMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      choices: choices
          .map(
            (item) =>
                MindcareChoice.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      nextQuestion: question is Map
          ? MindcareQuestion.fromJson(Map<String, dynamic>.from(question))
          : null,
      safetyStatus: safety is Map && safety['status'] != null
          ? '${safety['status']}'
          : null,
      safetyResources:
          json['resourceVersion'] != null || json['resources'] is List
          ? SafetyResources.fromJson(json)
          : null,
    );
  }
}

class MindcareApiException implements Exception {
  final String reason;

  const MindcareApiException(this.reason);

  @override
  String toString() => 'MindcareApiException($reason)';
}

class SafetyResource {
  final String key;
  final String title;
  final String description;
  final String? contact;
  final String? region;

  const SafetyResource({
    required this.key,
    required this.title,
    required this.description,
    required this.contact,
    required this.region,
  });

  factory SafetyResource.fromJson(Map<String, dynamic> json) => SafetyResource(
    key: '${json['key'] ?? ''}',
    title: '${json['title'] ?? ''}',
    description: '${json['description'] ?? ''}',
    contact: json['contact'] == null ? null : '${json['contact']}',
    region: json['region'] == null ? null : '${json['region']}',
  );
}

class SafetyResources {
  final String resourceVersion;
  final String source;
  final String validUntil;
  final String locationMode;
  final String? countryCode;
  final String? adminArea;
  final List<SafetyResource> resources;

  const SafetyResources({
    required this.resourceVersion,
    required this.source,
    required this.validUntil,
    required this.locationMode,
    required this.countryCode,
    required this.adminArea,
    required this.resources,
  });

  factory SafetyResources.fromJson(
    Map<String, dynamic> json,
  ) => SafetyResources(
    resourceVersion: '${json['resourceVersion'] ?? ''}',
    source: '${json['source'] ?? ''}',
    validUntil: '${json['validUntil'] ?? ''}',
    locationMode: '${json['locationMode'] ?? 'general'}',
    countryCode: json['countryCode'] == null ? null : '${json['countryCode']}',
    adminArea: json['adminArea'] == null ? null : '${json['adminArea']}',
    resources: (json['resources'] as List? ?? const [])
        .map(
          (item) =>
              SafetyResource.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
  );
}

class MindcareApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  MindcareApi({required this.baseUrl, required this.token, http.Client? client})
    : _client = client ?? http.Client();

  void close() => _client.close();

  Future<MindcareConversation> createOrResume() async {
    final body = await _request('POST', _sessionsEndpoint);
    return MindcareConversation.fromJson(body);
  }

  Future<MindcareConversation> fetchSession(int id) async {
    final body = await _request('GET', '$_sessionsEndpoint/$id');
    return MindcareConversation.fromJson(body);
  }

  Future<MindcareConversation> sendMessage({
    required int id,
    String? choiceKey,
    String? text,
  }) async {
    final body = <String, dynamic>{};
    if (choiceKey != null) body['choiceKey'] = choiceKey;
    if (text != null) body['text'] = text;
    final response = await _request(
      'POST',
      '$_sessionsEndpoint/$id/messages',
      body: body,
    );
    return MindcareConversation.fromJson(response);
  }

  Future<MindcareConversation> confirmSafety({
    required int id,
    required bool safeNow,
    bool? permissionGranted,
    String? countryCode,
    String? adminArea,
  }) async {
    final body = <String, dynamic>{'safeNow': safeNow};
    if (permissionGranted != null) {
      body['locationPermission'] = permissionGranted ? 'granted' : 'denied';
    }
    if (countryCode != null) body['countryCode'] = countryCode;
    if (adminArea != null) body['adminArea'] = adminArea;
    final response = await _request(
      'POST',
      '$_sessionsEndpoint/$id/safety',
      body: body,
    );
    return MindcareConversation.fromJson(response);
  }

  Future<SafetyResources> fetchSafetyResources({
    required bool permissionGranted,
    String? countryCode,
    String? adminArea,
  }) async {
    final query = <String, String>{
      'permission': permissionGranted ? 'granted' : 'denied',
    };
    if (countryCode != null) query['country'] = countryCode;
    if (adminArea != null) query['adminArea'] = adminArea;
    final uri = Uri.parse(
      _sessionsEndpoint.replaceFirst('/sessions', '/safety-resources'),
    ).replace(queryParameters: query);
    final response = await _request('GET', uri.toString());
    return SafetyResources.fromJson(response);
  }

  String get _sessionsEndpoint => '$baseUrl/api/relationship/mindcare/sessions';

  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final response = switch (method) {
        'POST' => await _client.post(
          Uri.parse(endpoint),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        _ => await _client.get(Uri.parse(endpoint), headers: headers),
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
        throw MindcareApiException('${decoded?['reason'] ?? 'request_failed'}');
      }
      return decoded!;
    } on http.ClientException {
      throw const MindcareApiException('network_error');
    }
  }
}
