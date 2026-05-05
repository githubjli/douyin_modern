import 'session_models.dart';

abstract class SessionRepository {
  Future<AuthSession> getCurrentSession();
}

class MockSessionRepository implements SessionRepository {
  const MockSessionRepository();

  @override
  Future<AuthSession> getCurrentSession() async {
    return const AuthSession(
      isSignedIn: false,
      userId: null,
      displayName: 'Guest',
    );
  }
}
