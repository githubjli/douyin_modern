import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import 'api_error.dart';
import 'endpoints.dart';

class ApiClient {
  ApiClient({
    Dio? dio,
    TokenStorage? tokenStorage,
    String? baseUrl,
  })  : _tokenStorage = tokenStorage ?? TokenStorage(),
        _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl ?? defaultBaseUrl));

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    try {
      final Options options = await _buildOptions(authenticated: authenticated);
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      if (_shouldRefresh(
        authenticated: authenticated,
        path: path,
        error: error,
      )) {
        return _refreshAndRetry<T>(
          () async {
            final Options retryOptions = await _buildOptions(
              authenticated: authenticated,
            );
            return _dio.get<T>(
              path,
              queryParameters: queryParameters,
              options: retryOptions,
            );
          },
          originalError: error,
        );
      }
      throw _mapDioError(error);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    try {
      final Options options = await _buildOptions(authenticated: authenticated);
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      if (_shouldRefresh(
        authenticated: authenticated,
        path: path,
        error: error,
      )) {
        return _refreshAndRetry<T>(
          () async {
            final Options retryOptions = await _buildOptions(
              authenticated: authenticated,
            );
            return _dio.post<T>(
              path,
              data: data,
              queryParameters: queryParameters,
              options: retryOptions,
            );
          },
          originalError: error,
        );
      }
      throw _mapDioError(error);
    }
  }

  Future<Options> _buildOptions({required bool authenticated}) async {
    if (!authenticated) {
      return Options();
    }

    final String? token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      return Options();
    }

    return Options(
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
  }

  bool _shouldRefresh({
    required bool authenticated,
    required String path,
    required DioException error,
  }) {
    return authenticated &&
        error.response?.statusCode == 401 &&
        !_isAuthEndpoint(path);
  }

  bool _isAuthEndpoint(String path) {
    final String normalizedPath = _normalizeEndpointPath(path);
    return normalizedPath == _normalizeEndpointPath(Endpoints.authLogin) ||
        normalizedPath == _normalizeEndpointPath(Endpoints.authRegister) ||
        normalizedPath == _normalizeEndpointPath(Endpoints.authRefresh);
  }

  String _normalizeEndpointPath(String path) {
    final Uri? uri = Uri.tryParse(path);
    String normalizedPath = uri?.path ?? path.split('?').first;
    if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
    }
    return normalizedPath;
  }

  bool _isRefreshAuthFailure(DioException error) {
    final int? statusCode = error.response?.statusCode;
    // Only confirmed refresh credential failures clear tokens. Do not include
    // 422 unless the backend contract explicitly defines it as auth failure.
    return statusCode == 400 || statusCode == 401 || statusCode == 403;
  }

  Future<Response<T>> _refreshAndRetry<T>(
    Future<Response<T>> Function() retry, {
    required DioException originalError,
  }) async {
    final String? refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw _mapDioError(originalError);
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        Endpoints.authRefresh,
        data: <String, dynamic>{'refresh': refreshToken},
      );
      await _persistRefreshTokens(response.data ?? <String, dynamic>{});
    } on DioException catch (refreshError) {
      if (_isRefreshAuthFailure(refreshError)) {
        await _tokenStorage.clearAllTokens();
        throw _mapDioError(originalError);
      }
      throw _mapDioError(refreshError);
    } catch (refreshError) {
      throw ApiError(message: refreshError.toString());
    }

    try {
      return await retry();
    } on DioException catch (retryError) {
      throw _mapDioError(retryError);
    }
  }

  Future<void> _persistRefreshTokens(Map<String, dynamic> data) async {
    final String? accessToken = _readString(
      data,
      const <String>['access', 'access_token'],
    );
    final String? refreshToken = _readString(
      data,
      const <String>['refresh', 'refresh_token'],
    );

    if (accessToken != null && accessToken.isNotEmpty) {
      await _tokenStorage.writeAccessToken(accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _tokenStorage.writeRefreshToken(refreshToken);
    }
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is num) return value.toString();
    }
    return null;
  }

  ApiError _mapDioError(DioException error) {
    final int? statusCode = error.response?.statusCode;
    final dynamic data = error.response?.data;
    String? code;
    String message = 'Network request failed';

    if (data is Map<String, dynamic>) {
      if (data['code'] is String) code = data['code'] as String;
      if (data['message'] is String) message = data['message'] as String;
      if (data['detail'] is String) message = data['detail'] as String;
    } else if (error.message != null && error.message!.isNotEmpty) {
      message = error.message!;
    }

    return ApiError(message: message, statusCode: statusCode, code: code);
  }
}
