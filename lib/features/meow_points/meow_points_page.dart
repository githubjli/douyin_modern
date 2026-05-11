import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import 'domain/meow_point_wallet.dart';

class MeowPointsPage extends StatefulWidget {
  const MeowPointsPage({
    super.key,
    required this.apiClient,
    this.initialWallet,
  });

  final ApiClient apiClient;
  final MeowPointWallet? initialWallet;

  @override
  State<MeowPointsPage> createState() => _MeowPointsPageState();
}

class _MeowPointsPageState extends State<MeowPointsPage> {
  MeowPointWallet? _wallet;
  bool _loading = false;
  String? _error;
  bool _claimingReward = false;

  @override
  void initState() {
    super.initState();
    _wallet = widget.initialWallet;
    if (_wallet == null) {
      _loadWallet();
    }
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.get<dynamic>(
        Endpoints.meowPointsWallet,
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic> && mounted) {
        setState(() {
          _wallet = MeowPointWallet.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load wallet.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _claimDailyReward() async {
    if (_claimingReward) return;
    setState(() => _claimingReward = true);
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.meowPointsDailyReward,
        authenticated: true,
      );
      final dynamic data = response.data;
      if (!mounted) return;
      final bool granted = data is Map<String, dynamic>
          ? data['granted'] == true
          : false;
      final int amount = data is Map<String, dynamic>
          ? (data['points_amount'] as num?)?.toInt() ?? 0
          : 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? '+$amount Meow Points — daily reward claimed!'
                : 'Daily reward already claimed today.',
          ),
        ),
      );
      // Refresh wallet to reflect new balance
      if (granted) await _loadWallet();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to claim reward.')),
        );
      }
    } finally {
      if (mounted) setState(() => _claimingReward = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MeowPointWallet? w = _wallet;

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandGold,
          onRefresh: _loadWallet,
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
                // Header
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
                      onPressed: _loadWallet,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Balance hero card
                _BalanceCard(wallet: w, loading: _loading, error: _error),
                const SizedBox(height: AppSpacing.md),

                // Daily reward
                _DailyRewardCard(
                  claiming: _claimingReward,
                  onClaim: _claimDailyReward,
                ),
                const SizedBox(height: AppSpacing.md),

                // Stats breakdown
                if (w != null) ...<Widget>[
                  _StatsCard(wallet: w),
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
