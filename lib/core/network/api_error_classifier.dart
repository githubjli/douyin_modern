import 'api_error.dart';

bool isAuthDeniedError(Object error) {
  return error is ApiError &&
      (error.statusCode == 401 || error.statusCode == 403);
}

bool isTransientError(Object error) {
  if (isAuthDeniedError(error)) return false;
  if (error is ApiError) {
    final int? statusCode = error.statusCode;
    if (statusCode == null) return true;
    if (statusCode >= 500) return true;
    return true;
  }
  return true;
}
