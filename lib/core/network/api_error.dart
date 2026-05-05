class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() {
    return 'ApiError(statusCode: $statusCode, code: $code, message: $message)';
  }
}
