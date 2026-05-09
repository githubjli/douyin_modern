import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/features/auth/application/auth_providers.dart';
import 'package:meow_media/features/auth/application/auth_state.dart';
import 'package:meow_media/features/auth/domain/auth_repository.dart';
import 'package:meow_media/features/auth/domain/auth_session.dart';

void main() {
  const AuthSession signedInSession = AuthSession(
    isSignedIn: true,
    userId: 'user-1',
    displayName: 'Meow User',
  );
  const AuthSession refreshedSession = AuthSession(
    isSignedIn: true,
    userId: 'user-1',
    displayName: 'Fresh Meow User',
  );
  const AuthSession signedOutSession = AuthSession(
    isSignedIn: false,
    userId: null,
    displayName: 'Guest',
  );

  ProviderContainer createContainer(_FakeAuthRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('bootstrap success sets signed-in state', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      currentSession: signedInSession,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).bootstrap();

    final AuthState state = container.read(authControllerProvider);
    expect(state.isSignedIn, isTrue);
    expect(state.status, AuthStatus.signedIn);
    expect(state.session, signedInSession);
  });

  test('bootstrap success sets signed-out state', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      currentSession: signedOutSession,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).bootstrap();

    final AuthState state = container.read(authControllerProvider);
    expect(state.isSignedOut, isTrue);
    expect(state.session, isNull);
  });

  test('bootstrap transient error without previous session sets error', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      currentSessionError: Exception('offline'),
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).bootstrap();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.isSignedIn, isFalse);
    expect(state.session, isNull);
    expect(state.message, contains('offline'));
  });

  test('login success sets signed-in state', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      loginSession: signedInSession,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.signedIn);
    expect(state.session, signedInSession);
    expect(repository.loginEmail, 'meow@example.com');
    expect(repository.loginPassword, 'secret');
  });

  test('logout calls repository and sets signed-out state', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      loginSession: signedInSession,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );
    await container.read(authControllerProvider.notifier).logout();

    final AuthState state = container.read(authControllerProvider);
    expect(repository.logoutCalled, isTrue);
    expect(state.isSignedOut, isTrue);
  });

  test('refreshSession emits refreshing then signed-in on success', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      loginSession: signedInSession,
      refreshSessionResult: refreshedSession,
    );
    final ProviderContainer container = createContainer(repository);
    final List<AuthState> states = <AuthState>[];
    container.listen<AuthState>(
      authControllerProvider,
      (_, AuthState next) => states.add(next),
    );

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );
    await container.read(authControllerProvider.notifier).refreshSession();

    expect(
      states.any(
        (AuthState state) =>
            state.status == AuthStatus.refreshing &&
            state.session == signedInSession,
      ),
      isTrue,
    );
    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.signedIn);
    expect(state.session, refreshedSession);
  });

  test('refreshSession transient error preserves previous signed-in session',
      () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      loginSession: signedInSession,
      refreshSessionError: const ApiError(
        message: 'Server unavailable',
        statusCode: 500,
      ),
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );
    await container.read(authControllerProvider.notifier).refreshSession();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.session, signedInSession);
    expect(state.isSignedIn, isTrue);
    expect(state.isSignedOut, isFalse);
    expect(state.message, 'Server unavailable');
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.currentSession,
    this.currentSessionError,
    this.loginSession,
    this.loginError,
    this.refreshSessionResult,
    this.refreshSessionError,
  });

  final AuthSession? currentSession;
  final Object? currentSessionError;
  final AuthSession? loginSession;
  final Object? loginError;
  final AuthSession? refreshSessionResult;
  final Object? refreshSessionError;

  String? loginEmail;
  String? loginPassword;
  bool logoutCalled = false;

  @override
  Future<AuthSession> getCurrentSession() async {
    final Object? error = currentSessionError;
    if (error != null) throw error;
    return currentSession ??
        const AuthSession(
          isSignedIn: false,
          userId: null,
          displayName: 'Guest',
        );
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginEmail = email;
    loginPassword = password;
    final Object? error = loginError;
    if (error != null) throw error;
    return loginSession ??
        AuthSession(
          isSignedIn: true,
          userId: email,
          displayName: 'Meow User',
        );
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<AuthSession> refreshSession() async {
    final Object? error = refreshSessionError;
    if (error != null) throw error;
    return refreshSessionResult ?? getCurrentSession();
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
}
