import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/auth/token_storage.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/core/network/endpoints.dart';
import 'package:meow_media/features/auth/data/remote_auth_repository.dart';

void main() {
  test('authenticated request with access token sends Authorization header',
      () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'access-1',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.ok(<String, dynamic>{'ok': true}),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    await client.get<Map<String, dynamic>>('/api/private', authenticated: true);

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.authorization, 'Bearer access-1');
  });

  test('authenticated request without token does not send Authorization header',
      () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage();
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.ok(<String, dynamic>{'ok': true}),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    await client.get<Map<String, dynamic>>('/api/private', authenticated: true);

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.authorization, isNull);
  });

  test('auth login success does not use refresh flow and saves tokens', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.ok(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 'user-1',
          'display_name': 'Meow User',
        },
        'access_token': 'login-access',
        'refresh_token': 'login-refresh',
      }),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);
    final RemoteAuthRepository repository = RemoteAuthRepository(
      apiClient: client,
      tokenStorage: tokenStorage,
    );

    final session = await repository.login(
      email: 'meow@example.com',
      password: 'secret',
    );

    expect(session.isSignedIn, isTrue);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, Endpoints.authLogin);
    expect(adapter.requests.single.authorization, isNull);
    expect(adapter.requests.single.data, <String, dynamic>{
      'email': 'meow@example.com',
      'password': 'secret',
    });
    expect(tokenStorage.accessToken, 'login-access');
    expect(tokenStorage.refreshToken, 'login-refresh');
  });

  test('auth login 401 does not call refresh endpoint or clear tokens', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'existing-access',
      refreshToken: 'existing-refresh',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.unauthorized(),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);
    final RemoteAuthRepository repository = RemoteAuthRepository(
      apiClient: client,
      tokenStorage: tokenStorage,
    );

    await expectLater(
      repository.login(email: 'meow@example.com', password: 'bad-secret'),
      throwsA(isA<ApiError>().having(
        (ApiError error) => error.statusCode,
        'statusCode',
        401,
      )),
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, Endpoints.authLogin);
    expect(tokenStorage.accessToken, 'existing-access');
    expect(tokenStorage.refreshToken, 'existing-refresh');
  });

  test('auth register success does not use refresh flow and saves tokens',
      () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage();
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.ok(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 'user-2',
          'display_name': 'New User',
        },
        'access': 'register-access',
        'refresh': 'register-refresh',
      }),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);
    final RemoteAuthRepository repository = RemoteAuthRepository(
      apiClient: client,
      tokenStorage: tokenStorage,
    );

    final session = await repository.register(
      email: 'new@example.com',
      password: 'secret',
      displayName: 'New User',
    );

    expect(session.isSignedIn, isTrue);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, Endpoints.authRegister);
    expect(adapter.requests.single.authorization, isNull);
    expect(tokenStorage.accessToken, 'register-access');
    expect(tokenStorage.refreshToken, 'register-refresh');
  });

  test('auth refresh endpoint 401 does not recursively refresh', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.unauthorized(),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    await expectLater(
      client.post<Map<String, dynamic>>(
        Endpoints.authRefresh,
        data: <String, dynamic>{'refresh': 'refresh-1'},
        authenticated: true,
      ),
      throwsA(isA<ApiError>().having(
        (ApiError error) => error.statusCode,
        'statusCode',
        401,
      )),
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, Endpoints.authRefresh);
    expect(tokenStorage.accessToken, 'access-1');
    expect(tokenStorage.refreshToken, 'refresh-1');
  });

  test('401 then refresh success retries once with new access token', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'expired-access',
      refreshToken: 'refresh-1',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.unauthorized(),
      _QueuedResponse.ok(<String, dynamic>{
        'access': 'new-access',
        'refresh': 'new-refresh',
      }),
      _QueuedResponse.ok(<String, dynamic>{'ok': true}),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    final Response<Map<String, dynamic>> response = await client.get(
      '/api/private',
      authenticated: true,
    );

    expect(response.data?['ok'], isTrue);
    expect(adapter.requests, hasLength(3));
    expect(adapter.requests[0].path, '/api/private');
    expect(adapter.requests[0].authorization, 'Bearer expired-access');
    expect(adapter.requests[1].path, Endpoints.authRefresh);
    expect(adapter.requests[1].authorization, isNull);
    expect(adapter.requests[1].data, <String, dynamic>{'refresh': 'refresh-1'});
    expect(adapter.requests[2].path, '/api/private');
    expect(adapter.requests[2].authorization, 'Bearer new-access');
    expect(tokenStorage.accessToken, 'new-access');
    expect(tokenStorage.refreshToken, 'new-refresh');
  });

  test('401 then refresh failure clears tokens and throws ApiError', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'expired-access',
      refreshToken: 'refresh-1',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.unauthorized(),
      _QueuedResponse.error(400, <String, dynamic>{'detail': 'Bad refresh'}),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    await expectLater(
      client.get<Map<String, dynamic>>('/api/private', authenticated: true),
      throwsA(
        isA<ApiError>()
            .having((ApiError error) => error.statusCode, 'statusCode', 400)
            .having((ApiError error) => error.message, 'message', 'Bad refresh'),
      ),
    );

    expect(adapter.requests, hasLength(2));
    expect(tokenStorage.accessToken, isNull);
    expect(tokenStorage.refreshToken, isNull);
  });

  test('retry once only when refreshed request is still 401', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'expired-access',
      refreshToken: 'refresh-1',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.unauthorized(),
      _QueuedResponse.ok(<String, dynamic>{'access': 'new-access'}),
      _QueuedResponse.unauthorized(),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    await expectLater(
      client.get<Map<String, dynamic>>('/api/private', authenticated: true),
      throwsA(isA<ApiError>().having(
        (ApiError error) => error.statusCode,
        'statusCode',
        401,
      )),
    );

    expect(adapter.requests, hasLength(3));
    expect(
      adapter.requests.where(
        (_RecordedRequest request) => request.path == Endpoints.authRefresh,
      ),
      hasLength(1),
    );
    expect(tokenStorage.refreshToken, 'refresh-1');
  });

  test('500 does not refresh or clear tokens', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.error(500, <String, dynamic>{'detail': 'Server down'}),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    await expectLater(
      client.get<Map<String, dynamic>>('/api/private', authenticated: true),
      throwsA(
        isA<ApiError>()
            .having((ApiError error) => error.statusCode, 'statusCode', 500)
            .having((ApiError error) => error.message, 'message', 'Server down'),
      ),
    );

    expect(adapter.requests, hasLength(1));
    expect(tokenStorage.accessToken, 'access-1');
    expect(tokenStorage.refreshToken, 'refresh-1');
  });

  test('network error does not refresh or clear tokens', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.networkError(),
    ]);
    final ApiClient client = _client(adapter, tokenStorage);

    await expectLater(
      client.get<Map<String, dynamic>>('/api/private', authenticated: true),
      throwsA(isA<ApiError>().having(
        (ApiError error) => error.statusCode,
        'statusCode',
        isNull,
      )),
    );

    expect(adapter.requests, hasLength(1));
    expect(tokenStorage.accessToken, 'access-1');
    expect(tokenStorage.refreshToken, 'refresh-1');
  });
}

ApiClient _client(_QueueAdapter adapter, _FakeTokenStorage tokenStorage) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
    ..httpClientAdapter = adapter;
  return ApiClient(dio: dio, tokenStorage: tokenStorage);
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._responses);

  final List<_QueuedResponse> _responses;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(_RecordedRequest(options));
    if (_responses.isEmpty) {
      throw DioException(
        requestOptions: options,
        message: 'No queued response for ${options.path}',
      );
    }
    final _QueuedResponse response = _responses.removeAt(0);
    final Object? error = response.error;
    if (error != null) {
      throw DioException(
        requestOptions: options,
        error: error,
        message: error.toString(),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response.data),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _QueuedResponse {
  const _QueuedResponse._({
    required this.statusCode,
    this.data,
    this.error,
  });

  factory _QueuedResponse.ok(Map<String, dynamic> data) {
    return _QueuedResponse._(statusCode: 200, data: data);
  }

  factory _QueuedResponse.unauthorized() {
    return _QueuedResponse.error(
      401,
      <String, dynamic>{'detail': 'Unauthorized'},
    );
  }

  factory _QueuedResponse.error(int statusCode, Map<String, dynamic> data) {
    return _QueuedResponse._(statusCode: statusCode, data: data);
  }

  factory _QueuedResponse.networkError() {
    return const _QueuedResponse._(
      statusCode: 0,
      error: 'network offline',
    );
  }

  final int statusCode;
  final Map<String, dynamic>? data;
  final Object? error;
}

class _RecordedRequest {
  _RecordedRequest(RequestOptions options)
      : path = options.path,
        data = options.data,
        authorization = options.headers['Authorization'] as String?;

  final String path;
  final Object? data;
  final String? authorization;
}

class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clearAccessToken() async {
    accessToken = null;
  }

  @override
  Future<void> clearAllTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<void> clearRefreshToken() async {
    refreshToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    refreshToken = token;
  }
}
