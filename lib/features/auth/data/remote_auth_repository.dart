import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required ApiClient apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      Endpoints.authLogin,
      data: <String, dynamic>{
        'email': email,
        'password': password,
      },
    );

    final AuthSession session = _sessionFromMap(response.data ?? <String, dynamic>{});
    await _persistTokens(response.data ?? <String, dynamic>{});
    return session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      Endpoints.authRegister,
      data: <String, dynamic>{
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );

    final AuthSession session = _sessionFromMap(response.data ?? <String, dynamic>{});
    await _persistTokens(response.data ?? <String, dynamic>{});
    return session;
  }

  @override
  Future<AuthSession> refreshSession() async {
    final String? refreshToken = await _tokenStorage.readRefreshToken();

    final response = await _apiClient.post<Map<String, dynamic>>(
      Endpoints.authRefresh,
      data: <String, dynamic>{'refresh': refreshToken},
    );

    await _persistTokens(response.data ?? <String, dynamic>{});
    return getCurrentSession();
  }

  @override
  Future<AuthSession> getCurrentSession() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      Endpoints.authMe,
      authenticated: true,
    );

    return _sessionFromMap(response.data ?? <String, dynamic>{});
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.clearAllTokens();
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final String? accessToken = _readString(data, const <String>['access', 'access_token']);
    final String? refreshToken = _readString(data, const <String>['refresh', 'refresh_token']);

    if (accessToken != null && accessToken.isNotEmpty) {
      await _tokenStorage.writeAccessToken(accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _tokenStorage.writeRefreshToken(refreshToken);
    }
  }

  AuthSession _sessionFromMap(Map<String, dynamic> data) {
    final dynamic user = data['user'];
    final Map<String, dynamic> userMap = user is Map<String, dynamic>
        ? user
        : <String, dynamic>{};

    final String? userId = _readString(
      userMap,
      const <String>['id', 'user_id', 'uid'],
    ) ?? _readString(data, const <String>['id', 'user_id', 'uid']);

    final String displayName =
        _readString(userMap, const <String>['display_name', 'username', 'name']) ??
            _readString(data, const <String>['display_name', 'username', 'name']) ??
            'User';

    return AuthSession(
      isSignedIn: userId != null,
      userId: userId,
      displayName: displayName,
    );
  }

  String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is num) return value.toString();
    }
    return null;
  }
}
