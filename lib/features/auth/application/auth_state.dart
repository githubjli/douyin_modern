import '../domain/auth_session.dart';

enum AuthStatus {
  unknown,
  checking,
  signedOut,
  signedIn,
  refreshing,
  error,
}

class AuthState {
  const AuthState._({
    required this.status,
    this.session,
    this.message,
  });

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.checking({AuthSession? previous})
      : this._(
          status: AuthStatus.checking,
          session: previous,
        );

  const AuthState.signedOut() : this._(status: AuthStatus.signedOut);

  const AuthState.signedIn(AuthSession session)
      : this._(
          status: AuthStatus.signedIn,
          session: session,
        );

  const AuthState.refreshing({AuthSession? previous})
      : this._(
          status: AuthStatus.refreshing,
          session: previous,
        );

  const AuthState.error(String message, {AuthSession? previous})
      : this._(
          status: AuthStatus.error,
          session: previous,
          message: message,
        );

  final AuthStatus status;
  final AuthSession? session;
  final String? message;

  bool get isSignedIn => session?.isSignedIn == true;

  bool get isChecking => status == AuthStatus.unknown || status == AuthStatus.checking;

  bool get isSignedOut => status == AuthStatus.signedOut;
}
