import 'dart:convert';

import 'package:http/http.dart' as http;

enum AssessmentAudience { individual, couple }

enum AssessmentCompletionStatus { notStarted, inProgress, completed }

AssessmentAudience _audienceFromJson(Object? value) => switch (value) {
  'individual' => AssessmentAudience.individual,
  'couple' => AssessmentAudience.couple,
  _ => throw const FormatException('Unknown assessment audience'),
};

AssessmentCompletionStatus _completionStatusFromJson(Object? value) =>
    switch (value) {
      'in_progress' => AssessmentCompletionStatus.inProgress,
      'completed' => AssessmentCompletionStatus.completed,
      'not_started' => AssessmentCompletionStatus.notStarted,
      _ => throw const FormatException('Unknown assessment completion status'),
    };

int _requiredInt(Object? value) {
  if (value is int) return value;
  final parsed = int.tryParse('$value');
  if (parsed == null) throw const FormatException('Invalid assessment number');
  return parsed;
}

class LikertOption {
  final int value;
  final String label;

  const LikertOption({required this.value, required this.label});

  factory LikertOption.fromJson(Map<String, dynamic> json) => LikertOption(
    value: _requiredInt(json['value']),
    label: '${json['label'] ?? ''}',
  );
}

class AssessmentDimension {
  final String key;
  final String title;
  final int order;

  const AssessmentDimension({
    required this.key,
    required this.title,
    required this.order,
  });

  factory AssessmentDimension.fromJson(Map<String, dynamic> json) =>
      AssessmentDimension(
        key: '${json['key'] ?? ''}',
        title: '${json['title'] ?? ''}',
        order: _requiredInt(json['order']),
      );
}

class AssessmentQuestion {
  final String key;
  final String prompt;
  final String dimensionKey;
  final bool reverseScored;
  final int order;
  final List<LikertOption> likertScale;

  const AssessmentQuestion({
    required this.key,
    required this.prompt,
    required this.dimensionKey,
    required this.reverseScored,
    required this.order,
    required this.likertScale,
  });

  factory AssessmentQuestion.fromJson(
    Map<String, dynamic> json,
  ) => AssessmentQuestion(
    key: '${json['key'] ?? ''}',
    prompt: '${json['prompt'] ?? ''}',
    dimensionKey: '${json['dimensionKey'] ?? ''}',
    reverseScored: json['reverseScored'] == true,
    order: _requiredInt(json['order']),
    likertScale: (json['likertScale'] as List? ?? const [])
        .map(
          (option) =>
              LikertOption.fromJson(Map<String, dynamic>.from(option as Map)),
        )
        .toList(growable: false),
  );
}

class AssessmentCatalogItem {
  final String code;
  final AssessmentAudience audience;
  final String title;
  final String description;
  final String version;
  final int candidateQuestionCount;
  final int activeQuestionCount;
  final AssessmentCompletionStatus completionStatus;
  final bool hasResultHistory;
  final List<AssessmentDimension> dimensions;
  final List<AssessmentQuestion> questions;

  const AssessmentCatalogItem({
    required this.code,
    required this.audience,
    required this.title,
    required this.description,
    required this.version,
    required this.candidateQuestionCount,
    required this.activeQuestionCount,
    required this.completionStatus,
    this.hasResultHistory = false,
    required this.dimensions,
    required this.questions,
  });

  factory AssessmentCatalogItem.fromJson(Map<String, dynamic> json) {
    final dimensions = (json['dimensions'] as List? ?? const [])
        .map(
          (dimension) => AssessmentDimension.fromJson(
            Map<String, dynamic>.from(dimension as Map),
          ),
        )
        .toList(growable: false);
    final questions =
        (json['questions'] as List? ?? const [])
            .map(
              (question) => AssessmentQuestion.fromJson(
                Map<String, dynamic>.from(question as Map),
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.order.compareTo(right.order));
    return AssessmentCatalogItem(
      code: '${json['code'] ?? ''}',
      audience: _audienceFromJson(json['audience']),
      title: '${json['title'] ?? ''}',
      description: '${json['description'] ?? ''}',
      version: '${json['version'] ?? ''}',
      candidateQuestionCount: _requiredInt(json['candidateQuestionCount']),
      activeQuestionCount: _requiredInt(json['activeQuestionCount']),
      completionStatus: _completionStatusFromJson(json['completionStatus']),
      hasResultHistory: json['hasResultHistory'] == true,
      dimensions: dimensions,
      questions: questions,
    );
  }
}

class AssessmentCatalogApiException implements Exception {
  final String reason;

  const AssessmentCatalogApiException(this.reason);

  @override
  String toString() => 'AssessmentCatalogApiException($reason)';
}

class AssessmentCatalogApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  AssessmentCatalogApi({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void close() => _client.close();

  Future<List<AssessmentCatalogItem>> fetch() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/relationship/assessments'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _successfulBody(response);
      final rawAssessments = body['assessments'];
      if (rawAssessments is! List) {
        throw const FormatException('Missing assessments');
      }
      return rawAssessments
          .map(
            (assessment) => AssessmentCatalogItem.fromJson(
              Map<String, dynamic>.from(assessment as Map),
            ),
          )
          .toList(growable: false);
    } on http.ClientException {
      throw const AssessmentCatalogApiException('network_error');
    } on FormatException {
      throw const AssessmentCatalogApiException('invalid_response');
    }
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
      throw AssessmentCatalogApiException(
        '${body?['reason'] ?? 'request_failed'}',
      );
    }
    return body!;
  }
}
