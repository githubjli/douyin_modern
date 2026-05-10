import 'auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<AuthSession> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  });

  Future<AuthSession> refreshSession();

  Future<AuthSession> getCurrentSession();

  Future<void> logout();
}
