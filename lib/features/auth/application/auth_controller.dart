import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/api_error_classifier.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState.unknown());

  final AuthRepository _repository;
  int _operationGeneration = 0;

  Future<void> bootstrap() async {
    final int operation = _beginOperation();
    final AuthSession? previous = _signedInSession;
    state = AuthState.checking(previous: previous);
    try {
      final AuthSession session = await _repository.getCurrentSession();
      if (!_isCurrentOperation(operation)) return;
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      if (_isCurrentOperation(operation)) {
        _handleFailure(error, previous: previous);
      }
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final int operation = _beginOperation();
    final AuthSession? previous = _signedInSession;
    state = AuthState.checking(previous: previous);
    try {
      final AuthSession session = await _repository.login(
        email: email,
        password: password,
      );
      if (!_isCurrentOperation(operation)) return;
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      if (_isCurrentOperation(operation)) {
        _handleFailure(error, previous: previous);
      }
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final int operation = _beginOperation();
    final AuthSession? previous = _signedInSession;
    state = AuthState.checking(previous: previous);
    try {
      final AuthSession session = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (!_isCurrentOperation(operation)) return;
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      if (_isCurrentOperation(operation)) {
        _handleFailure(error, previous: previous);
      }
    }
  }

  Future<void> refreshSession() async {
    final int operation = _beginOperation();
    final AuthSession? previous = _signedInSession;
    state = AuthState.refreshing(previous: previous);
    try {
      final AuthSession session = await _repository.refreshSession();
      if (!_isCurrentOperation(operation)) return;
      state = session.isSignedIn
          ? AuthState.signedIn(session)
          : const AuthState.signedOut();
    } catch (error) {
      if (_isCurrentOperation(operation)) {
        _handleFailure(error, previous: previous);
      }
    }
  }

  Future<void> logout() async {
    final int operation = _beginOperation();
    try {
      await _repository.logout();
    } finally {
      if (_isCurrentOperation(operation)) {
        state = const AuthState.signedOut();
      }
    }
  }

  int _beginOperation() {
    _operationGeneration += 1;
    return _operationGeneration;
  }

  bool _isCurrentOperation(int operation) {
    return operation == _operationGeneration;
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
