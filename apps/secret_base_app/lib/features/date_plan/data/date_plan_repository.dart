import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/date_plan.dart';

class DatePlanException implements Exception {
  final String reason;
  const DatePlanException(this.reason);

  @override
  String toString() => 'DatePlanException($reason)';
}

class DatePlanCompletion {
  final DatePlan plan;
  final DatePlanAfterglow? afterglow;

  const DatePlanCompletion({required this.plan, this.afterglow});
}

abstract class DatePlanRepository {
  Future<DatePlanPage> list({required bool upcoming, String? cursor});
  Future<DatePlan> create({
    required String planDate,
    String? planTime,
    required String title,
    String? memo,
    int? pinId,
  });
  Future<DatePlan> update(
    int id, {
    String? planDate,
    String? planTime,
    bool clearTime = false,
    String? title,
    String? memo,
  });
  Future<void> remove(int id);

  /// "다녀왔어요". 애프터글로우 방문 표시는 기존 애프터글로우 API가 맡는다.
  Future<DatePlanCompletion> complete(int id);
}

class HttpDatePlanRepository implements DatePlanRepository {
  final String baseUrl;
  final String token;
  final http.Client _client;

  HttpDatePlanRepository({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/date-plans$path').replace(queryParameters: query);

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
      throw DatePlanException('${reason ?? 'request_failed'}');
    }
    return body;
  }

  DatePlan _plan(Map<String, dynamic> body) => DatePlan.fromJson(
    Map<String, dynamic>.from(body['plan'] as Map? ?? const {}),
  );

  @override
  Future<DatePlanPage> list({required bool upcoming, String? cursor}) async {
    final body = _decode(
      await _client.get(
        _uri('', {
          'scope': upcoming ? 'upcoming' : 'past',
          'limit': '20',
          'cursor': ?cursor,
        }),
        headers: _headers,
      ),
    );
    return DatePlanPage(
      plans: [
        for (final item in (body['plans'] as List? ?? const []))
          DatePlan.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      nextCursor: body['next_cursor'] as String?,
    );
  }

  @override
  Future<DatePlan> create({
    required String planDate,
    String? planTime,
    required String title,
    String? memo,
    int? pinId,
  }) async => _plan(
    _decode(
      await _client.post(
        _uri(''),
        headers: _headers,
        body: jsonEncode({
          'plan_date': planDate,
          'plan_time': planTime,
          'title': title,
          'memo': memo,
          'map_pin_id': pinId,
        }),
      ),
    ),
  );

  @override
  Future<DatePlan> update(
    int id, {
    String? planDate,
    String? planTime,
    bool clearTime = false,
    String? title,
    String? memo,
  }) async => _plan(
    _decode(
      await _client.patch(
        _uri('/$id'),
        headers: _headers,
        body: jsonEncode({
          'plan_date': ?planDate,
          if (planTime != null || clearTime) 'plan_time': planTime,
          'title': ?title,
          'memo': ?memo,
        }),
      ),
    ),
  );

  @override
  Future<void> remove(int id) async {
    _decode(await _client.delete(_uri('/$id'), headers: _headers));
  }

  @override
  Future<DatePlanCompletion> complete(int id) async {
    final body = _decode(
      await _client.post(_uri('/$id/complete'), headers: _headers),
    );
    return DatePlanCompletion(
      plan: _plan(body),
      afterglow: DatePlanAfterglow.fromJson(body['afterglow']),
    );
  }

  void close() => _client.close();
}
