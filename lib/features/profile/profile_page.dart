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

  void _openEditProfile() {
    final UserProfile? current = _profile;
    if (current == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditProfilePage(
          profile: current,
          profileRepository: _profileRepository,
          onSaved: (UserProfile updated) {
            if (mounted) setState(() => _profile = updated);
          },
        ),
      ),
    );
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
          else if (isSignedIn) ...<Widget>[
            if (_error != null) ...<Widget>[
              _WarmCard(title: 'Notice', subtitle: _error!),
              const SizedBox(height: AppSpacing.sm),
            ],
            _SignedInProfileBody(
              profile: _profile,
              onLogout: _logout,
              onRefresh: _refreshProfile,
              onEdit: _openEditProfile,
            ),
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

// ---------------------------------------------------------------------------
// Signed-in profile body — full sectioned layout
// ---------------------------------------------------------------------------

class _SignedInProfileBody extends StatelessWidget {
  const _SignedInProfileBody({
    required this.profile,
    required this.onLogout,
    required this.onRefresh,
    required this.onEdit,
  });

  final UserProfile? profile;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bool isCreator = profile?.isCreator == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── Avatar + name ──────────────────────────────────────────────
        _ProfileHeader(profile: profile, onRefresh: onRefresh, onEdit: onEdit),
        const SizedBox(height: AppSpacing.md),

        // ── Meow Points card ───────────────────────────────────────────
        const _PointsCard(points: null), // TODO: wire up backend
        const SizedBox(height: AppSpacing.md),

        // ── Creator tools (only when isCreator) ────────────────────────
        if (isCreator) ...<Widget>[
          _SectionCard(
            label: 'Creator Studio',
            items: <_MenuItem>[
              _MenuItem(
                icon: Icons.play_circle_outline_rounded,
                label: 'My Videos',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.upload_outlined,
                label: 'Upload Video',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.live_tv_outlined,
                label: 'Live Creator',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.menu_book_outlined,
                label: 'Drama Creator',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── My content ─────────────────────────────────────────────────
        _SectionCard(
          label: 'My Content',
          items: <_MenuItem>[
            _MenuItem(
              icon: Icons.video_library_outlined,
              label: 'My Library',
              onTap: () => _showComingSoon(context),
            ),
            _MenuItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Membership & Orders',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const MembershipOrdersPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Account ────────────────────────────────────────────────────
        _SectionCard(
          label: 'Account',
          items: <_MenuItem>[
            _MenuItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet & Billing',
              onTap: () => _showComingSoon(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Security ───────────────────────────────────────────────────
        _SectionCard(
          label: 'Security',
          items: <_MenuItem>[
            _MenuItem(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              onTap: () => _showComingSoon(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Sign out ───────────────────────────────────────────────────
        _SectionCard(
          label: '',
          items: <_MenuItem>[
            _MenuItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              destructive: true,
              onTap: onLogout,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon.')),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar + display name header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onRefresh,
    required this.onEdit,
  });

  final UserProfile? profile;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String name = profile?.displayName ?? 'User';
    final String? email = profile?.email;
    final String? bio =
        profile?.bio.trim().isNotEmpty == true ? profile!.bio.trim() : null;
    final bool isCreator = profile?.isCreator == true;
    final bool isSeller = profile?.isSeller == true;
    final String initials = _initials(name);
    final String? avatarUrl = profile?.avatarUrl.trim().isNotEmpty == true
        ? profile!.avatarUrl.trim()
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.brandGold.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brandGold, width: 1.5),
            ),
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _InitialsAvatar(initials: initials),
                    ),
                  )
                : _InitialsAvatar(initials: initials),
          ),
          const SizedBox(width: AppSpacing.md),
          // Name, email, badges, bio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: AppTextStyles.cardTitle),
                if (email != null && email != name) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mutedOliveText,
                    ),
                  ),
                ],
                if (isCreator || isSeller) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: <Widget>[
                      if (isCreator) const _RoleBadge(label: 'Creator'),
                      if (isSeller) const _RoleBadge(label: 'Seller'),
                    ],
                  ),
                ],
                if (bio != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    bio,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mutedOliveText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Action buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('profile-refresh-button'),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.mutedOliveText,
                tooltip: 'Refresh profile',
                onPressed: onRefresh,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.mutedOliveText,
                tooltip: 'Edit profile',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.brandGold,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withAlpha(22),
        border: Border.all(color: AppColors.brandGold.withAlpha(80)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.brandGold,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meow Points card
// ---------------------------------------------------------------------------

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points});

  final int? points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandGold.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: AppColors.brandGold,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Meow Points', style: AppTextStyles.body),
                Text(
                  points != null ? '$points pts' : '— pts',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.mutedOliveText,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon.')),
            ),
            child: const Text('Details'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic section card with list items
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.items});

  final String label;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border.all(color: AppColors.softBorder),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                _MenuRow(item: items[i]),
                if (i < items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.softBorder,
                    indent: AppSpacing.md + 28,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final Color color =
        item.destructive ? Colors.redAccent.shade100 : AppColors.cocoaText;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(item.icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                item.label,
                style: AppTextStyles.body.copyWith(color: color),
              ),
            ),
            if (!item.destructive)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.mutedOliveText,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile — full-page, ManualPayment card style
// ---------------------------------------------------------------------------

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.profile,
    required this.profileRepository,
    required this.onSaved,
  });

  final UserProfile profile;
  final ProfileRepository profileRepository;
  final ValueChanged<UserProfile> onSaved;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final UserProfile updated = await widget.profileRepository.updateProfile(
        displayName: name,
        bio: _bioController.text.trim(),
      );
      if (!mounted) return;
      widget.onSaved(updated);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Row(
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground.withValues(alpha: 0.54),
                          border: Border.all(color: AppColors.softBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.brandGold,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Edit Profile',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 18,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Display Name card
              _EditCard(
                label: 'Display Name',
                child: TextField(
                  controller: _nameController,
                  cursorColor: AppColors.brandGold,
                  textCapitalization: TextCapitalization.words,
                  style: AppTextStyles.body,
                  decoration: _editFieldDecoration('Your name'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Bio card
              _EditCard(
                label: 'Bio',
                child: TextField(
                  controller: _bioController,
                  cursorColor: AppColors.brandGold,
                  maxLines: 5,
                  minLines: 3,
                  style: AppTextStyles.body,
                  decoration: _editFieldDecoration(
                    'Tell others a bit about yourself…',
                  ),
                ),
              ),

              // Error message
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(20),
                    border: Border.all(color: Colors.redAccent.withAlpha(80)),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: AppColors.warmBackground,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: Text(
                  _saving ? 'Saving...' : 'Save',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

class _EditCard extends StatelessWidget {
  const _EditCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.brandGold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

InputDecoration _editFieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.caption,
    isDense: true,
    filled: true,
    fillColor: AppColors.warmBackground,
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
  );
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
