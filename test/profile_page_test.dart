import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/auth/application/auth_providers.dart';
import 'package:meow_media/features/auth/domain/auth_repository.dart';
import 'package:meow_media/features/auth/domain/auth_session.dart';
import 'package:meow_media/features/profile/domain/profile_repository.dart';
import 'package:meow_media/features/profile/domain/user_profile.dart';
import 'package:meow_media/features/profile/profile_page.dart';

void main() {
  const AuthSession signedInSession = AuthSession(
    isSignedIn: true,
    userId: 'user-1',
    displayName: 'Meow User',
  );
  const AuthSession signedOutSession = AuthSession(
    isSignedIn: false,
    userId: null,
    displayName: 'Guest',
  );
  const UserProfile profile = UserProfile(
    userId: 'user-1',
    displayName: 'Profile User',
    bio: 'Bio',
    avatarUrl: '',
    email: 'profile@example.com',
    isCreator: true,
    isSeller: false,
    walletLinked: true,
    walletAddress: '0x123',
  );

  Future<void> pumpProfilePage(
    WidgetTester tester, {
    required AuthRepository authRepository,
    ProfileRepository? profileRepository,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProfilePage(
              profileRepository:
                  profileRepository ?? const _FakeProfileRepository(profile),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('auth checking shows loading instead of guest login card',
      (WidgetTester tester) async {
    await pumpProfilePage(
      tester,
      authRepository: _NeverCompletingAuthRepository(),
      settle: false,
    );

    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Checking your session...'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
    expect(find.text('Sign In'), findsNothing);
  });

  testWidgets('auth signedOut shows guest login card',
      (WidgetTester tester) async {
    await pumpProfilePage(
      tester,
      authRepository: _FakeAuthRepository(currentSession: signedOutSession),
    );

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Profile User'), findsNothing);
  });

  testWidgets('password visibility toggle shows and hides password',
      (WidgetTester tester) async {
    await pumpProfilePage(
      tester,
      authRepository: _FakeAuthRepository(currentSession: signedOutSession),
    );

    final Finder passwordField = find.byType(TextField).at(1);
    TextField passwordTextField = tester.widget<TextField>(passwordField);
    expect(passwordTextField.obscureText, isTrue);

    final Finder visibilityToggle = find.byKey(
      const ValueKey<String>('profile-password-visibility-toggle'),
    );
    expect(visibilityToggle, findsOneWidget);

    await tester.tap(visibilityToggle);
    await tester.pump();

    passwordTextField = tester.widget<TextField>(passwordField);
    expect(passwordTextField.obscureText, isFalse);

    await tester.tap(visibilityToggle);
    await tester.pump();

    passwordTextField = tester.widget<TextField>(passwordField);
    expect(passwordTextField.obscureText, isTrue);
  });

  testWidgets('auth signedIn shows signed-in profile card',
      (WidgetTester tester) async {
    await pumpProfilePage(
      tester,
      authRepository: _FakeAuthRepository(currentSession: signedInSession),
    );

    expect(find.text('Profile User'), findsOneWidget);
    expect(find.text('profile@example.com'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
  });

  testWidgets('login success updates global auth and shows signed-in profile',
      (WidgetTester tester) async {
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      currentSession: signedOutSession,
      loginSession: signedInSession,
    );
    await pumpProfilePage(tester, authRepository: authRepository);

    await tester.enterText(find.byType(TextField).at(0), 'meow@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(authRepository.loginCalled, isTrue);
    expect(authRepository.loginEmail, 'meow@example.com');
    expect(find.text('Profile User'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('token-only login flow shows signed-in profile instead of login',
      (WidgetTester tester) async {
    final _TokenOnlyLoginAuthRepository authRepository =
        _TokenOnlyLoginAuthRepository(
      signedOutSession: signedOutSession,
      signedInSession: signedInSession,
    );
    await pumpProfilePage(tester, authRepository: authRepository);

    await tester.enterText(find.byType(TextField).at(0), 'meow@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(authRepository.loginCalled, isTrue);
    expect(authRepository.currentSessionCalls, 2);
    expect(find.text('Profile User'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
  });

  testWidgets('logout calls auth controller and shows guest login card',
      (WidgetTester tester) async {
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      currentSession: signedInSession,
    );
    await pumpProfilePage(tester, authRepository: authRepository);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(authRepository.logoutCalled, isTrue);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Profile User'), findsNothing);
  });

  testWidgets('transient auth error preserves previous signed-in profile card',
      (WidgetTester tester) async {
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      currentSession: signedInSession,
    );
    await pumpProfilePage(tester, authRepository: authRepository);

    expect(find.text('Profile User'), findsOneWidget);

    authRepository.currentSessionError = Exception('offline');
    await tester.tap(find.text('Refresh profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile User'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
    expect(find.textContaining('offline'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required this.currentSession,
    this.loginSession,
  });

  AuthSession currentSession;
  AuthSession? loginSession;
  Object? currentSessionError;
  bool loginCalled = false;
  String? loginEmail;
  String? loginPassword;
  bool logoutCalled = false;

  @override
  Future<AuthSession> getCurrentSession() async {
    final Object? error = currentSessionError;
    if (error != null) throw error;
    return currentSession;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalled = true;
    loginEmail = email;
    loginPassword = password;
    final AuthSession session = loginSession ??
        AuthSession(
          isSignedIn: true,
          userId: email,
          displayName: 'Meow User',
        );
    currentSession = session;
    return session;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    currentSession = const AuthSession(
      isSignedIn: false,
      userId: null,
      displayName: 'Guest',
    );
  }

  @override
  Future<AuthSession> refreshSession() async => getCurrentSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
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

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository(this.profile);

  final UserProfile profile;

  @override
  Future<UserProfile> getCurrentProfile() async => profile;

  @override
  Future<UserProfile> updateProfile({
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) async {
    return UserProfile(
      userId: profile.userId,
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl ?? profile.avatarUrl,
      email: profile.email,
      isCreator: profile.isCreator,
      isSeller: profile.isSeller,
      walletAddress: profile.walletAddress,
      walletLinked: profile.walletLinked,
    );
  }
}

class _NeverCompletingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> getCurrentSession() => Completer<AuthSession>().future;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> refreshSession() => getCurrentSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) {
    throw UnimplementedError();
  }
}

class _TokenOnlyLoginAuthRepository implements AuthRepository {
  _TokenOnlyLoginAuthRepository({
    required this.signedOutSession,
    required this.signedInSession,
  }) : _currentSession = signedOutSession;

  final AuthSession signedOutSession;
  final AuthSession signedInSession;
  AuthSession _currentSession;
  bool loginCalled = false;
  int currentSessionCalls = 0;

  @override
  Future<AuthSession> getCurrentSession() async {
    currentSessionCalls += 1;
    return _currentSession;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalled = true;
    _currentSession = signedInSession;
    return getCurrentSession();
  }

  @override
  Future<void> logout() async {
    _currentSession = signedOutSession;
  }

  @override
  Future<AuthSession> refreshSession() => getCurrentSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    _currentSession = signedInSession;
    return getCurrentSession();
  }
}
