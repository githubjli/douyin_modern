import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  @override
  Future<AuthSession> getCurrentSession() async {
    return const AuthSession(
      isSignedIn: false,
      userId: null,
      displayName: 'Guest',
    );
  }
}
