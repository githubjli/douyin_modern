import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/membership_order.dart';
import 'domain/membership_plan.dart';

class MembershipPaymentPage extends StatelessWidget {
  const MembershipPaymentPage({
    super.key,
    required this.order,
    this.plan,
  });

  final MembershipOrder order;
  final MembershipPlan? plan;

  Future<void> _copyPaymentValue({
    required BuildContext context,
    required String? value,
    required String emptyMessage,
    required String copiedMessage,
  }) async {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _showMessage(context, emptyMessage);
      return;
    }
    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!context.mounted) return;
    _showMessage(context, copiedMessage);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String amountLabel = _paymentAmountLabel(order, plan);
    final String addressLabel = _paymentValue(
      order.payToAddress,
      'Payment address unavailable',
    );

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
              _PaymentHeader(onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: AppSpacing.md),
              _PaymentHeroCard(order: order, plan: plan),
              const SizedBox(height: AppSpacing.md),
              _PaymentDetailsCard(
                order: order,
                plan: plan,
                amountLabel: amountLabel,
                addressLabel: addressLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  _PaymentPillButton(
                    label: 'Copy amount',
                    icon: Icons.copy_rounded,
                    onTap: () => _copyPaymentValue(
                      context: context,
                      value: order.expectedAmountLbc,
                      emptyMessage: 'Amount unavailable',
                      copiedMessage: 'Amount copied',
                    ),
                  ),
                  _PaymentPillButton(
                    label: 'Copy address',
                    icon: Icons.content_copy_rounded,
                    onTap: () => _copyPaymentValue(
                      context: context,
                      value: order.payToAddress,
                      emptyMessage: 'Payment address unavailable',
                      copiedMessage: 'Address copied',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _GoldButton(
                label: 'Done',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBack,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.softBorder),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.brandGold,
                  size: 17,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Back',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brandGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Complete payment',
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 18,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentHeroCard extends StatelessWidget {
  const _PaymentHeroCard({required this.order, required this.plan});

  final MembershipOrder order;
  final MembershipPlan? plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF5A4324),
            Color(0xFF322A22),
            AppColors.cardBackground,
          ],
        ),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.46)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Complete payment',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _paymentPlanLabel(order, plan),
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Send the exact amount to the payment address before expiry.',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PaymentDetailsCard extends StatelessWidget {
  const _PaymentDetailsCard({
    required this.order,
    required this.plan,
    required this.amountLabel,
    required this.addressLabel,
  });

  final MembershipOrder order;
  final MembershipPlan? plan;
  final String amountLabel;
  final String addressLabel;

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
          _PaymentInfoRow(label: 'Plan', value: _paymentPlanLabel(order, plan)),
          _PaymentInfoRow(label: 'Order no', value: order.orderNo),
          _PaymentInfoRow(label: 'Status', value: order.status),
          _PaymentInfoRow(label: 'Amount', value: amountLabel),
          _PaymentInfoRow(
            label: 'Currency',
            value: _paymentCurrencyLabel(order, plan),
          ),
          _PaymentInfoRow(
            label: 'Pay to',
            value: addressLabel,
            wrapValueInBlock: true,
          ),
          _PaymentInfoRow(
            label: 'Expires',
            value: _paymentValue(order.expiresAt, 'No expiry provided'),
          ),
        ],
      ),
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({
    required this.label,
    required this.value,
    this.wrapValueInBlock = false,
  });

  final String label;
  final String value;
  final bool wrapValueInBlock;

  @override
  Widget build(BuildContext context) {
    final Widget valueText = Text(
      value,
      softWrap: true,
      style: AppTextStyles.body.copyWith(fontSize: 12, height: 1.25),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: wrapValueInBlock
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.warmBackground,
                      border: Border.all(color: AppColors.softBorder),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: valueText,
                  )
                : valueText,
          ),
        ],
      ),
    );
  }
}

class _PaymentPillButton extends StatelessWidget {
  const _PaymentPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.brandGold.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: AppColors.brandGold),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.brandGold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.brandGold,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.warmBackground,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

String _paymentPlanLabel(MembershipOrder order, MembershipPlan? plan) {
  final String? title = order.planTitle?.trim().isNotEmpty == true
      ? order.planTitle!.trim()
      : plan?.title.trim();
  final String? code = order.planCode?.trim().isNotEmpty == true
      ? order.planCode!.trim()
      : plan?.code?.trim();
  if (title != null && title.isNotEmpty && code != null && code.isNotEmpty) {
    return '$title ($code)';
  }
  if (title != null && title.isNotEmpty) return title;
  if (code != null && code.isNotEmpty) return code;
  return 'Plan unavailable';
}

String _paymentAmountLabel(MembershipOrder order, MembershipPlan? plan) {
  final String? amount = order.expectedAmountLbc?.trim();
  if (amount == null || amount.isEmpty) return 'Amount unavailable';
  final String currency = _paymentCurrencyLabel(order, plan);
  if (currency == 'Currency unavailable') return amount;
  return '$amount $currency';
}

String _paymentCurrencyLabel(MembershipOrder order, MembershipPlan? plan) {
  final String? currency = order.currency?.trim();
  if (currency != null && currency.isNotEmpty) return currency;
  final String? tokenSymbol = plan?.settlementTokenSymbol?.trim();
  if (tokenSymbol != null && tokenSymbol.isNotEmpty) return tokenSymbol;
  return 'Currency unavailable';
}

String _paymentValue(String? value, String fallback) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return fallback;
  return trimmed;
}
