import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import 'api_error.dart';

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
    } on DioException catch (e) {
      throw _mapDioError(e);
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
    } on DioException catch (e) {
      throw _mapDioError(e);
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
