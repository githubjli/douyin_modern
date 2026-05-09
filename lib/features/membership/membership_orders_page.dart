import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'application/membership_providers.dart';
import 'application/membership_state.dart';
import 'domain/membership_status.dart';

class MembershipOrdersPage extends ConsumerWidget {
  const MembershipOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MembershipState state = ref.watch(membershipControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.brandGold),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Membership & Orders',
          style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            _MembershipStatusCard(state: state),
            const SizedBox(height: AppSpacing.md),
            const _OrderHistoryNote(),
          ],
        ),
      ),
    );
  }
}

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({required this.state});

  final MembershipState state;

  @override
  Widget build(BuildContext context) {
    final MembershipStatus? membership = state.membership;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
          color: state.hasActiveMembership
              ? AppColors.brandGold.withValues(alpha: 0.55)
              : AppColors.softBorder,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                state.hasActiveMembership
                    ? Icons.workspace_premium_rounded
                    : Icons.workspace_premium_outlined,
                color: AppColors.brandGold,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Membership Status',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.isLoading)
            Text(
              'Loading...',
              style: AppTextStyles.body.copyWith(fontSize: 13),
            )
          else if (membership == null || !membership.isActive)
            const _StatusRow(
              label: 'Status',
              value: 'No active membership',
              valueColor: AppColors.mutedOliveText,
            )
          else ...<Widget>[
            _StatusRow(
              label: 'Plan',
              value: membership.planTitle,
            ),
            _StatusRow(
              label: 'Status',
              value: _capitalize(membership.status),
              valueColor: AppColors.brandGold,
            ),
            if (membership.startsAt != null)
              _StatusRow(
                label: 'Started',
                value: _formatDate(membership.startsAt),
              ),
            if (membership.endsAt != null)
              _StatusRow(
                label: 'Renews / Expires',
                value: _formatDate(membership.endsAt),
              ),
          ],
        ],
      ),
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '—';
    final DateTime? parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHistoryNote extends StatelessWidget {
  const _OrderHistoryNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Order History',
            style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Full order history will be available once the backend order list API is connected.',
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              color: AppColors.mutedOliveText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
