import '../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_assets.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../auth/application/auth_providers.dart';
import '../auth/application/auth_state.dart';
import '../home/data/remote_home_repository.dart';
import '../home/domain/home_models.dart';
import '../video_detail/video_detail_page.dart';
import 'application/membership_providers.dart';
import 'application/membership_state.dart';
import 'data/mock_membership_repository.dart';
import 'data/remote_membership_repository.dart';
import 'data/remote_manual_membership_repository.dart';
import 'domain/manual_membership_repository.dart';
import 'domain/manual_payment_info.dart';
import 'domain/membership_plan.dart';
import 'domain/membership_repository.dart';
import 'domain/membership_status.dart';
import 'manual_payment_page.dart';

/// Outer widget — injects page-scoped providers via [ProviderScope].
class MembershipPage extends ConsumerWidget {
  const MembershipPage({
    super.key,
    this.repository,
    this.mockRepository = const MockMembershipRepository(),
    this.manualRepository,
    this.useRemote = true,
    this.vipVideosFuture,
    this.videoRepository,
    this.isActive = true,
    this.onSignInPressed,
    this.onSubscribePressed,
  });

  final MembershipRepository? repository;
  final MembershipRepository mockRepository;
  final ManualMembershipRepository? manualRepository;
  final bool useRemote;
  final Future<List<HomeVideoItem>>? vipVideosFuture;
  final RemoteHomeRepository? videoRepository;
  final bool isActive;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  MembershipRepository _resolveRepo(WidgetRef ref) {
    if (!useRemote) return mockRepository;
    return repository ??
        RemoteMembershipRepository(apiClient: ref.read(apiClientProvider));
  }

  ManualMembershipRepository _resolveManualRepo(WidgetRef ref) {
    return manualRepository ??
        RemoteManualMembershipRepository(
            apiClient: ref.read(apiClientProvider));
  }

  RemoteHomeRepository _resolveVideoRepo(WidgetRef ref) {
    return videoRepository ??
        RemoteHomeRepository(apiClient: ref.read(apiClientProvider));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Future<List<HomeVideoItem>>? vipFuture = vipVideosFuture;
    return ProviderScope(
      overrides: [
        membershipPageRepoProvider.overrideWithValue(_resolveRepo(ref)),
        membershipPageMockRepoProvider.overrideWithValue(mockRepository),
        membershipPageManualRepoProvider
            .overrideWithValue(_resolveManualRepo(ref)),
        membershipPageVideoRepoProvider
            .overrideWithValue(_resolveVideoRepo(ref)),
        membershipPageUseRemoteProvider.overrideWithValue(useRemote),
        if (vipFuture != null)
          membershipPageVipFutureProvider.overrideWithValue(vipFuture),
      ],
      child: _MembershipBody(
        isActive: isActive,
        onSignInPressed: onSignInPressed,
        onSubscribePressed: onSubscribePressed,
      ),
    );
  }
}

class _MembershipBody extends ConsumerStatefulWidget {
  const _MembershipBody({
    required this.isActive,
    this.onSignInPressed,
    this.onSubscribePressed,
  });

  final bool isActive;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  @override
  ConsumerState<_MembershipBody> createState() => _MembershipBodyState();
}

class _MembershipBodyState extends ConsumerState<_MembershipBody> {
  late final ProviderSubscription<AuthState> _authSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthState>(
      authControllerProvider,
      _handleAuthStateChanged,
    );
    Future<void>.microtask(() {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  void dispose() {
    _authSubscription.close();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MembershipBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      ref.invalidate(membershipPlansProvider);
      ref.invalidate(membershipVipVideosProvider);
      ref.invalidate(membershipPendingCodesProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshMembershipForActiveTab();
      });
    }
  }

  void _handleAuthStateChanged(AuthState? _, AuthState next) {
    if (next.isSignedOut) {
      ref.read(membershipControllerProvider.notifier).reset();
      return;
    }
    final bool shouldRefresh = next.session?.isSignedIn == true &&
        (next.status == AuthStatus.signedIn || next.status == AuthStatus.error);
    if (shouldRefresh) {
      ref.read(membershipControllerProvider.notifier).refresh();
    }
  }

  void _refreshMembershipForActiveTab() {
    final AuthState authState = ref.read(authControllerProvider);
    if (authState.session?.isSignedIn == true) {
      ref.read(membershipControllerProvider.notifier).refresh();
    }
  }

  void _showPendingReviewMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'We are reviewing your payment. This usually takes 1–2 business days.',
        ),
      ),
    );
  }

  Future<void> _handleBuyNowPressed(MembershipPlan plan) async {
    final String? planCode = plan.code?.trim();
    if (planCode == null || planCode.isEmpty) {
      _showMessage('Plan is unavailable. Please try again later.');
      return;
    }
    if (ref.read(membershipLoadingPlanCodeProvider) != null) return;

    ref.read(membershipLoadingPlanCodeProvider.notifier).set(planCode);
    final ManualMembershipRepository manualRepo =
        ref.read(membershipPageManualRepoProvider);
    final MembershipRepository membershipRepo =
        ref.read(membershipPageRepoProvider);

    try {
      final ManualPaymentInfo info =
          await manualRepo.getPaymentInfo(planCode: planCode);
      if (!mounted) return;
      ref.read(membershipLoadingPlanCodeProvider.notifier).set(null);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ManualPaymentPage(
            paymentInfo: info,
            repository: manualRepo,
            displayCurrency: plan.settlementTokenSymbol,
            supportedPaymentAssets: plan.supportedPaymentAssets,
            paymentAssetOptions: plan.paymentAssetOptions,
            membershipRepository: membershipRepo,
            onMembershipActivated: () {
              if (mounted) {
                ref
                    .read(membershipControllerProvider.notifier)
                    .refresh();
              }
            },
          ),
        ),
      );
      if (mounted) ref.invalidate(membershipPendingCodesProvider);
    } catch (_) {
      if (!mounted) return;
      ref.read(membershipLoadingPlanCodeProvider.notifier).set(null);
      _showMessage('Unable to load payment info. Please try again later.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final MembershipState membershipState =
        ref.watch(membershipControllerProvider);
    final bool isSignedIn = _isMembershipUser(authState);
    final bool canCreateOrders = authState.session?.isSignedIn == true;
    final bool authBusy = !canCreateOrders && !_isDefinitelySignedOut(authState);
    final MembershipStatus? status =
        isSignedIn ? _visibleMembershipStatus(membershipState) : null;

    return SafeArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          96,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _MembershipHeader(),
            const SizedBox(height: 14),
            _VipHeroCard(
              status: status,
              isSignedIn: isSignedIn,
              onSignInPressed: widget.onSignInPressed,
            ),
            const SizedBox(height: AppSpacing.md),
            _PlanSection(
              status: status,
              canCreateOrders: canCreateOrders,
              authBusy: authBusy,
              onSignInPressed: widget.onSignInPressed,
              onBuyNowPressed: _handleBuyNowPressed,
              onPendingReviewPressed: _showPendingReviewMessage,
            ),
            const SizedBox(height: AppSpacing.md),
            _ExclusiveSection(
              onSignInPressed: widget.onSignInPressed,
              onSubscribePressed: widget.onSubscribePressed,
            ),
          ],
        ),
      ),
    );
  }
}

bool _isDefinitelySignedOut(AuthState authState) {
  return authState.isSignedOut ||
      (authState.status == AuthStatus.error &&
          authState.session?.isSignedIn != true);
}

bool _isMembershipUser(AuthState authState) {
  if (authState.isSignedOut) return false;
  if (authState.session?.isSignedIn == true) return true;
  if (authState.status == AuthStatus.error) return false;
  return authState.status == AuthStatus.unknown ||
      authState.status == AuthStatus.checking ||
      authState.status == AuthStatus.refreshing;
}

MembershipStatus? _visibleMembershipStatus(MembershipState membershipState) {
  final MembershipStatus? membership = membershipState.membership;
  return membership?.isActive == true ? membership : null;
}

class _MembershipHeader extends StatelessWidget {
  const _MembershipHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            AppAssets.meowLogo,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Membership',
          style: AppTextStyles.sectionTitle.copyWith(
            fontSize: 16,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Container(
          width: 34,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border.all(color: AppColors.softBorder),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.workspace_premium_outlined,
            color: AppColors.brandGold,
            size: 19,
          ),
        ),
      ],
    );
  }
}

class _VipHeroCard extends StatelessWidget {
  const _VipHeroCard({
    required this.status,
    required this.isSignedIn,
    required this.onSignInPressed,
  });

  final MembershipStatus? status;
  final bool isSignedIn;
  final VoidCallback? onSignInPressed;

  @override
  Widget build(BuildContext context) {
    final MembershipStatus? currentStatus = status;
    final bool isActive = isSignedIn && currentStatus?.isActive == true;
    final String name = !isSignedIn
        ? 'Guest'
        : isActive
            ? 'Member'
            : 'Meow Plus';
    final String statusLabel = !isSignedIn
        ? 'Sign in required'
        : isActive
            ? currentStatus!.planTitle
            : 'Not subscribed';
    final String accessLine = !isSignedIn
        ? 'Sign in to unlock VIP access'
        : isActive
            ? _validUntilLabel(currentStatus!.endsAt)
            : 'Choose a plan to unlock VIP access';
    final String cta = !isSignedIn ? 'Sign in' : 'Subscribe';

    return Container(
      height: 166,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF5A4324),
            Color(0xFF322A22),
            AppColors.cardBackground,
          ],
        ),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.46)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 50,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[AppColors.brandGold, Color(0xFF8F6424)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.warmBackground,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 18,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.brandGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  accessLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Premium dramas, live rooms, and early picks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (!isActive) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            _GoldButton(
              label: cta,
              onTap: !isSignedIn ? onSignInPressed : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanSection extends ConsumerWidget {
  const _PlanSection({
    required this.status,
    required this.canCreateOrders,
    required this.authBusy,
    required this.onSignInPressed,
    required this.onBuyNowPressed,
    required this.onPendingReviewPressed,
  });

  final MembershipStatus? status;
  final bool canCreateOrders;
  final bool authBusy;
  final VoidCallback? onSignInPressed;
  final ValueChanged<MembershipPlan> onBuyNowPressed;
  final VoidCallback onPendingReviewPressed;

  VoidCallback? _planAction({
    required MembershipPlan plan,
    required String? loadingCode,
    required Set<String> pendingCodes,
  }) {
    if (authBusy) return null;
    if (!canCreateOrders) return onSignInPressed;
    final String? code = plan.code?.trim();
    if (code != null && pendingCodes.contains(code)) {
      return onPendingReviewPressed;
    }
    if (loadingCode != null) return null;
    return () => onBuyNowPressed(plan);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MembershipPlan> plans = _displayPlans(
      ref.watch(membershipPlansProvider).value ?? const <MembershipPlan>[],
    );
    final String? loadingCode = ref.watch(membershipLoadingPlanCodeProvider);
    final Set<String> pendingCodes =
        ref.watch(membershipPendingCodesProvider).value ?? const <String>{};
    final MembershipStatus? activeStatus =
        status?.isActive == true ? status : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle(title: 'Membership Plans'),
        const SizedBox(height: AppSpacing.xs),
        for (int index = 0; index < plans.length; index++) ...<Widget>[
          _PlanCard(
            plan: plans[index],
            isCurrent: activeStatus?.planTitle == plans[index].title,
            isBusy: loadingCode != null && loadingCode == plans[index].code,
            isPending: pendingCodes.contains(plans[index].code ?? ''),
            hasActiveMembership: activeStatus != null,
            onPressed: _planAction(
              plan: plans[index],
              loadingCode: loadingCode,
              pendingCodes: pendingCodes,
            ),
          ),
          if (index != plans.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isBusy,
    required this.isPending,
    required this.hasActiveMembership,
    required this.onPressed,
  });

  final MembershipPlan plan;
  final bool isCurrent;
  final bool isBusy;
  final bool isPending;
  final bool hasActiveMembership;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final String price = _displayPrice(plan.price);
    final String? badge = _planBadge(plan);
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
          color: isCurrent
              ? AppColors.brandGold.withValues(alpha: 0.60)
              : AppColors.softBorder,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                    ),
                    if (badge != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      _VipStatusBadge(label: badge),
                    ],
                    if (isCurrent) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      const _VipStatusBadge(label: 'Current'),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.brandGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        plan.perks,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _OutlineGoldButton(
            label: isBusy
                ? 'Loading...'
                : isPending
                    ? 'Pending Review'
                    : isCurrent
                        ? 'Renew'
                        : hasActiveMembership
                            ? 'Upgrade'
                            : 'Buy Now',
            onTap: onPressed,
          ),
        ],
      ),
    );
  }
}

class _ExclusiveSection extends ConsumerWidget {
  const _ExclusiveSection({
    required this.onSignInPressed,
    required this.onSubscribePressed,
  });

  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<HomeVideoItem> videos =
        ref.watch(membershipVipVideosProvider).value ??
            const <HomeVideoItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle(title: 'Exclusive for Members'),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.isEmpty ? _vipPicks.length : videos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 16 / 9,
          ),
          itemBuilder: (BuildContext context, int index) {
            if (videos.isEmpty) {
              return _ExclusiveFallbackCard(pick: _vipPicks[index]);
            }
            return _ExclusiveVideoCard(
              video: videos[index],
              recommendations: videos,
              onSignInPressed: onSignInPressed,
              onSubscribePressed: onSubscribePressed,
            );
          },
        ),
      ],
    );
  }
}

class _ExclusiveVideoCard extends StatelessWidget {
  const _ExclusiveVideoCard({
    required this.video,
    required this.recommendations,
    required this.onSignInPressed,
    required this.onSubscribePressed,
  });

  final HomeVideoItem video;
  final List<HomeVideoItem> recommendations;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('membership-vip-video-card-${video.id}'),
      onTap: () => _openMembershipVideoDetail(
        context,
        video,
        recommendations,
        onSignInPressed: onSignInPressed,
        onSubscribePressed: onSubscribePressed,
      ),
      child: _ExclusiveCardFrame(
        imageUrl: video.thumbnailUrl,
        title: video.title,
        subtitle: _membershipVideoSubtitle(video),
        showLockedBadge: video.isLocked == true,
      ),
    );
  }
}

class _ExclusiveFallbackCard extends StatelessWidget {
  const _ExclusiveFallbackCard({required this.pick});

  final _VipPick pick;

  @override
  Widget build(BuildContext context) {
    return _ExclusiveCardFrame(
      title: pick.title,
      subtitle: pick.subtitle,
      colors: pick.colors,
    );
  }
}

class _ExclusiveCardFrame extends StatelessWidget {
  const _ExclusiveCardFrame({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.colors,
    this.showLockedBadge = false,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final List<Color>? colors;
  final bool showLockedBadge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _VipCardCover(imageUrl: imageUrl, colors: colors),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x10000000),
                  Color(0x50000000),
                  Color(0xD9000000),
                ],
              ),
            ),
          ),
          const Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: _VipStatusBadge(label: 'VIP'),
          ),
          if (showLockedBadge)
            const Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: _VipStatusBadge(label: 'Locked'),
            ),
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VipCardCover extends StatelessWidget {
  const _VipCardCover({this.imageUrl, this.colors});

  final String? imageUrl;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final String? trimmedUrl = imageUrl?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return _VipGradient(colors: colors ?? _defaultVipGradientColors);
    }
    return AppCachedImage(
      imageUrl: trimmedUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          _VipGradient(colors: colors ?? _defaultVipGradientColors),
      errorWidget: (_, __, ___) =>
          _VipGradient(colors: colors ?? _defaultVipGradientColors),
    );
  }
}

class _VipGradient extends StatelessWidget {
  const _VipGradient({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(
        Icons.workspace_premium,
        color: AppColors.brandGold.withValues(alpha: 0.55),
        size: 36,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.sectionTitle.copyWith(
        fontSize: 16,
        height: 1.15,
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.brandGold,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.warmBackground,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _OutlineGoldButton extends StatelessWidget {
  const _OutlineGoldButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.brandGold.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.brandGold,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _VipStatusBadge extends StatelessWidget {
  const _VipStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.75),
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
      ),
    );
  }
}

class _VipPick {
  const _VipPick({
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
}

const List<Color> _defaultVipGradientColors = <Color>[
  Color(0xFF5A4324),
  Color(0xFF24201F),
];


String _membershipVideoSubtitle(HomeVideoItem video) {
  final String owner = video.ownerName?.trim().isNotEmpty == true
      ? video.ownerName!.trim()
      : 'VIP video';
  return '$owner · ${video.viewCount ?? 0} views';
}

void _openMembershipVideoDetail(
  BuildContext context,
  HomeVideoItem video,
  List<HomeVideoItem> recommendations, {
  VoidCallback? onSignInPressed,
  VoidCallback? onSubscribePressed,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VideoDetailPage(
        video: video,
        recommendations: recommendations,
        onSignInPressed: onSignInPressed,
        onSubscribePressed: onSubscribePressed,
      ),
    ),
  );
}

const List<MembershipPlan> _placeholderPlans = <MembershipPlan>[
  MembershipPlan(
    id: 'placeholder-monthly',
    code: 'monthly',
    title: 'Monthly',
    price: 'THB 99 / month',
    perks: 'Flexible access',
    durationDays: 30,
  ),
  MembershipPlan(
    id: 'placeholder-quarterly',
    code: 'quarterly',
    title: 'Quarterly',
    price: 'THB 259 / quarter',
    perks: 'Popular choice',
    durationDays: 90,
  ),
  MembershipPlan(
    id: 'placeholder-yearly',
    code: 'yearly',
    title: 'Yearly',
    price: 'THB 899 / year',
    perks: 'Best value',
    durationDays: 365,
  ),
];

const List<_VipPick> _vipPicks = <_VipPick>[
  _VipPick(
    title: 'Golden Hour Drama',
    subtitle: 'Member-only episodes',
    colors: <Color>[Color(0xFF6D4F24), Color(0xFF2E2820)],
  ),
  _VipPick(
    title: 'Creator Masterclass',
    subtitle: 'Premium creator lessons',
    colors: <Color>[Color(0xFF59412B), Color(0xFF24201D)],
  ),
  _VipPick(
    title: 'Premium Live Room',
    subtitle: 'VIP live access',
    colors: <Color>[Color(0xFF4B3F26), Color(0xFF1F2220)],
  ),
  _VipPick(
    title: 'Early Access Picks',
    subtitle: 'Watch before everyone',
    colors: <Color>[Color(0xFF5A3928), Color(0xFF24201F)],
  ),
  _VipPick(
    title: 'Hidden Gems',
    subtitle: 'Curated member picks',
    colors: <Color>[Color(0xFF3D4F2E), Color(0xFF1E2820)],
  ),
  _VipPick(
    title: 'Behind the Scenes',
    subtitle: 'Exclusive creator content',
    colors: <Color>[Color(0xFF2E3F5A), Color(0xFF1A2028)],
  ),
  _VipPick(
    title: 'Director\'s Cut',
    subtitle: 'Extended episodes',
    colors: <Color>[Color(0xFF4F2E3D), Color(0xFF281E24)],
  ),
  _VipPick(
    title: 'Night Stories',
    subtitle: 'Premium late-night dramas',
    colors: <Color>[Color(0xFF2E2E5A), Color(0xFF1A1A28)],
  ),
  _VipPick(
    title: 'Shorts Collection',
    subtitle: 'VIP short films',
    colors: <Color>[Color(0xFF5A3F2E), Color(0xFF28201A)],
  ),
  _VipPick(
    title: 'Top Creators',
    subtitle: 'Follow exclusive creators',
    colors: <Color>[Color(0xFF3F5A2E), Color(0xFF202818)],
  ),
  _VipPick(
    title: 'Live Replays',
    subtitle: 'Missed a live? Watch now',
    colors: <Color>[Color(0xFF5A4F2E), Color(0xFF282418)],
  ),
  _VipPick(
    title: 'Monthly Specials',
    subtitle: 'New drops every month',
    colors: <Color>[Color(0xFF4F3F5A), Color(0xFF241E28)],
  ),
];

List<MembershipPlan> _displayPlans(List<MembershipPlan> remotePlans) {
  final List<MembershipPlan> plans = <MembershipPlan>[];
  final Set<int> usedRemoteIndexes = <int>{};

  for (final MembershipPlan placeholder in _placeholderPlans) {
    final int remoteIndex = _remotePlanIndexForSlot(
      remotePlans,
      placeholder,
      usedRemoteIndexes,
      allowFirstAvailable: plans.isEmpty,
    );
    if (remoteIndex == -1) {
      plans.add(placeholder);
      continue;
    }

    usedRemoteIndexes.add(remoteIndex);
    plans.add(remotePlans[remoteIndex]);
  }

  return plans;
}

int _remotePlanIndexForSlot(
  List<MembershipPlan> remotePlans,
  MembershipPlan placeholder,
  Set<int> usedRemoteIndexes, {
  required bool allowFirstAvailable,
}) {
  final String slot = placeholder.title.toLowerCase();

  for (int index = 0; index < remotePlans.length; index++) {
    if (usedRemoteIndexes.contains(index)) continue;
    if (_planMatchesSlot(remotePlans[index], slot)) return index;
  }

  if (!allowFirstAvailable) return -1;
  for (int index = 0; index < remotePlans.length; index++) {
    if (!usedRemoteIndexes.contains(index)) return index;
  }
  return -1;
}

bool _planMatchesSlot(MembershipPlan plan, String slot) {
  final String haystack = '${plan.title} ${plan.price}'.toLowerCase();
  return switch (slot) {
    'monthly' => haystack.contains('month') || haystack.contains('monthly'),
    'quarterly' => haystack.contains('quarter') || haystack.contains('3 month'),
    'yearly' => haystack.contains('year') || haystack.contains('annual'),
    _ => false,
  };
}

String? _planBadge(MembershipPlan plan) {
  final String label = '${plan.title} ${plan.price}'.toLowerCase();
  if (label.contains('quarter')) return 'Popular';
  if (label.contains('year') || label.contains('annual')) return 'Best value';
  return null;
}

String _displayPrice(String price) {
  return price.trim() == 'Price unavailable' ? 'Pricing coming soon' : price;
}

String _validUntilLabel(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) return 'Valid while membership is active';
  final DateTime? parsed = DateTime.tryParse(rawDate);
  if (parsed == null) return 'Valid until $rawDate';
  const List<String> months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return 'Valid until ${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}
