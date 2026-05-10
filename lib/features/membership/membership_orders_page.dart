import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import 'application/membership_providers.dart';
import 'application/membership_state.dart';
import 'data/remote_manual_membership_repository.dart';
import 'domain/manual_membership_repository.dart';
import 'domain/manual_tx_hint.dart';
import 'domain/membership_status.dart';

class MembershipOrdersPage extends ConsumerStatefulWidget {
  const MembershipOrdersPage({super.key, this.manualRepository});

  final ManualMembershipRepository? manualRepository;

  @override
  ConsumerState<MembershipOrdersPage> createState() =>
      _MembershipOrdersPageState();
}

class _MembershipOrdersPageState extends ConsumerState<MembershipOrdersPage> {
  late ManualMembershipRepository _repository;
  late Future<List<ManualTxHint>> _hintsFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.manualRepository ??
        RemoteManualMembershipRepository(apiClient: ApiClient());
    _hintsFuture = _repository.getTxHints();
  }

  void _refresh() {
    setState(() {
      _hintsFuture = _repository.getTxHints();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.brandGold),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            _MembershipStatusCard(state: state),
            const SizedBox(height: AppSpacing.md),
            _TxHintsSection(future: _hintsFuture, onRefresh: _refresh),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Membership status card (from Riverpod provider)
// ---------------------------------------------------------------------------

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
            _StatusRow(label: 'Plan', value: membership.planTitle),
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

// ---------------------------------------------------------------------------
// Tx hints section — live list from the API
// ---------------------------------------------------------------------------

class _TxHintsSection extends StatelessWidget {
  const _TxHintsSection({required this.future, required this.onRefresh});

  final Future<List<ManualTxHint>> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ManualTxHint>>(
      future: future,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<ManualTxHint>> snapshot,
      ) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Payment History',
              style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (snapshot.connectionState == ConnectionState.waiting)
              const _LoadingCard()
            else if (snapshot.hasError)
              _ErrorCard(onRetry: onRefresh)
            else if (snapshot.data == null || snapshot.data!.isEmpty)
              const _EmptyCard()
            else
              for (final ManualTxHint hint in snapshot.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _TxHintCard(hint: hint),
                ),
          ],
        );
      },
    );
  }
}

class _TxHintCard extends StatelessWidget {
  const _TxHintCard({required this.hint});

  final ManualTxHint hint;

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = hint.status.isSuccess;
    final Color statusColor = isSuccess
        ? AppColors.brandGold
        : hint.status == ManualTxHintStatus.rejected
            ? Colors.redAccent
            : AppColors.mutedOliveText;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
          color: isSuccess
              ? AppColors.brandGold.withValues(alpha: 0.45)
              : AppColors.softBorder,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hint.planName,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hint.status.displayLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          _HintRow(label: 'Amount', value: '${hint.expectedAmountLbc} LBC'),
          _HintRow(
            label: 'TX ID',
            value: hint.txid.length > 24
                ? '${hint.txid.substring(0, 12)}…${hint.txid.substring(hint.txid.length - 8)}'
                : hint.txid,
          ),
          _HintRow(label: 'Submitted', value: _formatDate(hint.createdAt)),
          if (hint.confirmations > 0)
            _HintRow(
              label: 'Confirmations',
              value: hint.confirmations.toString(),
            ),
          if (hint.rejectReason != null && hint.rejectReason!.isNotEmpty)
            _HintRow(label: 'Reason', value: hint.rejectReason!),
        ],
      ),
    );
  }

  static String _formatDate(String rawDate) {
    final DateTime? parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

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
        children: <Widget>[
          Text(
            'Could not load payment history.',
            style: AppTextStyles.body.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        'No payment submissions yet.',
        style: AppTextStyles.body.copyWith(
          fontSize: 12,
          color: AppColors.mutedOliveText,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

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
