import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/widgets/back_nav_header.dart';
import 'application/membership_providers.dart';
import 'application/membership_state.dart';
import 'domain/manual_tx_hint.dart';
import 'domain/membership_order.dart';
import 'domain/membership_status.dart';

class MembershipOrdersPage extends ConsumerWidget {
  const MembershipOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MembershipState state = ref.watch(membershipControllerProvider);
    final AsyncValue<List<MembershipOrder>> orders =
        ref.watch(membershipOrdersListProvider);
    final AsyncValue<List<ManualTxHint>> hints = ref.watch(txHintsProvider);

    void refresh() {
      ref.invalidate(membershipOrdersListProvider);
      ref.invalidate(txHintsProvider);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            BackNavHeader(
              title: 'Membership & Orders',
              trailing: IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.mutedOliveText,
                onPressed: refresh,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _MembershipStatusCard(state: state),
            const SizedBox(height: AppSpacing.md),
            _OrdersSection(orders: orders, onRefresh: refresh),
            const SizedBox(height: AppSpacing.md),
            _TxHintsSection(hints: hints, onRefresh: refresh),
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
// Orders section — all membership orders (platform asset + chain)
// ---------------------------------------------------------------------------

class _OrdersSection extends StatelessWidget {
  const _OrdersSection({required this.orders, required this.onRefresh});

  final AsyncValue<List<MembershipOrder>> orders;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Order History',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.xs),
        orders.when(
          loading: () => const _LoadingCard(),
          error: (_, __) => _ErrorCard(onRetry: onRefresh),
          data: (List<MembershipOrder> items) {
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border.all(color: AppColors.softBorder),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  'No orders yet.',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: AppColors.mutedOliveText,
                  ),
                ),
              );
            }
            return Column(
              children: <Widget>[
                for (final MembershipOrder order in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _OrderCard(order: order),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final MembershipOrder order;

  @override
  Widget build(BuildContext context) {
    final String normalizedStatus = order.status.toLowerCase().trim();
    final bool isPaid = order.isSuccessLike;
    final bool isPending = order.isPending;

    final Color statusColor = isPaid
        ? AppColors.brandGold
        : isPending
            ? AppColors.mutedOliveText
            : Colors.redAccent;

    final String statusLabel = switch (normalizedStatus) {
      'paid'             => 'Paid',
      'pending'          => 'Pending',
      'created'          => 'Pending',
      'awaiting_payment' => 'Awaiting',
      'expired'          => 'Expired',
      'underpaid'        => 'Underpaid',
      'overpaid'         => 'Paid',
      'paid_after_expiry'=> 'Paid',
      'cancelled'        => 'Cancelled',
      _                  => _capitalize(order.status),
    };

    final String? amountLine = _buildAmountLine();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
          color: isPaid
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
                  order.planTitle ?? order.planCode ?? order.orderNo,
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
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
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
          if (amountLine != null)
            _OrderRow(label: 'Amount', value: amountLine),
          _OrderRow(
            label: 'Order',
            value: order.orderNo.length > 20
                ? '${order.orderNo.substring(0, 10)}…${order.orderNo.substring(order.orderNo.length - 6)}'
                : order.orderNo,
          ),
          if (order.createdAt != null)
            _OrderRow(label: 'Date', value: _formatDate(order.createdAt!)),
        ],
      ),
    );
  }

  String? _buildAmountLine() {
    // Prefer display_payment_amount / display_payment_asset from the backend.
    if (order.displayPaymentAmount != null) {
      final String amt = _formatAmount(order.displayPaymentAmount!);
      final String asset = _assetLabel(order.displayPaymentAsset);
      return '$amt $asset';
    }
    // Fallback: expected amount in token symbol.
    if (order.expectedAmountLbc != null) {
      final String amt = _formatAmount(order.expectedAmountLbc!);
      final String asset = order.tokenSymbol ?? order.currency ?? '';
      return asset.isNotEmpty ? '$amt $asset' : amt;
    }
    return null;
  }

  static String _assetLabel(String? raw) => switch (raw?.toLowerCase()) {
        'meow_points' => 'MeowPoints',
        'meow_credit' => 'MeowCredit',
        'thb_ltt'     => 'THB-LTT',
        null          => '',
        _             => raw!,
      };

  static String _formatAmount(String raw) {
    final double? v = double.tryParse(raw.trim());
    if (v == null) return raw.trim();
    return v
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 60,
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

// ---------------------------------------------------------------------------
// Tx hints section — THB-LTT manual chain payment submissions
// ---------------------------------------------------------------------------

class _TxHintsSection extends StatelessWidget {
  const _TxHintsSection({required this.hints, required this.onRefresh});

  final AsyncValue<List<ManualTxHint>> hints;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Chain Payment Submissions',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.xs),
        hints.when(
          loading: () => const _LoadingCard(),
          error: (_, __) => _ErrorCard(onRetry: onRefresh),
          data: (List<ManualTxHint> items) {
            if (items.isEmpty) return const _EmptyCard();
            return Column(
              children: <Widget>[
                for (final ManualTxHint hint in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TxHintCard(hint: hint),
                  ),
              ],
            );
          },
        ),
      ],
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
          _HintRow(label: 'Amount', value: '${hint.expectedAmountLbc} THB-LTT'),
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
