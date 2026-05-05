import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../shared/brand_page_header.dart';
import '../auth/data/remote_auth_repository.dart';
import '../auth/domain/auth_repository.dart';
import '../auth/domain/auth_session.dart';
import 'data/remote_profile_repository.dart';
import 'domain/profile_repository.dart';
import 'domain/user_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    AuthRepository? authRepository,
    ProfileRepository? profileRepository,
  })  : _authRepository = authRepository,
        _profileRepository = profileRepository;

  final AuthRepository? _authRepository;
  final ProfileRepository? _profileRepository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final AuthRepository _authRepository;
  late final ProfileRepository _profileRepository;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = true;
  bool _loggingIn = false;
  String? _error;
  AuthSession? _session;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    final ApiClient apiClient = ApiClient();
    _authRepository = widget._authRepository ??
        RemoteAuthRepository(apiClient: apiClient);
    _profileRepository = widget._profileRepository ??
        RemoteProfileRepository(apiClient: apiClient);
    _loadSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AuthSession session = await _authRepository.getCurrentSession();
      if (session.isSignedIn) {
        final UserProfile profile = await _profileRepository.getCurrentProfile();
        if (!mounted) return;
        setState(() {
          _session = session;
          _profile = profile;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _session = session;
          _profile = null;
        });
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _session = const AuthSession(isSignedIn: false, userId: null, displayName: 'Guest');
        _profile = null;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = const AuthSession(isSignedIn: false, userId: null, displayName: 'Guest');
        _profile = null;
        _error = 'Unable to load profile right now.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _loadSession();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Login failed. Please try again.');
    } finally {
      if (!mounted) return;
      setState(() => _loggingIn = false);
    }
  }

  Future<void> _logout() async {
    await _authRepository.logout();
    if (!mounted) return;
    setState(() {
      _session = const AuthSession(isSignedIn: false, userId: null, displayName: 'Guest');
      _profile = null;
      _error = null;
      _emailController.clear();
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const BrandPageHeader(title: 'Profile'),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const _WarmCard(title: 'Loading', subtitle: 'Checking your session...')
          else if (_session?.isSignedIn == true)
            _SignedInProfileCard(
              profile: _profile,
              onLogout: _logout,
              onRefresh: _loadSession,
            )
          else
            _GuestProfileCard(
              emailController: _emailController,
              passwordController: _passwordController,
              loggingIn: _loggingIn,
              onLogin: _login,
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _WarmCard(title: 'Notice', subtitle: _error!),
          ],
        ],
      ),
    );
  }
}

class _GuestProfileCard extends StatelessWidget {
  const _GuestProfileCard({
    required this.emailController,
    required this.passwordController,
    required this.loggingIn,
    required this.onLogin,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loggingIn;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Guest mode', style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          const Text('Log in to load your backend profile.', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  onPressed: loggingIn ? null : onLogin,
                  child: Text(loggingIn ? 'Logging in...' : 'Login'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(onPressed: null, child: const Text('Register')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignedInProfileCard extends StatelessWidget {
  const _SignedInProfileCard({
    required this.profile,
    required this.onLogout,
    required this.onRefresh,
  });

  final UserProfile? profile;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(profile?.displayName ?? 'User', style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(profile?.email ?? 'No email from backend', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Text('Creator: ${profile?.isCreator == true ? 'Yes' : 'No'}', style: AppTextStyles.caption),
          Text('Seller: ${profile?.isSeller == true ? 'Yes' : 'No'}', style: AppTextStyles.caption),
          Text('Wallet linked: ${profile?.walletLinked == true ? 'Yes' : 'No'}', style: AppTextStyles.caption),
          Text('Wallet: ${profile?.walletAddress ?? '-'}', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onRefresh,
                  child: const Text('Refresh profile'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLogout,
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarmCard extends StatelessWidget {
  const _WarmCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
