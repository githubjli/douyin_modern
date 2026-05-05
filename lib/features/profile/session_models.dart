class AuthSession {
  const AuthSession({
    required this.isSignedIn,
    required this.userId,
    required this.displayName,
  });

  final bool isSignedIn;
  final String? userId;
  final String displayName;
}
