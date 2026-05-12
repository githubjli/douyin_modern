import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/meow_credit_repository.dart';
import 'meow_credit_recharge_page.dart';

/// Amount-input page — the user types how many credits to recharge,
/// then we create the order and open the Manual-Payment-style payment page.
class RechargePackagePage extends ConsumerStatefulWidget {
  const RechargePackagePage({super.key});

  @override
  ConsumerState<RechargePackagePage> createState() =>
      _RechargePackagePageState();
}

class _RechargePackagePageState extends ConsumerState<RechargePackagePage> {
  final TextEditingController _amountController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final String raw = _amountController.text.trim();
    final int? amount = int.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final order =
          await ref.read(meowCreditRepositoryProvider).createRecharge(amount);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MeowCreditRechargePage(
          requestedAmount: amount,
          order: order,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create recharge order.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Recharge Meow Credit',
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: Colors.white)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Amount input
              Text('Amount to Recharge',
                  style: AppTextStyles.body.copyWith(color: Colors.white)),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Eg, 100',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  suffixText: 'Credits',
                  suffixStyle: const TextStyle(
                      color: AppColors.brandGold,
                      fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide:
                        const BorderSide(color: AppColors.softBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide:
                        const BorderSide(color: AppColors.softBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.brandGold),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Notice
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.brandGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                      color: AppColors.brandGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Enter the number of credits you wish to purchase. '
                  'You will be shown the payment address and amount after confirming.',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.brandGold),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Confirm button
              GestureDetector(
                onTap: _creating ? null : _proceed,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: _creating
                        ? AppColors.brandGold.withValues(alpha: 0.5)
                        : AppColors.brandGold,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  alignment: Alignment.center,
                  child: _creating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          'Proceed to Payment',
                          style: AppTextStyles.body.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
