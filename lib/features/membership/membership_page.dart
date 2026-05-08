import 'package:flutter/material.dart';

import '../../app/theme/app_assets.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../auth/data/remote_auth_repository.dart';
import '../auth/domain/auth_repository.dart';
import '../home/data/remote_home_repository.dart';
import '../home/domain/home_models.dart';
import '../video_detail/video_detail_page.dart';
import 'data/mock_membership_repository.dart';
import 'data/remote_membership_repository.dart';
import 'domain/membership_plan.dart';
import 'domain/membership_repository.dart';
import 'domain/membership_status.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({
    super.key,
    this.repository,
    this.mockRepository = const MockMembershipRepository(),
    this.useRemote = true,
    this.vipVideosFuture,
    this.videoRepository,
    this.authRepository,
    this.signedInFuture,
    this.isActive = true,
  });

  final MembershipRepository? repository;
  final MembershipRepository mockRepository;
  final bool useRemote;
  final Future<List<HomeVideoItem>>? vipVideosFuture;
  final RemoteHomeRepository? videoRepository;
  final AuthRepository? authRepository;
  final Future<bool>? signedInFuture;
  final bool isActive;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  late MembershipRepository _repository;
  late RemoteHomeRepository _videoRepository;
  late AuthRepository _authRepository;
  late Future<List<MembershipPlan>> _plansFuture;
  late Future<MembershipStatus?> _statusFuture;
  late Future<bool> _signedInFuture;
  late Future<List<HomeVideoItem>> _vipVideosFuture;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _configureRepositories();
    _refreshMembershipState(notify: false);
  }

  @override
  void didUpdateWidget(covariant MembershipPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.mockRepository != widget.mockRepository ||
        oldWidget.useRemote != widget.useRemote ||
        oldWidget.vipVideosFuture != widget.vipVideosFuture ||
        oldWidget.videoRepository != widget.videoRepository ||
        oldWidget.authRepository != widget.authRepository ||
        oldWidget.signedInFuture != widget.signedInFuture) {
      _configureRepositories();
      _refreshMembershipState();
      return;
    }

    if (!oldWidget.isActive && widget.isActive) {
      _refreshMembershipState();
    }
  }

  void _configureRepositories() {
    _repository = _defaultRepository();
    _videoRepository = _defaultVideoRepository();
    _authRepository = _defaultAuthRepository();
  }

  void _refreshMembershipState({bool notify = true}) {
    if (_refreshing) return;
    _refreshing = true;

    final Future<List<MembershipPlan>> plansFuture = _loadPlans();
    final Future<MembershipStatus?> statusFuture = _loadStatus();
    final Future<bool> signedInFuture =
        widget.signedInFuture ?? _loadSignedInState();
    final Future<List<HomeVideoItem>> vipVideosFuture =
        widget.vipVideosFuture ?? _loadVipVideos();

    void applyFutures() {
      _plansFuture = plansFuture;
      _statusFuture = statusFuture;
      _signedInFuture = signedInFuture;
      _vipVideosFuture = vipVideosFuture;
    }

    if (notify) {
      setState(applyFutures);
    } else {
      applyFutures();
    }

    Future.wait<dynamic>(<Future<dynamic>>[
      plansFuture,
      statusFuture,
      signedInFuture,
      vipVideosFuture,
    ]).whenComplete(() {
      _refreshing = false;
    });
  }

  MembershipRepository _defaultRepository() {
    if (!widget.useRemote) return widget.mockRepository;
    return widget.repository ?? RemoteMembershipRepository(apiClient: ApiClient());
  }

  RemoteHomeRepository _defaultVideoRepository() {
    return widget.videoRepository ?? RemoteHomeRepository(apiClient: ApiClient());
  }

  AuthRepository _defaultAuthRepository() {
    return widget.authRepository ?? RemoteAuthRepository(apiClient: ApiClient());
  }

  Future<bool> _loadSignedInState() async {
    if (!widget.useRemote) return true;
    try {
      final session = await _authRepository.getCurrentSession();
      return session.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  Future<MembershipStatus?> _loadStatus() async {
    try {
      return await _repository.getCurrentStatus();
    } catch (_) {
      return null;
    }
  }

  Future<List<MembershipPlan>> _loadPlans() async {
    try {
      final List<MembershipPlan> plans = await _repository.getPlans();
      if (plans.isNotEmpty) return plans;
    } catch (_) {
      // Fall through to the bundled mock plans so Membership stays usable.
    }
    return widget.mockRepository.getPlans();
  }

  Future<List<HomeVideoItem>> _loadVipVideos() async {
    if (!widget.useRemote) return const <HomeVideoItem>[];
    try {
      final HomeVideoPage page = await _videoRepository.getVideoPage(
        accessType: 'membership',
        pageSize: 4,
      );
      final List<HomeVideoItem> membershipVideos = _membershipVideos(page.items);
      if (membershipVideos.isNotEmpty) return membershipVideos.take(4).toList();
    } catch (_) {
      // Fall through to an unfiltered fetch; older backends may ignore access_type.
    }

    try {
      final HomeVideoPage page = await _videoRepository.getVideoPage(pageSize: 12);
      return _membershipVideos(page.items).take(4).toList();
    } catch (_) {
      return const <HomeVideoItem>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
            FutureBuilder<bool>(
              future: _signedInFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<bool> signedInSnapshot,
              ) {
                return FutureBuilder<MembershipStatus?>(
                  future: _statusFuture,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<MembershipStatus?> statusSnapshot,
                  ) {
                    return _VipHeroCard(
                      status: statusSnapshot.data,
                      isSignedIn: signedInSnapshot.data ?? false,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlanSection(
              plansFuture: _plansFuture,
              statusFuture: _statusFuture,
            ),
            const SizedBox(height: AppSpacing.md),
            _ExclusiveSection(videosFuture: _vipVideosFuture),
          ],
        ),
      ),
    );
  }
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
  const _VipHeroCard({required this.status, required this.isSignedIn});

  final MembershipStatus? status;
  final bool isSignedIn;

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
    final String cta = !isSignedIn
        ? 'Sign in'
        : isActive
            ? 'Manage'
            : 'Subscribe';

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
          const SizedBox(width: AppSpacing.sm),
          _GoldButton(label: cta),
        ],
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.plansFuture,
    required this.statusFuture,
  });

  final Future<List<MembershipPlan>> plansFuture;
  final Future<MembershipStatus?> statusFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MembershipPlan>>(
      future: plansFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MembershipPlan>> planSnapshot,
      ) {
        final List<MembershipPlan> plans = _displayPlans(
          planSnapshot.data ?? const <MembershipPlan>[],
        );
        return FutureBuilder<MembershipStatus?>(
          future: statusFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<MembershipStatus?> statusSnapshot,
          ) {
            final MembershipStatus? activeStatus =
                statusSnapshot.data?.isActive == true ? statusSnapshot.data : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle(title: 'Membership Plans'),
                const SizedBox(height: AppSpacing.xs),
                for (int index = 0; index < plans.length; index++) ...<Widget>[
                  _PlanCard(
                    plan: plans[index],
                    isCurrent: activeStatus?.planTitle == plans[index].title,
                  ),
                  if (index != plans.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.isCurrent});

  final MembershipPlan plan;
  final bool isCurrent;

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
          _OutlineGoldButton(label: isCurrent ? 'Manage' : 'Buy Now'),
        ],
      ),
    );
  }
}

class _ExclusiveSection extends StatelessWidget {
  const _ExclusiveSection({required this.videosFuture});

  final Future<List<HomeVideoItem>> videosFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HomeVideoItem>>(
      future: videosFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<HomeVideoItem>> snapshot,
      ) {
        final List<HomeVideoItem> videos = snapshot.data ?? const <HomeVideoItem>[];
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
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ExclusiveVideoCard extends StatelessWidget {
  const _ExclusiveVideoCard({
    required this.video,
    required this.recommendations,
  });

  final HomeVideoItem video;
  final List<HomeVideoItem> recommendations;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('membership-vip-video-card-${video.id}'),
      onTap: () => _openMembershipVideoDetail(context, video, recommendations),
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
                    fontSize: 13,
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
    return Image.network(
      trimmedUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return _VipGradient(colors: colors ?? _defaultVipGradientColors);
      },
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? loadingProgress,
      ) {
        if (loadingProgress == null) return child;
        return _VipGradient(colors: colors ?? _defaultVipGradientColors);
      },
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
  const _GoldButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _OutlineGoldButton extends StatelessWidget {
  const _OutlineGoldButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _VipStatusBadge extends StatelessWidget {
  const _VipStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.16),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.52)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.brandGold,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
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

List<HomeVideoItem> _membershipVideos(List<HomeVideoItem> videos) {
  return videos.where((HomeVideoItem video) => video.isMembershipVideo).toList();
}

String _membershipVideoSubtitle(HomeVideoItem video) {
  final String owner = video.ownerName?.trim().isNotEmpty == true
      ? video.ownerName!.trim()
      : 'VIP video';
  return '$owner · ${video.viewCount ?? 0} views';
}

void _openMembershipVideoDetail(
  BuildContext context,
  HomeVideoItem video,
  List<HomeVideoItem> recommendations,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VideoDetailPage(
        video: video,
        recommendations: recommendations,
      ),
    ),
  );
}

const List<MembershipPlan> _placeholderPlans = <MembershipPlan>[
  MembershipPlan(
    id: 'placeholder-monthly',
    title: 'Monthly',
    price: 'THB 99 / month',
    perks: 'Flexible access',
  ),
  MembershipPlan(
    id: 'placeholder-quarterly',
    title: 'Quarterly',
    price: 'THB 259 / quarter',
    perks: 'Popular choice',
  ),
  MembershipPlan(
    id: 'placeholder-yearly',
    title: 'Yearly',
    price: 'THB 899 / year',
    perks: 'Best value',
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
