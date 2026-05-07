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
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.brandGold, AppColors.deepGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Meow Plus',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkDark,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Unlock premium badges, perks, and exclusive rooms.',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<MembershipStatus?>(
            future: _statusFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<MembershipStatus?> snapshot,
            ) {
              return _MembershipStatusCard(status: snapshot.data);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<MembershipPlan>>(
            future: _plansFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<MembershipPlan>> snapshot,
            ) {
              final List<MembershipPlan> plans =
                  snapshot.data ?? const <MembershipPlan>[];
              if (plans.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: <Widget>[
                  for (int i = 0; i < plans.length; i++) ...<Widget>[
                    _PlanCard(
                      title: plans[i].title,
                      price: plans[i].price,
                      perks: plans[i].perks,
                    ),
                    if (i != plans.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({required this.status});

  final MembershipStatus? status;

  @override
  Widget build(BuildContext context) {
    final MembershipStatus? currentStatus = status;
    final bool isActive = currentStatus?.isActive == true;
    final String title = isActive ? 'Active membership' : 'Membership status';
    final String subtitle = currentStatus != null && isActive
        ? currentStatus.planTitle
        : 'Sign in to view membership status. Choose a plan below.';
    final String? statusText = currentStatus != null && isActive
        ? _activeStatusText(currentStatus)
        : null;

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
          Text(subtitle, style: AppTextStyles.caption),
          if (statusText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              statusText,
              style: AppTextStyles.body.copyWith(
                color: AppColors.deepGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _activeStatusText(MembershipStatus status) {
    final String? endsAt = status.endsAt;
    if (endsAt == null || endsAt.trim().isEmpty) return status.status;
    return '${status.status} · Ends at ${endsAt.trim()}';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.perks,
  });

  final String title;
  final String price;
  final String perks;

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
          Text(
            price,
            style: AppTextStyles.body.copyWith(
              color: AppColors.deepGold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(perks, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
