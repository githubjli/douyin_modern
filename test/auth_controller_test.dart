import 'dart:async';

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
      overrides: [
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
    expect(state.session, isNull);
  });

  test('logout clears auth state even if repository logout fails', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      loginSession: signedInSession,
      logoutError: Exception('remote logout failed'),
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );

    await expectLater(
      container.read(authControllerProvider.notifier).logout(),
      throwsA(isA<Exception>()),
    );

    final AuthState state = container.read(authControllerProvider);
    expect(repository.logoutCalled, isTrue);
    expect(state.status, AuthStatus.signedOut);
    expect(state.session, isNull);
  });

  test('logout is not overwritten by older bootstrap completion', () async {
    final Completer<AuthSession> currentSessionCompleter =
        Completer<AuthSession>();
    final _FakeAuthRepository repository = _FakeAuthRepository(
      currentSessionFuture: currentSessionCompleter.future,
    );
    final ProviderContainer container = createContainer(repository);

    final Future<void> bootstrapFuture =
        container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).status, AuthStatus.checking);

    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);

    currentSessionCompleter.complete(signedInSession);
    await bootstrapFuture;

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.signedOut);
    expect(state.session, isNull);
  });

  test('stale bootstrap cannot override later successful login', () async {
    final Completer<AuthSession> currentSessionCompleter =
        Completer<AuthSession>();
    final _FakeAuthRepository repository = _FakeAuthRepository(
      currentSessionFuture: currentSessionCompleter.future,
      loginSession: signedInSession,
    );
    final ProviderContainer container = createContainer(repository);

    final Future<void> bootstrapFuture =
        container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).status, AuthStatus.checking);

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );
    expect(container.read(authControllerProvider).status, AuthStatus.signedIn);
    expect(container.read(authControllerProvider).session, signedInSession);

    currentSessionCompleter.complete(signedOutSession);
    await bootstrapFuture;

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.signedIn);
    expect(state.session, signedInSession);
  });

  test('stale refresh success cannot override later logout', () async {
    final Completer<AuthSession> refreshCompleter = Completer<AuthSession>();
    final _FakeAuthRepository repository = _FakeAuthRepository(
      loginSession: signedInSession,
      refreshSessionFuture: refreshCompleter.future,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );
    final Future<void> refreshFuture =
        container.read(authControllerProvider.notifier).refreshSession();
    expect(container.read(authControllerProvider).status, AuthStatus.refreshing);

    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);

    refreshCompleter.complete(refreshedSession);
    await refreshFuture;

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.signedOut);
    expect(state.session, isNull);
  });

  test('stale refresh error cannot override later logout', () async {
    final Completer<AuthSession> refreshCompleter = Completer<AuthSession>();
    final _FakeAuthRepository repository = _FakeAuthRepository(
      loginSession: signedInSession,
      refreshSessionFuture: refreshCompleter.future,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(authControllerProvider.notifier).login(
          email: 'meow@example.com',
          password: 'secret',
        );
    final Future<void> refreshFuture =
        container.read(authControllerProvider.notifier).refreshSession();
    expect(container.read(authControllerProvider).status, AuthStatus.refreshing);

    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);

    refreshCompleter.completeError(
      const ApiError(message: 'Server unavailable', statusCode: 500),
    );
    await refreshFuture;

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.signedOut);
    expect(state.session, isNull);
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
    this.currentSessionFuture,
    this.currentSessionError,
    this.loginSession,
    this.refreshSessionResult,
    this.refreshSessionFuture,
    this.refreshSessionError,
    this.logoutError,
  });

  final AuthSession? currentSession;
  final Future<AuthSession>? currentSessionFuture;
  final Object? currentSessionError;
  final AuthSession? loginSession;
  final AuthSession? refreshSessionResult;
  final Future<AuthSession>? refreshSessionFuture;
  final Object? refreshSessionError;
  final Object? logoutError;

  String? loginEmail;
  String? loginPassword;
  bool logoutCalled = false;

  @override
  Future<AuthSession> getCurrentSession() async {
    final Future<AuthSession>? future = currentSessionFuture;
    if (future != null) return future;
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
    final Object? error = logoutError;
    if (error != null) throw error;
  }

  @override
  Future<AuthSession> refreshSession() async {
    final Future<AuthSession>? future = refreshSessionFuture;
    if (future != null) return future;
    final Object? error = refreshSessionError;
    if (error != null) throw error;
    final AuthSession? result = refreshSessionResult;
    if (result != null) return result;
    return getCurrentSession();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    return AuthSession(
      isSignedIn: true,
      userId: email,
      displayName: 'Registered User',
    );
  }
}
