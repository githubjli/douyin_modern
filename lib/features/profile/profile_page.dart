import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_assets.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../shared/brand_page_header.dart';
import '../auth/application/auth_providers.dart';
import '../auth/application/auth_state.dart';
import 'data/remote_profile_repository.dart';
import 'domain/profile_repository.dart';
import 'domain/user_profile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({
    super.key,
    ProfileRepository? profileRepository,
  }) : _profileRepository = profileRepository;

  final ProfileRepository? _profileRepository;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final ProfileRepository _profileRepository;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loadingProfile = false;
  bool _loggingIn = false;
  String? _error;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    final ApiClient apiClient = ApiClient();
    _profileRepository = widget._profileRepository ??
        RemoteProfileRepository(apiClient: apiClient);
    Future<void>.microtask(() {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _error = null;
    });

    try {
      final UserProfile profile = await _profileRepository.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyAuthError(e.message);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load profile right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _refreshProfile() async {
    await ref.read(authControllerProvider.notifier).bootstrap();
    if (ref.read(authControllerProvider).status == AuthStatus.signedIn) {
      await _loadProfile();
    }
  }

  Future<void> _login() async {
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      final AuthState authState = ref.read(authControllerProvider);
      if (authState.isSignedIn) {
        _passwordController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _loggingIn = false);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _error = null;
      _emailController.clear();
      _passwordController.clear();
    });
  }

  void _handleAuthState(AuthState authState) {
    if (!mounted) return;
    if (authState.status == AuthStatus.signedOut) {
      setState(() {
        _profile = null;
        _error = null;
        _emailController.clear();
        _passwordController.clear();
        _loadingProfile = false;
      });
      return;
    }

    if (authState.status == AuthStatus.error) {
      setState(() {
        _error = authState.message;
      });
    }

    if (authState.isSignedIn && !_loadingProfile && _profile == null) {
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (_, AuthState next) {
      _handleAuthState(next);
    });
    final AuthState authState = ref.watch(authControllerProvider);
    final bool isSignedIn = _hasSignedInSession(authState);
    final bool showGuest = _shouldShowGuestProfile(authState);
    final bool isChecking = !isSignedIn && !showGuest;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          if (isChecking || isSignedIn) ...<Widget>[
            const BrandPageHeader(title: 'Profile'),
            const SizedBox(height: AppSpacing.md),
          ],
          if (isChecking)
            const _WarmCard(
              title: 'Loading',
              subtitle: 'Checking your session...',
            )
          else if (isSignedIn)
            _SignedInProfileCard(
              profile: _profile,
              onLogout: _logout,
              onRefresh: _refreshProfile,
            )
          else if (showGuest)
            _GuestProfileCard(
              emailController: _emailController,
              passwordController: _passwordController,
              loggingIn: _loggingIn,
              error: _error ?? authState.message,
              onLogin: _login,
              onSignUp: _showSignUpPlaceholder,
            ),
          if (_error != null && (isChecking || isSignedIn)) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _WarmCard(title: 'Notice', subtitle: _error!),
          ],
        ],
      ),
    );
  }

  void _showSignUpPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign Up coming soon.')),
    );
  }
}

bool _hasSignedInSession(AuthState authState) {
  return authState.session?.isSignedIn == true;
}

bool _shouldShowGuestProfile(AuthState authState) {
  if (authState.status == AuthStatus.signedOut) return true;
  return authState.status == AuthStatus.error && !_hasSignedInSession(authState);
}

String _friendlyAuthError(String message) {
  if (message.contains('Given token not valid for any token type')) {
    return 'Session expired. Please sign in again.';
  }
  return message;
}

class _GuestProfileCard extends StatefulWidget {
  const _GuestProfileCard({
    required this.emailController,
    required this.passwordController,
    required this.loggingIn,
    required this.error,
    required this.onLogin,
    required this.onSignUp,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loggingIn;
  final String? error;
  final Future<void> Function() onLogin;
  final VoidCallback onSignUp;

  @override
  State<_GuestProfileCard> createState() => _GuestProfileCardState();
}

class _GuestProfileCardState extends State<_GuestProfileCard> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final double minHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        (AppSpacing.md * 2);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border.all(color: AppColors.softBorder),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Image.asset(AppAssets.meowLogo, fit: BoxFit.contain),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Meow Media', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Sign in to continue',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.mutedOliveText,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border.all(color: AppColors.softBorder),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: widget.emailController,
                      cursorColor: AppColors.brandGold,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTextStyles.body,
                      decoration: _loginInputDecoration('Email'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: widget.passwordController,
                      cursorColor: AppColors.brandGold,
                      obscureText: _obscurePassword,
                      style: AppTextStyles.body,
                      decoration: _loginInputDecoration(
                        'Password',
                        suffixIcon: IconButton(
                          key: const ValueKey<String>(
                            'profile-password-visibility-toggle',
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          color: AppColors.mutedOliveText,
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    if (widget.error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _InlineAuthMessage(message: widget.error!),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: widget.loggingIn ? null : widget.onLogin,
                      child: Text(
                        widget.loggingIn ? 'Signing in...' : 'Sign In',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: widget.onSignUp,
                child: RichText(
                  text: const TextSpan(
                    style: AppTextStyles.caption,
                    children: <TextSpan>[
                      TextSpan(text: 'Don’t have an account? '),
                      TextSpan(
                        text: 'Sign Up',
                        style: TextStyle(
                          color: AppColors.brandGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _loginInputDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.warmBackground,
    labelStyle: AppTextStyles.caption,
    floatingLabelStyle: AppTextStyles.caption.copyWith(
      color: AppColors.brandGold,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: const BorderSide(color: AppColors.softBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: const BorderSide(color: AppColors.brandGold),
    ),
    suffixIcon: suffixIcon,
  );
}

class _InlineAuthMessage extends StatelessWidget {
  const _InlineAuthMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warmBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
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
