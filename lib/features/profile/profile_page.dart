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
import '../membership/membership_orders_page.dart';
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
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _loadingProfile = false;
  bool _loggingIn = false;
  bool _registering = false;
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
    _firstNameController.dispose();
    _lastNameController.dispose();
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

  Future<void> _register() async {
    setState(() {
      _registering = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );
      final AuthState authState = ref.read(authControllerProvider);
      if (authState.isSignedIn) {
        _passwordController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _registering = false);
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
      _firstNameController.clear();
      _lastNameController.clear();
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
        _firstNameController.clear();
        _lastNameController.clear();
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

    if (showGuest) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double verticalPadding = AppSpacing.md * 2;
            final double minHeight = constraints.maxHeight > verticalPadding
                ? constraints.maxHeight - verticalPadding
                : 0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Align(
                  alignment: const Alignment(0, -0.12),
                  child: _GuestProfileCard(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    loggingIn: _loggingIn,
                    registering: _registering,
                    error: _error ?? authState.message,
                    onLogin: _login,
                    onRegister: _register,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

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
            ),
          if (_error != null && (isChecking || isSignedIn)) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _WarmCard(title: 'Notice', subtitle: _error!),
          ],
        ],
      ),
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

enum _AuthMode { login, register }

class _GuestProfileCard extends StatefulWidget {
  const _GuestProfileCard({
    required this.emailController,
    required this.passwordController,
    required this.firstNameController,
    required this.lastNameController,
    required this.loggingIn,
    required this.registering,
    required this.error,
    required this.onLogin,
    required this.onRegister,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool loggingIn;
  final bool registering;
  final String? error;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRegister;

  @override
  State<_GuestProfileCard> createState() => _GuestProfileCardState();
}

class _GuestProfileCardState extends State<_GuestProfileCard> {
  bool _obscurePassword = true;
  _AuthMode _mode = _AuthMode.login;

  bool get _busy => widget.loggingIn || widget.registering;

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.login ? _AuthMode.register : _AuthMode.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isRegister = _mode == _AuthMode.register;

    return ConstrainedBox(
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
            isRegister ? 'Create your account' : 'Sign in to continue',
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
                if (isRegister) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: widget.firstNameController,
                          cursorColor: AppColors.brandGold,
                          textCapitalization: TextCapitalization.words,
                          style: AppTextStyles.body,
                          decoration: _inputDecoration('First name'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: widget.lastNameController,
                          cursorColor: AppColors.brandGold,
                          textCapitalization: TextCapitalization.words,
                          style: AppTextStyles.body,
                          decoration: _inputDecoration('Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextField(
                  controller: widget.emailController,
                  cursorColor: AppColors.brandGold,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.body,
                  decoration: _inputDecoration('Email'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: widget.passwordController,
                  cursorColor: AppColors.brandGold,
                  obscureText: _obscurePassword,
                  style: AppTextStyles.body,
                  decoration: _inputDecoration(
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
                  onPressed: _busy
                      ? null
                      : (isRegister ? widget.onRegister : widget.onLogin),
                  child: Text(
                    isRegister
                        ? (widget.registering ? 'Creating account...' : 'Sign Up')
                        : (widget.loggingIn ? 'Signing in...' : 'Sign In'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : _toggleMode,
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.caption,
                children: <TextSpan>[
                  TextSpan(
                    text: isRegister
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                  ),
                  TextSpan(
                    text: isRegister ? 'Sign In' : 'Sign Up',
                    style: const TextStyle(
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
    );
  }
}

InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
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
          _MembershipOrdersEntry(),
          const SizedBox(height: AppSpacing.sm),
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

class _MembershipOrdersEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const MembershipOrdersPage(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.warmBackground,
          border: Border.all(color: AppColors.softBorder),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.workspace_premium_outlined,
              color: AppColors.brandGold,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Membership & Orders',
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.cocoaText,
              size: 18,
            ),
          ],
        ),
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
