import 'auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> getCurrentSession();
}
