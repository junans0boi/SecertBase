import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/two_answer.dart';

class TwoAnswersException implements Exception {
  final String reason;
  const TwoAnswersException(this.reason);

  @override
  String toString() => 'TwoAnswersException($reason)';
}

abstract class TwoAnswersRepository {
  Future<TwoAnswerCard> today();
  Future<TwoAnswerCard> answerToday(String body);
  Future<TwoAnswerHistoryPage> history({int? cursor});
  Future<List<TwoAnswerCard>> missed();
  Future<TwoAnswerCard> answerLate(int id, String body);

  /// 열린 카드를 MomentLoop 글 기록으로 남긴다.
  Future<void> saveAsMoment(TwoAnswerCard card);
}

class HttpTwoAnswersRepository implements TwoAnswersRepository {
  final String baseUrl;
  final String token;
  final http.Client _client;

  HttpTwoAnswersRepository({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$baseUrl/api/two-answers$path',
  ).replace(queryParameters: query);

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] == false) {
      final reason = body['reason'] ?? (body['error'] as Map?)?['code'];
      throw TwoAnswersException('${reason ?? 'request_failed'}');
    }
    return body;
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  @override
  Future<TwoAnswerCard> today() async {
    final body = _decode(await _client.get(_uri('/today'), headers: _headers));
    return TwoAnswerCard.fromJson(_map(body['today']));
  }

  @override
  Future<TwoAnswerCard> answerToday(String text) async {
    final body = _decode(
      await _client.put(
        _uri('/today/answer'),
        headers: _headers,
        body: jsonEncode({'body': text}),
      ),
    );
    return TwoAnswerCard.fromJson(_map(body['today']));
  }

  @override
  Future<TwoAnswerHistoryPage> history({int? cursor}) async {
    final body = _decode(
      await _client.get(
        _uri('/history', {if (cursor != null) 'cursor': '$cursor'}),
        headers: _headers,
      ),
    );
    return TwoAnswerHistoryPage(
      items: [
        for (final item in (body['items'] as List? ?? const []))
          TwoAnswerCard.fromJson(_map(item)),
      ],
      nextCursor: int.tryParse('${body['next_cursor']}'),
    );
  }

  @override
  Future<List<TwoAnswerCard>> missed() async {
    final body = _decode(await _client.get(_uri('/missed'), headers: _headers));
    return [
      for (final item in (body['items'] as List? ?? const []))
        TwoAnswerCard.fromJson(_map(item)),
    ];
  }

  @override
  Future<TwoAnswerCard> answerLate(int id, String text) async {
    final body = _decode(
      await _client.post(
        _uri('/$id/answer-late'),
        headers: _headers,
        body: jsonEncode({'body': text}),
      ),
    );
    return TwoAnswerCard.fromJson(_map(body['question']));
  }

  @override
  Future<void> saveAsMoment(TwoAnswerCard card) async {
    final caption = [
      '마주 열기 · ${card.question}',
      '나: ${card.myBody ?? ''}',
      '상대: ${card.partnerBody ?? ''}',
    ].join('\n');
    final response = await _client.post(
      Uri.parse('$baseUrl/api/setlog'),
      headers: _headers,
      body: jsonEncode({
        'caption': caption,
        'media_type': 'text',
        'taken_at': card.businessDate,
      }),
    );
    _decode(response);
  }

  void close() => _client.close();
}
