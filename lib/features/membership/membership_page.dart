import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../shared/brand_page_header.dart';
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
    return widget.repository ??
        RemoteMembershipRepository(apiClient: ApiClient());
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
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const BrandPageHeader(title: 'Membership'),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<MembershipStatus?>(
            future: _statusFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<MembershipStatus?> snapshot,
            ) {
              return _MembershipHeroCard(status: snapshot.data);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const _VipSection(),
          const SizedBox(height: AppSpacing.lg),
          _PlansSection(
            plansFuture: _plansFuture,
            statusFuture: _statusFuture,
          ),
        ],
      ),
    );
  }
}

class _MembershipHeroCard extends StatelessWidget {
  const _MembershipHeroCard({required this.status});

  final MembershipStatus? status;

  @override
  Widget build(BuildContext context) {
    final MembershipStatus? currentStatus = status;
    final MembershipStatus? activeStatus =
        currentStatus != null && currentStatus.isActive ? currentStatus : null;
    final bool hasInactiveStatus = currentStatus != null && activeStatus == null;
    final String chipLabel = activeStatus != null
        ? 'Active'
        : hasInactiveStatus
            ? 'Not subscribed'
            : 'Sign in required';
    final String planTitle = activeStatus != null
        ? activeStatus.planTitle
        : hasInactiveStatus
            ? 'No active membership'
            : 'Choose your Meow Plus plan';
    final String detail = activeStatus != null
        ? _validUntilLabel(activeStatus.endsAt)
        : hasInactiveStatus
            ? 'Renew anytime to unlock member perks.'
            : 'Sign in to view status or subscribe below.';
    final String cta = activeStatus != null
        ? 'Manage'
        : hasInactiveStatus
            ? 'Renew'
            : 'Subscribe';
    final bool isActive = activeStatus != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 224),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF4F3921),
            Color(0xFF2F2922),
            AppColors.cardBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.48)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brandGold.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Meow Plus',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 24,
                    height: 1.1,
                  ),
                ),
              ),
              _StatusChip(label: chipLabel, isActive: isActive),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            planTitle,
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.brandGold,
              fontSize: 22,
              height: 1.14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(detail, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.centerLeft,
            child: _HeroCta(label: cta),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.brandGold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: isActive ? AppColors.brandGold : AppColors.softBorder,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: isActive ? AppColors.brandGold : AppColors.mutedOliveText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandGold,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: AppColors.warmBackground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VipSection extends StatelessWidget {
  const _VipSection();

  static const List<_VipPick> _picks = <_VipPick>[
    _VipPick(
      title: 'Golden Hour Room',
      subtitle: 'Private creator lounge',
      badge: 'VIP',
    ),
    _VipPick(
      title: 'Midnight Drama Cut',
      subtitle: 'Member-only episode',
      badge: 'Exclusive',
    ),
    _VipPick(
      title: 'Creator Masterclass',
      subtitle: 'Priority learning drop',
      badge: 'VIP',
    ),
    _VipPick(
      title: 'Early Access Vault',
      subtitle: 'Preview tomorrow picks',
      badge: 'Exclusive',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Exclusive for Members',
          style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _picks.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (_, int index) => _VipPickCard(pick: _picks[index]),
        ),
      ],
    );
  }
}

class _VipPick {
  const _VipPick({
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final String title;
  final String subtitle;
  final String badge;
}

class _VipPickCard extends StatelessWidget {
  const _VipPickCard({required this.pick});

  final _VipPick pick;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _VipCoverPlaceholder(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x14000000),
                  Color(0x44000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: _VipBadge(label: pick.badge),
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
                    fontSize: 13,
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
                    fontSize: 10,
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

class _VipCoverPlaceholder extends StatelessWidget {
  const _VipCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF5A4324),
            Color(0xFF2D2923),
            Color(0xFF1E1D1B),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.workspace_premium,
          color: AppColors.brandGold,
          size: 32,
        ),
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.warmBackground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({required this.plansFuture, required this.statusFuture});

  final Future<List<MembershipPlan>> plansFuture;
  final Future<MembershipStatus?> statusFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MembershipPlan>>(
      future: plansFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MembershipPlan>> snapshot,
      ) {
        final List<MembershipPlan> plans =
            snapshot.data ?? const <MembershipPlan>[];
        if (plans.isEmpty) return const SizedBox.shrink();

        return FutureBuilder<MembershipStatus?>(
          future: statusFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<MembershipStatus?> statusSnapshot,
          ) {
            final MembershipStatus? status = statusSnapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Choose your plan',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (int i = 0; i < plans.length; i++) ...<Widget>[
                  _PlanCard(
                    plan: plans[i],
                    tag: _planTag(plans[i], status, i),
                    ctaLabel: _planCtaLabel(plans[i], status),
                  ),
                  if (i != plans.length - 1)
                    const SizedBox(height: AppSpacing.sm),
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
  const _PlanCard({
    required this.plan,
    required this.tag,
    required this.ctaLabel,
  });

  final MembershipPlan plan;
  final String tag;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final bool current = tag == 'Current plan';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
          color: current ? AppColors.brandGold : AppColors.softBorder,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(plan.title, style: AppTextStyles.cardTitle),
              ),
              _PlanTag(label: tag),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(plan.perks, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _displayPrice(plan.price),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.brandGold,
                    fontSize: 18,
                  ),
                ),
              ),
              _PlanCta(label: ctaLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanTag extends StatelessWidget {
  const _PlanTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.55)),
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

class _PlanCta extends StatelessWidget {
  const _PlanCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool current = label == 'Current plan';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: current ? Colors.transparent : AppColors.brandGold,
        border: Border.all(color: AppColors.brandGold),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: current ? AppColors.brandGold : AppColors.warmBackground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _planTag(MembershipPlan plan, MembershipStatus? status, int index) {
  if (_isCurrentPlan(plan, status)) return 'Current plan';
  final String title = plan.title.toLowerCase();
  if (title.contains('year') || title.contains('annual')) return 'Best value';
  if (index == 0) return 'Popular';
  return 'Member pick';
}

String _planCtaLabel(MembershipPlan plan, MembershipStatus? status) {
  if (_isCurrentPlan(plan, status)) return 'Current plan';
  if (status?.isActive == true) return 'Switch plan';
  return 'Subscribe';
}

bool _isCurrentPlan(MembershipPlan plan, MembershipStatus? status) {
  if (status == null || !status.isActive) return false;
  final String planTitle = _normalizePlanName(plan.title);
  final String statusTitle = _normalizePlanName(status.planTitle);
  return planTitle == statusTitle;
}

String _displayPrice(String price) {
  final String trimmed = price.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'price unavailable') {
    return 'Pricing coming soon';
  }
  return trimmed;
}

String _validUntilLabel(String? rawDate) {
  final String? formatted = _formatMembershipDate(rawDate);
  if (formatted == null) return 'Membership is active';
  return 'Valid until $formatted';
}

String? _formatMembershipDate(String? rawDate) {
  if (rawDate == null || rawDate.trim().isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(rawDate.trim());
  if (parsed == null) return rawDate.trim();
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
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

String _normalizePlanName(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
