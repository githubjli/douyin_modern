import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/widgets/back_nav_header.dart';
import '../../app/widgets/gold_button.dart';
import 'domain/membership_order.dart';
import 'domain/membership_repository.dart';

enum _PageState { idle, loading, success, error }

class PlatformAssetPaymentPage extends StatefulWidget {
  const PlatformAssetPaymentPage({
    super.key,
    required this.planCode,
    required this.planName,
    required this.planPrice,
    required this.planCurrency,
    required this.paymentAsset,
    required this.repository,
    this.onSuccess,
  });

  final String planCode;
  final String planName;
  final String planPrice;
  final String planCurrency;
  /// Raw API value: 'meow_points' or 'meow_credit'.
  final String paymentAsset;
  final MembershipRepository repository;
  final VoidCallback? onSuccess;

  @override
  State<PlatformAssetPaymentPage> createState() =>
      _PlatformAssetPaymentPageState();
}

class _PlatformAssetPaymentPageState extends State<PlatformAssetPaymentPage> {
  _PageState _state = _PageState.idle;
  String? _errorMessage;
  MembershipOrder? _order;

  String get _assetLabel => switch (widget.paymentAsset) {
        'meow_points' => 'MeowPoints',
        'meow_credit' => 'MeowCredit',
        _ => widget.paymentAsset,
      };

  String get _pageTitle => 'Pay with $_assetLabel';

  Future<void> _confirmPayment() async {
    if (_state == _PageState.loading) return;
    setState(() {
      _state = _PageState.loading;
      _errorMessage = null;
    });
    try {
      final MembershipOrder order = await widget.repository.createOrder(
        planCode: widget.planCode,
        paymentAsset: widget.paymentAsset,
      );
      if (!mounted) return;
      if (order.isSuccessLike) {
        setState(() {
          _state = _PageState.success;
          _order = order;
        });
        widget.onSuccess?.call();
      } else {
        setState(() {
          _state = _PageState.error;
          _errorMessage = 'Payment was not completed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PageState.error;
        _errorMessage = _parseError(e);
      });
    }
  }

  String _parseError(Object e) {
    final String msg = e.toString().toLowerCase();
    if (msg.contains('insufficient') && msg.contains('meow_point')) {
      return 'Insufficient MeowPoints balance.';
    }
    if (msg.contains('insufficient') && msg.contains('meow_credit')) {
      return 'Insufficient MeowCredit balance.';
    }
    if (msg.contains('insufficient')) {
      return 'Insufficient $_assetLabel balance.';
    }
    return 'Payment failed. Please try again.';
  }

  void _onDone() {
    final NavigatorState nav = Navigator.of(context);
    nav.pop();
    if (nav.canPop()) nav.pop();
  }

  void _onRetry() {
    setState(() {
      _state = _PageState.idle;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BackNavHeader(title: _pageTitle),
              const SizedBox(height: AppSpacing.md),
              _PlanSummaryCard(
                planName: widget.planName,
                planPrice: widget.planPrice,
                planCurrency: widget.planCurrency,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_state == _PageState.success)
                _SuccessCard(
                  planName: _order?.planTitle ?? widget.planName,
                  endsAt: null,
                  onDone: _onDone,
                )
              else if (_state == _PageState.error)
                _ErrorCard(
                  message: _errorMessage ?? 'Payment failed.',
                  onRetry: _onRetry,
                )
              else ...<Widget>[
                _PaymentMethodCard(assetLabel: _assetLabel),
                const SizedBox(height: AppSpacing.md),
                GoldButton(
                  label: _state == _PageState.loading
                      ? 'Processing...'
                      : 'Confirm Payment',
                  onTap: _state == _PageState.loading ? null : _confirmPayment,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.planName,
    required this.planPrice,
    required this.planCurrency,
  });

  final String planName;
  final String planPrice;
  final String planCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
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
            color: AppColors.brandGold.withValues(alpha: 0.38)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Selected Plan',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brandGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _formatAmount(planPrice),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                planCurrency,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatAmount(String raw) {
    final double? v = double.tryParse(raw.trim());
    if (v == null) return raw.trim();
    return v
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({required this.assetLabel});

  final String assetLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandGold.withValues(alpha: 0.12),
              border: Border.all(
                  color: AppColors.brandGold.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 18,
              color: AppColors.brandGold,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  assetLabel,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your $assetLabel balance will be deducted upon confirmation.',
                  style:
                      AppTextStyles.caption.copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.planName,
    required this.onDone,
    this.endsAt,
  });

  final String planName;
  final String? endsAt;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final String? formattedEnd = _fmtDate(endsAt);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(
            color: AppColors.brandGold.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded,
              color: AppColors.brandGold, size: 52),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Purchase Successful',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$planName is now active.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          if (formattedEnd != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Valid until $formattedEnd',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.brandGold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          GoldButton(label: 'Done', onTap: onDone),
        ],
      ),
    );
  }

  static String? _fmtDate(String? raw) {
    if (raw == null) return null;
    final DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
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
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Payment Failed',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          GoldButton(label: 'Try Again', onTap: onRetry),
        ],
      ),
    );
  }
}
