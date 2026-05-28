import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/auth/token_storage.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/core/network/endpoints.dart';
import 'package:meow_media/features/auth/application/auth_providers.dart';
import 'package:meow_media/features/auth/application/auth_state.dart';
import 'package:meow_media/features/auth/data/remote_auth_repository.dart';

void main() {
  test('login token-only response saves tokens before loading current session',
      () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage();
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.ok(<String, dynamic>{
        'access': 'login-access',
        'refresh': 'login-refresh',
      }),
      _QueuedResponse.ok(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 'user-1',
          'display_name': 'Meow User',
        },
      }),
    ]);
    final RemoteAuthRepository repository = _repository(adapter, tokenStorage);

    final session = await repository.login(
      email: 'meow@example.com',
      password: 'secret',
    );

    expect(session.isSignedIn, isTrue);
    expect(session.userId, 'user-1');
    expect(session.displayName, 'Meow User');
    expect(tokenStorage.accessToken, 'login-access');
    expect(tokenStorage.refreshToken, 'login-refresh');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].path, Endpoints.authLogin);
    expect(adapter.requests[0].authorization, isNull);
    expect(adapter.requests[1].path, Endpoints.authMe);
    expect(adapter.requests[1].authorization, 'Bearer login-access');
  });

  test('login token-only response surfaces current session transient failure',
      () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage();
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.ok(<String, dynamic>{
        'access': 'login-access',
        'refresh': 'login-refresh',
      }),
      _QueuedResponse.error(500, <String, dynamic>{'detail': 'Server down'}),
    ]);
    final RemoteAuthRepository repository = _repository(adapter, tokenStorage);

    await expectLater(
      repository.login(email: 'meow@example.com', password: 'secret'),
      throwsA(isA<ApiError>()
          .having((ApiError error) => error.statusCode, 'statusCode', 500)
          .having((ApiError error) => error.message, 'message', 'Server down')),
    );

    expect(tokenStorage.accessToken, 'login-access');
    expect(tokenStorage.refreshToken, 'login-refresh');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[1].path, Endpoints.authMe);
    expect(adapter.requests[1].authorization, 'Bearer login-access');
  });

  test('AuthController.login ends signed-in for token-only login response',
      () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage();
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      _QueuedResponse.ok(<String, dynamic>{
        'access_token': 'login-access',
        'refresh_token': 'login-refresh',
      }),
      _QueuedResponse.ok(<String, dynamic>{
        'id': 'user-1',
        'display_name': 'Meow User',
      }),
    ]);
    final RemoteAuthRepository repo = _repository(adapter, tokenStorage);
    final ProviderContainer container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'meow@example.com', password: 'secret');

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.signedIn);
    expect(state.session?.userId, 'user-1');
    expect(tokenStorage.accessToken, 'login-access');
    expect(adapter.requests.map((_RecordedRequest request) => request.path),
        <String>[Endpoints.authLogin, Endpoints.authMe]);
  });

  test('register returns not-signed-in session after 201', () async {
    final _FakeTokenStorage tokenStorage = _FakeTokenStorage();
    final _QueueAdapter adapter = _QueueAdapter(<_QueuedResponse>[
      // POST /register — user object, no tokens (201)
      _QueuedResponse.ok(<String, dynamic>{
        'id': 'user-2',
        'email': 'new@example.com',
      }),
    ]);
    final RemoteAuthRepository repository = _repository(adapter, tokenStorage);

    final session = await repository.register(
      email: 'new@example.com',
      password: 'secret',
    );

    expect(session.isSignedIn, isFalse);
    expect(tokenStorage.accessToken, isNull);
    expect(tokenStorage.refreshToken, isNull);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests[0].path, Endpoints.authRegister);
  });
}

RemoteAuthRepository _repository(
  _QueueAdapter adapter,
  _FakeTokenStorage tokenStorage,
) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
    ..httpClientAdapter = adapter;
  return RemoteAuthRepository(
    apiClient: ApiClient(dio: dio, tokenStorage: tokenStorage),
    tokenStorage: tokenStorage,
  );
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
  const _QueuedResponse._({required this.statusCode, required this.data});

  factory _QueuedResponse.ok(Map<String, dynamic> data) {
    return _QueuedResponse._(statusCode: 200, data: data);
  }

  factory _QueuedResponse.error(int statusCode, Map<String, dynamic> data) {
    return _QueuedResponse._(statusCode: statusCode, data: data);
  }

  final int statusCode;
  final Map<String, dynamic> data;
}

class _RecordedRequest {
  _RecordedRequest(RequestOptions options)
      : path = options.path,
        authorization = options.headers['Authorization'] as String?;

  final String path;
  final String? authorization;
}

class _FakeTokenStorage extends TokenStorage {
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
