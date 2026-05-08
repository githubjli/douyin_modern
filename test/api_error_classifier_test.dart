import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/core/network/api_error_classifier.dart';

void main() {
  group('isAuthDeniedError', () {
    test('returns true for 401', () {
      const ApiError error = ApiError(message: 'Unauthorized', statusCode: 401);

      expect(isAuthDeniedError(error), isTrue);
    });

    test('returns true for 403', () {
      const ApiError error = ApiError(message: 'Forbidden', statusCode: 403);

      expect(isAuthDeniedError(error), isTrue);
    });

    test('does not treat 400 as auth denied', () {
      const ApiError error = ApiError(message: 'Bad request', statusCode: 400);

      expect(isAuthDeniedError(error), isFalse);
    });

    test('does not treat 404 as auth denied', () {
      const ApiError error = ApiError(message: 'Not found', statusCode: 404);

      expect(isAuthDeniedError(error), isFalse);
    });
  });

  group('isTransientError', () {
    test('returns true for 500', () {
      const ApiError error = ApiError(message: 'Server error', statusCode: 500);

      expect(isTransientError(error), isTrue);
    });

    test('returns true for null statusCode', () {
      const ApiError error = ApiError(message: 'Network unavailable');

      expect(isTransientError(error), isTrue);
    });

    test('returns true for generic exceptions', () {
      expect(isTransientError(Exception('offline')), isTrue);
    });
  });
}
