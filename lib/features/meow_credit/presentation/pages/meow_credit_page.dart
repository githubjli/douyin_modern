import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/widgets/back_nav_header.dart';
import '../../../../app/widgets/gold_button.dart';
import '../../../../app/widgets/gold_outline_button.dart';
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
                BackNavHeader(
                  title: 'Meow Credit',
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.mutedOliveText,
                    onPressed: () {
                      ref.invalidate(meowCreditWalletProvider);
                      ref.invalidate(meowCreditLedgerProvider);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Balance card ─────────────────────────────────────────
                walletAsync.when(
                  data: (w) => _BalanceCard(wallet: w),
                  loading: () => const _BalanceCard(wallet: null),
                  error: (_, __) => const _BalanceCard(wallet: null),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Action buttons ───────────────────────────────────────
                Row(
                  children: <Widget>[
                    GoldButton(
                      label: '+ Recharge',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RechargePackagePage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GoldOutlineButton(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Redeem',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MeowCreditRedeemPage(
                            balance: walletAsync.valueOrNull?.balance ?? 0,
                          ),
                        ),
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
                    style: AppTextStyles.body.copyWith(color: Colors.white)),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF4D3A22),
            Color(0xFF302820),
            AppColors.cardBackground,
          ],
        ),
        border: Border.all(
          color: AppColors.brandGold.withValues(alpha: 0.38),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_money_rounded,
                  color: AppColors.brandGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Current Balance',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            wallet != null ? '${wallet!.balance}' : '—',
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.brandGold,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'CREDITS',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
              letterSpacing: 0.6,
            ),
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
