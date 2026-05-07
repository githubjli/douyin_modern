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
          const SizedBox(height: AppSpacing.md),
          const _BenefitsSection(),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<MembershipPlan>>(
            future: _plansFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<MembershipPlan>> snapshot,
            ) {
              final List<MembershipPlan> plans =
                  snapshot.data ?? const <MembershipPlan>[];
              if (plans.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<MembershipStatus?>(
                future: _statusFuture,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<MembershipStatus?> statusSnapshot,
                ) {
                  final MembershipStatus? currentStatus = statusSnapshot.data;
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
                          tag: _planTag(plans[i], currentStatus, i),
                          ctaLabel: _planCtaLabel(plans[i], currentStatus),
                        ),
                        if (i != plans.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              );
            },
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
    final bool isActive = currentStatus?.isActive == true;
    final MembershipStatus? activeStatus = isActive ? currentStatus : null;
    final String chipLabel = isActive ? 'Active' : 'Not subscribed';
    final String planTitle =
        activeStatus?.planTitle ?? 'Choose your Meow Plus plan';
    final String dateLabel = activeStatus == null
        ? 'Premium perks unlock after subscription'
        : _validUntilLabel(activeStatus.endsAt);
    final String actionLabel = activeStatus != null
        ? 'Manage'
        : currentStatus == null
            ? 'Subscribe'
            : 'Renew';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF4A3820),
            Color(0xFF2F2922),
            AppColors.cardBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brandGold.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Meow Plus',
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 24),
                ),
              ),
              _StatusChip(label: chipLabel, isActive: isActive),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            planTitle,
            style: AppTextStyles.cardTitle.copyWith(
              color: AppColors.brandGold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(dateLabel, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.lg),
          _PrimaryActionButton(label: actionLabel),
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
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandGold,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(
          color: AppColors.warmBackground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection();

  static const List<_BenefitSpec> _benefits = <_BenefitSpec>[
    _BenefitSpec(Icons.verified_rounded, 'Premium badge', 'Stand out in Meow'),
    _BenefitSpec(Icons.meeting_room_rounded, 'Exclusive rooms', 'Member chats'),
    _BenefitSpec(Icons.theaters_rounded, 'Member-only dramas', 'Bonus stories'),
    _BenefitSpec(Icons.flash_on_rounded, 'Priority access', 'Early features'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Your Benefits',
          style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final _BenefitSpec benefit in _benefits)
              _BenefitCard(benefit: benefit),
          ],
        ),
      ],
    );
  }
}

class _BenefitSpec {
  const _BenefitSpec(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.benefit});

  final _BenefitSpec benefit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(benefit.icon, color: AppColors.brandGold, size: 20),
          const SizedBox(height: AppSpacing.xs),
          Text(benefit.title, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            benefit.subtitle,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
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
  final String? tag;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
          color: tag == 'Current'
              ? AppColors.brandGold
              : AppColors.softBorder,
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
              if (tag != null) _PlanTag(label: tag!),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(plan.perks, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
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

String _planTag(
  MembershipPlan plan,
  MembershipStatus? status,
  int index,
) {
  if (_isCurrentPlan(plan, status)) return 'Current';
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
