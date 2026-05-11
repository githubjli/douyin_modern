import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/endpoints.dart';
import '../../features/auth/application/auth_providers.dart';
import 'application/meow_points_providers.dart';
import 'domain/meow_point_wallet.dart';

class MeowPointsPage extends ConsumerWidget {
  const MeowPointsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MeowPointWallet> walletAsync =
        ref.watch(meowPointsWalletProvider);
    final bool claiming = ref.watch(claimingRewardProvider);

    Future<void> claimDailyReward() async {
      if (ref.read(claimingRewardProvider)) return;
      // Capture messenger before await to avoid using context across async gaps.
      final ScaffoldMessengerState messenger =
          ScaffoldMessenger.of(context);
      ref.read(claimingRewardProvider.notifier).state = true;
      try {
        final response = await ref.read(apiClientProvider).post<dynamic>(
          Endpoints.meowPointsDailyReward,
          authenticated: true,
        );
        final dynamic data = response.data;
        final bool granted =
            data is Map<String, dynamic> ? data['granted'] == true : false;
        final int amount = data is Map<String, dynamic>
            ? (data['points_amount'] as num?)?.toInt() ?? 0
            : 0;
        messenger.showSnackBar(SnackBar(
          content: Text(
            granted
                ? '+$amount Meow Points — daily reward claimed!'
                : 'Daily reward already claimed today.',
          ),
        ));
        if (granted) ref.invalidate(meowPointsWalletProvider);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to claim reward.')),
        );
      } finally {
        ref.read(claimingRewardProvider.notifier).state = false;
      }
    }

    final MeowPointWallet? wallet = walletAsync.valueOrNull;
    final bool loading = walletAsync.isLoading;
    final String? error = walletAsync.hasError ? 'Unable to load wallet.' : null;

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandGold,
          onRefresh: () async => ref.invalidate(meowPointsWalletProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground.withValues(alpha: 0.54),
                            border: Border.all(color: AppColors.softBorder),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.brandGold,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Meow Points',
                        style: AppTextStyles.sectionTitle.copyWith(
                          fontSize: 18,
                          height: 1.1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: AppColors.mutedOliveText,
                      onPressed: () => ref.invalidate(meowPointsWalletProvider),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _BalanceCard(wallet: wallet, loading: loading, error: error),
                const SizedBox(height: AppSpacing.md),
                _DailyRewardCard(
                  claiming: claiming,
                  onClaim: claimDailyReward,
                ),
                const SizedBox(height: AppSpacing.md),
                if (wallet != null) ...<Widget>[
                  _StatsCard(wallet: wallet),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance hero card
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.wallet,
    required this.loading,
    required this.error,
  });

  final MeowPointWallet? wallet;
  final bool loading;
  final String? error;

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
                  color: AppColors.brandGold.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
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
          if (loading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandGold,
                ),
              ),
            )
          else if (error != null)
            Text(
              error!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
              ),
            )
          else ...<Widget>[
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
              'pts',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily reward card
// ---------------------------------------------------------------------------

class _DailyRewardCard extends StatelessWidget {
  const _DailyRewardCard({
    required this.claiming,
    required this.onClaim,
  });

  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandGold.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.brandGold,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Daily Login Reward', style: AppTextStyles.body),
                Text(
                  '+10 pts per day',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.mutedOliveText,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: claiming ? null : onClaim,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandGold,
              side: const BorderSide(color: AppColors.brandGold),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
            ),
            child: claiming
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandGold,
                    ),
                  )
                : const Text('Claim'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats breakdown card
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.wallet});
  final MeowPointWallet wallet;

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
          Text(
            'BREAKDOWN',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatRow(label: 'Total Earned', value: wallet.totalEarned),
          const Divider(height: 1, color: AppColors.softBorder),
          _StatRow(label: 'Total Spent', value: wallet.totalSpent),
          const Divider(height: 1, color: AppColors.softBorder),
          _StatRow(label: 'Purchased', value: wallet.totalPurchased),
          const Divider(height: 1, color: AppColors.softBorder),
          _StatRow(label: 'Bonus', value: wallet.totalBonus),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppTextStyles.body),
          Text(
            '$value pts',
            style: AppTextStyles.body.copyWith(
              color: AppColors.brandGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
