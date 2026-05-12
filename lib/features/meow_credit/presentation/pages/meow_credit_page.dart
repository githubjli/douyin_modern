import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../application/meow_credit_providers.dart';
import '../../domain/meow_credit_wallet.dart';
import 'meow_credit_redeem_page.dart';
import 'recharge_package_page.dart';

class MeowCreditPage extends ConsumerWidget {
  const MeowCreditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(meowCreditWalletProvider);
    final ledgerAsync = ref.watch(meowCreditLedgerProvider);

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandGold,
          onRefresh: () async {
            ref.invalidate(meowCreditWalletProvider);
            ref.invalidate(meowCreditLedgerProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Meow Credit',
                        style: AppTextStyles.sectionTitle
                            .copyWith(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Balance card ─────────────────────────────────────────
                walletAsync.when(
                  data: (w) => _BalanceCard(wallet: w),
                  loading: () => const _BalanceCard(wallet: null),
                  error: (_, __) => const _BalanceCard(wallet: null),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Action buttons ───────────────────────────────────────
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ActionButton(
                        label: '+ Recharge',
                        filled: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RechargePackagePage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActionButton(
                        label: 'Redeem',
                        filled: false,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(
                          builder: (_) => MeowCreditRedeemPage(
                            balance: walletAsync.valueOrNull?.balance ?? 0,
                          ),
                        )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Overall stats ────────────────────────────────────────
                walletAsync.when(
                  data: (w) => _OverallCard(wallet: w),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Ledger ───────────────────────────────────────────────
                Text('Meow Credit History',
                    style: AppTextStyles.sectionTitle
                        .copyWith(color: Colors.white)),
                const SizedBox(height: AppSpacing.sm),
                ledgerAsync.when(
                  data: (entries) => entries.isEmpty
                      ? _emptyLedger()
                      : Column(
                          children: entries
                              .map((e) => _LedgerRow(entry: e))
                              .toList(),
                        ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(
                          color: AppColors.brandGold),
                    ),
                  ),
                  error: (_, __) => _emptyLedger(error: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyLedger({bool error = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          error ? 'Unable to load history.' : 'No transactions yet.',
          style: AppTextStyles.body.copyWith(color: Colors.white54),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance card
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});
  final MeowCreditWallet? wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.brandGold,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('M',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Current Balance',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.brandGold)),
              const SizedBox(height: 4),
              Text(
                wallet != null ? '${wallet!.balance}' : '--',
                style: AppTextStyles.sectionTitle
                    .copyWith(color: Colors.white, fontSize: 32),
              ),
              Text('CREDITS',
                  style:
                      AppTextStyles.caption.copyWith(color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overall stats card
// ---------------------------------------------------------------------------

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.wallet});
  final MeowCreditWallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Text('Overall',
                style:
                    AppTextStyles.body.copyWith(color: Colors.white)),
          ),
          _StatRow(
              label: 'Total Recharge', value: wallet.totalRecharged),
          const Divider(color: AppColors.softBorder, height: 1),
          _StatRow(label: 'Total Spent', value: wallet.totalSpent),
          const Divider(color: AppColors.softBorder, height: 1),
          _StatRow(label: 'Total Redeem', value: wallet.totalRedeemed),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label,
              style: AppTextStyles.body.copyWith(color: Colors.white70)),
          Text('$value crds',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.brandGold)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: filled ? AppColors.brandGold : Colors.transparent,
          border: Border.all(color: AppColors.brandGold),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: filled ? Colors.black : AppColors.brandGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ledger row
// ---------------------------------------------------------------------------

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});
  final MeowCreditLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(entry.status);
    final String typeLabel = _typeLabel(entry.entryType);
    final String amountStr =
        entry.isPositive ? '+${entry.amount}' : '${entry.amount}';
    final String dateStr = _formatDate(entry.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$dateStr • $typeLabel',
                  style:
                      AppTextStyles.caption.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 4),
                Text(
                  amountStr,
                  style: AppTextStyles.body.copyWith(
                    color: entry.isPositive ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(label: _statusLabel(entry.status), color: statusColor),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return AppColors.brandGold;
      case 'rejected':
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'recharge':
        return 'Recharge';
      case 'spend':
        return 'Spend';
      case 'redeem':
        return 'Redeem';
      case 'refund':
        return 'Refund';
      case 'adjust':
        return 'Adjustment';
      default:
        return type;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final DateTime? dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $h:$m';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        if (label == 'Rejected') ...<Widget>[
          const SizedBox(width: 4),
          Icon(Icons.info_outline, size: 14, color: color),
        ],
      ],
    );
  }
}
