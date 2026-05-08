import 'package:flutter/material.dart';

import '../../app/theme/app_assets.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
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
  });

  final MembershipRepository? repository;
  final MembershipRepository mockRepository;
  final bool useRemote;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  late MembershipRepository _repository;
  late Future<List<MembershipPlan>> _plansFuture;
  late Future<MembershipStatus?> _statusFuture;

  @override
  void initState() {
    super.initState();
    _repository = _defaultRepository();
    _plansFuture = _loadPlans();
    _statusFuture = _loadStatus();
  }

  @override
  void didUpdateWidget(covariant MembershipPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.mockRepository != widget.mockRepository ||
        oldWidget.useRemote != widget.useRemote) {
      _repository = _defaultRepository();
      _plansFuture = _loadPlans();
      _statusFuture = _loadStatus();
    }
  }

  MembershipRepository _defaultRepository() {
    if (!widget.useRemote) return widget.mockRepository;
    return widget.repository ?? RemoteMembershipRepository(apiClient: ApiClient());
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
            FutureBuilder<MembershipStatus?>(
              future: _statusFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<MembershipStatus?> snapshot,
              ) {
                return _VipHeroCard(status: snapshot.data);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlanSection(
              plansFuture: _plansFuture,
              statusFuture: _statusFuture,
            ),
            const SizedBox(height: AppSpacing.md),
            const _ExclusiveSection(),
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
  const _VipHeroCard({required this.status});

  final MembershipStatus? status;

  @override
  Widget build(BuildContext context) {
    final MembershipStatus? currentStatus = status;
    final bool isActive = currentStatus?.isActive == true;
    final String name = isActive ? 'Member' : 'Meow Plus';
    final String level = isActive ? currentStatus!.planTitle : 'Not subscribed';
    final String expiry = isActive
        ? _validUntilLabel(currentStatus!.endsAt)
        : 'Choose a plan to unlock VIP access';
    final String cta = isActive ? 'Manage' : 'Subscribe';

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
          Container(
            width: 50,
            height: 50,
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.warmBackground,
                  size: 27,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  level,
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
                  expiry,
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
  const _ExclusiveSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle(title: 'Exclusive for Members'),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _vipPicks.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 16 / 9,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _ExclusiveCard(pick: _vipPicks[index]);
          },
        ),
      ],
    );
  }
}

class _ExclusiveCard extends StatelessWidget {
  const _ExclusiveCard({required this.pick});

  final _VipPick pick;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _VipGradient(colors: pick.colors),
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
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  pick.title,
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
                  pick.subtitle,
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
