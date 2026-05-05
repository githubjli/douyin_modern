import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return AuthSession(
      isSignedIn: true,
      userId: email,
      displayName: 'Meow User',
    );
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return AuthSession(
      isSignedIn: true,
      userId: email,
      displayName: displayName,
    );
  }

  @override
  Future<AuthSession> refreshSession() async {
    return const AuthSession(
      isSignedIn: false,
      userId: null,
      displayName: 'Guest',
    );
  }

  @override
  Future<AuthSession> getCurrentSession() async {
    return const AuthSession(
      isSignedIn: false,
      userId: null,
      displayName: 'Guest',
    );
  }

  @override
  Future<void> logout() async {}
}
