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
  final String audience;
  final int? coupleId;
  final String version;
  final String status;
  final String? startedAt;
  final String? updatedAt;
  final AssessmentAttemptProgress progress;
  final List<AssessmentAnswer> answers;

  const AssessmentAttempt({
    required this.id,
    required this.assessmentCode,
    required this.audience,
    required this.coupleId,
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
        audience: '${json['audience'] ?? 'individual'}',
        coupleId: json['coupleId'] == null
            ? null
            : int.tryParse('${json['coupleId']}'),
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

class CoupleAssessmentDimensionResult {
  final String key;
  final String title;
  final int pairScore;
  final int alignmentScore;

  const CoupleAssessmentDimensionResult({
    required this.key,
    required this.title,
    required this.pairScore,
    required this.alignmentScore,
  });

  factory CoupleAssessmentDimensionResult.fromJson(Map<String, dynamic> json) =>
      CoupleAssessmentDimensionResult(
        key: '${json['key'] ?? ''}',
        title: '${json['title'] ?? ''}',
        pairScore: int.tryParse('${json['pairScore']}') ?? 0,
        alignmentScore: int.tryParse('${json['alignmentScore']}') ?? 0,
      );
}

class CoupleAssessmentResult {
  final String assessmentCode;
  final String version;
  final List<CoupleAssessmentDimensionResult> dimensions;
  final int overallScore;
  final int overallAlignmentScore;
  final String relationshipPatternKey;
  final String relationshipPattern;
  final List<String> conversationPrompts;
  final String disclaimer;

  const CoupleAssessmentResult({
    required this.assessmentCode,
    required this.version,
    required this.dimensions,
    required this.overallScore,
    required this.overallAlignmentScore,
    required this.relationshipPatternKey,
    required this.relationshipPattern,
    required this.conversationPrompts,
    required this.disclaimer,
  });

  factory CoupleAssessmentResult.fromJson(Map<String, dynamic> json) =>
      CoupleAssessmentResult(
        assessmentCode: '${json['assessmentCode'] ?? ''}',
        version: '${json['version'] ?? ''}',
        dimensions: (json['dimensions'] as List? ?? const [])
            .map(
              (dimension) => CoupleAssessmentDimensionResult.fromJson(
                Map<String, dynamic>.from(dimension as Map),
              ),
            )
            .toList(growable: false),
        overallScore: int.tryParse('${json['overallScore']}') ?? 0,
        overallAlignmentScore:
            int.tryParse('${json['overallAlignmentScore']}') ?? 0,
        relationshipPatternKey: '${json['relationshipPatternKey'] ?? ''}',
        relationshipPattern: '${json['relationshipPattern'] ?? ''}',
        conversationPrompts: (json['conversationPrompts'] as List? ?? const [])
            .map((prompt) => '$prompt')
            .toList(growable: false),
        disclaimer: '${json['disclaimer'] ?? ''}',
      );
}

class CoupleAssessmentState {
  final String status;
  final int completedMemberCount;
  final int requiredMemberCount;
  final CoupleAssessmentResult? result;

  const CoupleAssessmentState({
    required this.status,
    required this.completedMemberCount,
    required this.requiredMemberCount,
    required this.result,
  });

  factory CoupleAssessmentState.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    return CoupleAssessmentState(
      status: '${json['status'] ?? 'pending'}',
      completedMemberCount:
          int.tryParse('${json['completedMemberCount']}') ?? 0,
      requiredMemberCount: int.tryParse('${json['requiredMemberCount']}') ?? 2,
      result: rawResult is Map
          ? CoupleAssessmentResult.fromJson(
              Map<String, dynamic>.from(rawResult),
            )
          : null,
    );
  }
}

class AssessmentHistoryItem {
  final int id;
  final String version;
  final String? createdAt;
  final AssessmentResult result;
  final List<AssessmentHistoryAnswer> answers;

  const AssessmentHistoryItem({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.result,
    this.answers = const [],
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
      answers: (json['answers'] as List? ?? const [])
          .map(
            (answer) => AssessmentHistoryAnswer.fromJson(
              Map<String, dynamic>.from(answer as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class AssessmentHistoryAnswer {
  final String questionKey;
  final String prompt;
  final int order;
  final String? dimensionTitle;
  final int value;
  final String label;
  final bool reverseScored;

  const AssessmentHistoryAnswer({
    required this.questionKey,
    required this.prompt,
    required this.order,
    required this.dimensionTitle,
    required this.value,
    required this.label,
    required this.reverseScored,
  });

  factory AssessmentHistoryAnswer.fromJson(Map<String, dynamic> json) =>
      AssessmentHistoryAnswer(
        questionKey: '${json['questionKey'] ?? ''}',
        prompt: '${json['prompt'] ?? ''}',
        order: int.tryParse('${json['order']}') ?? 0,
        dimensionTitle: json['dimensionTitle'] == null
            ? null
            : '${json['dimensionTitle']}',
        value: int.tryParse('${json['value']}') ?? 0,
        label: '${json['label'] ?? ''}',
        reverseScored: json['reverseScored'] == true,
      );
}

class AssessmentComparisonDimension {
  final String key;
  final String title;
  final int previous;
  final int current;
  final int delta;
  final AssessmentComparisonAlignment? alignment;

  const AssessmentComparisonDimension({
    required this.key,
    required this.title,
    required this.previous,
    required this.current,
    required this.delta,
    required this.alignment,
  });

  factory AssessmentComparisonDimension.fromJson(Map<String, dynamic> json) {
    final rawAlignment = json['alignment'];
    return AssessmentComparisonDimension(
      key: '${json['key'] ?? ''}',
      title: '${json['title'] ?? ''}',
      previous: int.tryParse('${json['previous'] ?? 0}') ?? 0,
      current: int.tryParse('${json['current'] ?? 0}') ?? 0,
      delta: int.tryParse('${json['delta'] ?? 0}') ?? 0,
      alignment: rawAlignment is Map
          ? AssessmentComparisonAlignment.fromJson(
              Map<String, dynamic>.from(rawAlignment),
            )
          : null,
    );
  }
}

class AssessmentComparisonAlignment {
  final int previous;
  final int current;
  final int delta;

  const AssessmentComparisonAlignment({
    required this.previous,
    required this.current,
    required this.delta,
  });

  factory AssessmentComparisonAlignment.fromJson(Map<String, dynamic> json) =>
      AssessmentComparisonAlignment(
        previous: int.tryParse('${json['previous'] ?? 0}') ?? 0,
        current: int.tryParse('${json['current'] ?? 0}') ?? 0,
        delta: int.tryParse('${json['delta'] ?? 0}') ?? 0,
      );
}

class AssessmentComparisonOverall {
  final int previous;
  final int current;
  final int delta;
  final AssessmentComparisonAlignment? alignment;

  const AssessmentComparisonOverall({
    required this.previous,
    required this.current,
    required this.delta,
    required this.alignment,
  });

  factory AssessmentComparisonOverall.fromJson(Map<String, dynamic> json) {
    final rawAlignment = json['alignment'];
    return AssessmentComparisonOverall(
      previous: int.tryParse('${json['previous'] ?? 0}') ?? 0,
      current: int.tryParse('${json['current'] ?? 0}') ?? 0,
      delta: int.tryParse('${json['delta'] ?? 0}') ?? 0,
      alignment: rawAlignment is Map
          ? AssessmentComparisonAlignment.fromJson(
              Map<String, dynamic>.from(rawAlignment),
            )
          : null,
    );
  }
}

class AssessmentComparison {
  final String status;
  final bool available;
  final String scope;
  final String metric;
  final String visualization;
  final String message;
  final AssessmentComparisonOverall? overall;
  final List<AssessmentComparisonDimension> dimensions;
  final String disclaimer;

  const AssessmentComparison({
    required this.status,
    required this.available,
    required this.scope,
    required this.metric,
    required this.visualization,
    required this.message,
    required this.overall,
    required this.dimensions,
    required this.disclaimer,
  });

  factory AssessmentComparison.fromJson(Map<String, dynamic> json) {
    final rawOverall = json['overall'];
    return AssessmentComparison(
      status: '${json['status'] ?? ''}',
      available: json['available'] == true,
      scope: '${json['scope'] ?? 'personal'}',
      metric: '${json['metric'] ?? 'dimensionScore'}',
      visualization: '${json['visualization'] ?? 'bar_or_line'}',
      message: '${json['message'] ?? '이 검사를 한 번 더 완료하면 최근 변화를 볼 수 있어요.'}',
      overall: rawOverall is Map
          ? AssessmentComparisonOverall.fromJson(
              Map<String, dynamic>.from(rawOverall),
            )
          : null,
      dimensions: (json['dimensions'] as List? ?? const [])
          .map(
            (item) => AssessmentComparisonDimension.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      disclaimer: '${json['disclaimer'] ?? ''}',
    );
  }

  String get accessibleMessage {
    final value = overall;
    if (value == null) return message;
    final sign = value.delta > 0 ? '+' : '';
    return '$message 전체 점수 ${value.previous}점에서 ${value.current}점, 변화량 $sign${value.delta}점이에요.';
  }
}

class ExplanationGeneration {
  final int id;
  final String status;
  final String provider;
  final String? model;
  final String promptVersion;
  final String contextVersion;
  final String? explanation;
  final String? errorCode;

  const ExplanationGeneration({
    required this.id,
    required this.status,
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.contextVersion,
    required this.explanation,
    required this.errorCode,
  });

  factory ExplanationGeneration.fromJson(Map<String, dynamic> json) =>
      ExplanationGeneration(
        id: int.tryParse('${json['id']}') ?? 0,
        status: '${json['status'] ?? ''}',
        provider: '${json['provider'] ?? ''}',
        model: json['model'] == null ? null : '${json['model']}',
        promptVersion: '${json['promptVersion'] ?? ''}',
        contextVersion: '${json['contextVersion'] ?? ''}',
        explanation: json['explanation'] == null
            ? null
            : '${json['explanation']}',
        errorCode: json['errorCode'] == null ? null : '${json['errorCode']}',
      );
}

class ExplanationState {
  final String status;
  final ExplanationGeneration? generation;

  const ExplanationState({required this.status, required this.generation});

  factory ExplanationState.fromJson(Map<String, dynamic> json) {
    final rawGeneration = json['generation'];
    return ExplanationState(
      status: '${json['status'] ?? 'idle'}',
      generation: rawGeneration is Map
          ? ExplanationGeneration.fromJson(
              Map<String, dynamic>.from(rawGeneration),
            )
          : null,
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

  Future<AssessmentAttempt> startCoupleOrResume(String code) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/relationship/couple-assessments/$code/attempt'),
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

  Future<CoupleAssessmentState> submitCouple(int attemptId) async {
    try {
      final response = await _client.post(
        Uri.parse(
          '$baseUrl/api/relationship/couple-assessment-attempts/$attemptId/submit',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      return CoupleAssessmentState.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<CoupleAssessmentState> fetchCoupleResult(String code) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api/relationship/couple-assessment-results/$code/current',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      return CoupleAssessmentState.fromJson(_successfulBody(response));
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

  Future<AssessmentComparison> fetchComparison(
    String code, {
    bool couple = false,
  }) async {
    try {
      final path = couple
          ? '/api/relationship/couple-assessment-results/$code/comparison'
          : '/api/relationship/assessment-results/$code/comparison';
      final response = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return AssessmentComparison.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<ExplanationState> fetchPersonalExplanation(String code) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api/relationship/explanations/personal/$code/current',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      return ExplanationState.fromJson(_successfulBody(response));
    } on http.ClientException {
      throw const AssessmentAttemptApiException('network_error');
    } on FormatException {
      throw const AssessmentAttemptApiException('invalid_response');
    }
  }

  Future<ExplanationState> requestPersonalExplanation(String code) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/relationship/explanations/personal/$code'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return ExplanationState.fromJson(_successfulBody(response));
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
