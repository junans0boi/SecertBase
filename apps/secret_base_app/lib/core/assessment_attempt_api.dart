import 'dart:convert';

import 'package:http/http.dart' as http;

class AssessmentAnswer {
  final String questionKey;
  final int value;
  final String? savedAt;

  const AssessmentAnswer({
    required this.questionKey,
    required this.value,
    required this.savedAt,
  });

  factory AssessmentAnswer.fromJson(Map<String, dynamic> json) =>
      AssessmentAnswer(
        questionKey: '${json['questionKey'] ?? ''}',
        value: int.tryParse('${json['value']}') ?? 0,
        savedAt: json['savedAt'] == null ? null : '${json['savedAt']}',
      );
}

class AssessmentAttemptProgress {
  final int answeredCount;
  final int totalCount;
  final int percentage;
  final String? lastSavedAt;

  const AssessmentAttemptProgress({
    required this.answeredCount,
    required this.totalCount,
    required this.percentage,
    required this.lastSavedAt,
  });

  factory AssessmentAttemptProgress.fromJson(Map<String, dynamic> json) =>
      AssessmentAttemptProgress(
        answeredCount: int.tryParse('${json['answeredCount']}') ?? 0,
        totalCount: int.tryParse('${json['totalCount']}') ?? 0,
        percentage: int.tryParse('${json['percentage']}') ?? 0,
        lastSavedAt: json['lastSavedAt'] == null
            ? null
            : '${json['lastSavedAt']}',
      );
}

class AssessmentAttempt {
  final int id;
  final String assessmentCode;
  final String version;
  final String status;
  final String? startedAt;
  final String? updatedAt;
  final AssessmentAttemptProgress progress;
  final List<AssessmentAnswer> answers;

  const AssessmentAttempt({
    required this.id,
    required this.assessmentCode,
    required this.version,
    required this.status,
    required this.startedAt,
    required this.updatedAt,
    required this.progress,
    required this.answers,
  });

  factory AssessmentAttempt.fromJson(Map<String, dynamic> json) =>
      AssessmentAttempt(
        id: int.tryParse('${json['id']}') ?? 0,
        assessmentCode: '${json['assessmentCode'] ?? ''}',
        version: '${json['version'] ?? ''}',
        status: '${json['status'] ?? ''}',
        startedAt: json['startedAt'] == null ? null : '${json['startedAt']}',
        updatedAt: json['updatedAt'] == null ? null : '${json['updatedAt']}',
        progress: AssessmentAttemptProgress.fromJson(
          Map<String, dynamic>.from(json['progress'] as Map),
        ),
        answers: (json['answers'] as List? ?? const [])
            .map(
              (answer) => AssessmentAnswer.fromJson(
                Map<String, dynamic>.from(answer as Map),
              ),
            )
            .toList(growable: false),
      );

  Map<String, int> get answerByQuestion => {
    for (final answer in answers) answer.questionKey: answer.value,
  };
}

class AssessmentDimensionResult {
  final String key;
  final String title;
  final int score;
  final double mean;
  final int answerCount;

  const AssessmentDimensionResult({
    required this.key,
    required this.title,
    required this.score,
    required this.mean,
    required this.answerCount,
  });

  factory AssessmentDimensionResult.fromJson(Map<String, dynamic> json) =>
      AssessmentDimensionResult(
        key: '${json['key'] ?? ''}',
        title: '${json['title'] ?? ''}',
        score: int.tryParse('${json['score']}') ?? 0,
        mean: double.tryParse('${json['mean']}') ?? 0,
        answerCount: int.tryParse('${json['answerCount']}') ?? 0,
      );
}

class AssessmentResult {
  final String assessmentCode;
  final String version;
  final List<AssessmentDimensionResult> dimensions;
  final int overallScore;
  final String overallTendencyKey;
  final String overallTendency;
  final String disclaimer;

  const AssessmentResult({
    required this.assessmentCode,
    required this.version,
    required this.dimensions,
    required this.overallScore,
    required this.overallTendencyKey,
    required this.overallTendency,
    required this.disclaimer,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) =>
      AssessmentResult(
        assessmentCode: '${json['assessmentCode'] ?? ''}',
        version: '${json['version'] ?? ''}',
        dimensions: (json['dimensions'] as List? ?? const [])
            .map(
              (dimension) => AssessmentDimensionResult.fromJson(
                Map<String, dynamic>.from(dimension as Map),
              ),
            )
            .toList(growable: false),
        overallScore: int.tryParse('${json['overallScore']}') ?? 0,
        overallTendencyKey: '${json['overallTendencyKey'] ?? ''}',
        overallTendency: '${json['overallTendency'] ?? ''}',
        disclaimer: '${json['disclaimer'] ?? ''}',
      );
}

class AssessmentHistoryItem {
  final int id;
  final String version;
  final String? createdAt;
  final AssessmentResult result;

  const AssessmentHistoryItem({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.result,
  });

  factory AssessmentHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    if (rawResult is! Map) {
      throw const FormatException('Invalid history result');
    }
    return AssessmentHistoryItem(
      id: int.tryParse('${json['id']}') ?? 0,
      version: '${json['version'] ?? ''}',
      createdAt: json['createdAt'] == null ? null : '${json['createdAt']}',
      result: AssessmentResult.fromJson(Map<String, dynamic>.from(rawResult)),
    );
  }
}

class AssessmentAttemptApiException implements Exception {
  final String reason;

  const AssessmentAttemptApiException(this.reason);

  @override
  String toString() => 'AssessmentAttemptApiException($reason)';
}

class AssessmentAttemptApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  AssessmentAttemptApi({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void close() => _client.close();

  Future<AssessmentAttempt?> fetchCurrent(String code) async {
    try {
      final response = await _client.get(
        _attemptEndpoint(code),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _successfulBody(response);
      final rawAttempt = body['attempt'];
      if (rawAttempt == null) return null;
      if (rawAttempt is! Map) throw const FormatException('Invalid attempt');
      return AssessmentAttempt.fromJson(Map<String, dynamic>.from(rawAttempt));
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<AssessmentAttempt> startOrResume(String code) async {
    try {
      final response = await _client.post(
        _attemptEndpoint(code),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _successfulBody(response);
      return _attemptFromBody(body);
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<AssessmentAttempt> saveAnswer(
    int attemptId,
    String questionKey,
    int value,
  ) async {
    try {
      final response = await _client.patch(
        Uri.parse(
          '$baseUrl/api/relationship/assessment-attempts/$attemptId/answers/$questionKey',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'value': value}),
      );
      return _attemptFromBody(_successfulBody(response));
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<AssessmentResult> submit(int attemptId) async {
    try {
      final response = await _client.post(
        Uri.parse(
          '$baseUrl/api/relationship/assessment-attempts/$attemptId/submit',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _successfulBody(response);
      final rawResult = body['result'];
      if (rawResult is! Map) throw const FormatException('Missing result');
      return AssessmentResult.fromJson(Map<String, dynamic>.from(rawResult));
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<AssessmentResult?> fetchCurrentResult(String code) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/relationship/assessment-results/$code/current'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _successfulBody(response);
      final rawResult = body['result'];
      if (rawResult == null) return null;
      if (rawResult is! Map) throw const FormatException('Invalid result');
      return AssessmentResult.fromJson(Map<String, dynamic>.from(rawResult));
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<List<AssessmentHistoryItem>> fetchHistory(String code) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/relationship/assessment-results/$code/history'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _successfulBody(response);
      final rawHistory = body['history'];
      if (rawHistory is! List) {
        throw const FormatException('Missing history');
      }
      return rawHistory
          .map(
            (item) => AssessmentHistoryItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Uri _attemptEndpoint(String code) =>
      Uri.parse('$baseUrl/api/relationship/assessments/$code/attempt');

  AssessmentAttempt _attemptFromBody(Map<String, dynamic> body) {
    final rawAttempt = body['attempt'];
    if (rawAttempt is! Map) throw const FormatException('Missing attempt');
    return AssessmentAttempt.fromJson(Map<String, dynamic>.from(rawAttempt));
  }

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
      throw AssessmentAttemptApiException(
        '${body?['reason'] ?? 'request_failed'}',
      );
    }
    return body!;
  }
}
