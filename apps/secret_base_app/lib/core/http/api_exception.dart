class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  final Object? cause;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.cause,
  });

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code, message: $message)';
}
