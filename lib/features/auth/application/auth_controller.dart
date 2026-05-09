import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/api_error_classifier.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    return const AuthState.unknown();
  }

  Future<void> bootstrap() async {
    final AuthSession? previous = _signedInSession;
    state = AuthState.checking(previous: previous);
    try {
      final AuthSession session = await _repository.getCurrentSession();
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      _handleFailure(error, previous: previous);
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final AuthSession? previous = _signedInSession;
    state = AuthState.checking(previous: previous);
    try {
      final AuthSession session = await _repository.login(
        email: email,
        password: password,
      );
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      _handleFailure(error, previous: previous);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final AuthSession? previous = _signedInSession;
    state = AuthState.checking(previous: previous);
    try {
      final AuthSession session = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      _handleFailure(error, previous: previous);
    }
  }

  Future<void> refreshSession() async {
    final AuthSession? previous = _signedInSession;
    state = AuthState.refreshing(previous: previous);
    try {
      final AuthSession session = await _repository.refreshSession();
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      _handleFailure(error, previous: previous);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState.signedOut();
  }

  AuthSession? get _signedInSession {
    final AuthSession? session = state.session;
    return session?.isSignedIn == true ? session : null;
  }

  void _handleFailure(Object error, {AuthSession? previous}) {
    if (isAuthDeniedError(error)) {
      state = const AuthState.signedOut();
      return;
    }
    if (isTransientError(error)) {
      state = AuthState.error(_messageFor(error), previous: previous);
      return;
    }
    state = AuthState.error(_messageFor(error), previous: previous);
  }

  String _messageFor(Object error) {
    if (error is ApiError) return error.message;
    return error.toString();
  }
}
