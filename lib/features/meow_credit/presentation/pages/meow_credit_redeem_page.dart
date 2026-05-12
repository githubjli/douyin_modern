import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/widgets/back_nav_header.dart';
import '../../application/meow_credit_providers.dart';
import '../../data/meow_credit_repository.dart';

class MeowCreditRedeemPage extends ConsumerStatefulWidget {
  const MeowCreditRedeemPage({super.key, required this.balance});
  final int balance;

  @override
  ConsumerState<MeowCreditRedeemPage> createState() =>
      _MeowCreditRedeemPageState();
}

class _MeowCreditRedeemPageState
    extends ConsumerState<MeowCreditRedeemPage> {
  // KYC status: null = loading, true = verified, false = not verified
  // For now we read from wallet response; backend can add `kyc_verified` field.
  // Treat as not verified by default so the guard is shown.
  // ignore: prefer_final_fields — will be mutated when backend adds kyc_verified
  bool _kycVerified = false;
  bool _kycLoading = true;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkKyc();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _checkKyc() async {
    // KYC status will come from the backend (e.g. wallet.kycVerified field).
    // Until that field is added, show the KYC overlay by default.
    try {
      await ref.read(meowCreditRepositoryProvider).getWallet();
      // TODO: set _kycVerified = wallet.kycVerified when backend adds field.
      if (mounted) setState(() => _kycLoading = false);
    } catch (_) {
      if (mounted) setState(() => _kycLoading = false);
    }
  }

  Future<void> _submit() async {
    final amountStr = _amountController.text.trim();
    final address = _addressController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    final int? amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount.')));
      return;
    }
    if (amount > widget.balance) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Amount exceeds your balance.')));
      return;
    }
    if (address.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please enter a receiving address.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(meowCreditRepositoryProvider).createRedeem(
            amount: amount,
            receivingAddress: address,
          );
      if (!mounted) return;
      ref.invalidate(meowCreditWalletProvider);
      ref.invalidate(meowCreditLedgerProvider);
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Redemption request submitted. We will process it within 1–2 business days.'),
        backgroundColor: Colors.green,
      ));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
          content: Text('Unable to submit request. Please try again.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Main content (blurred when KYC not verified)
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const BackNavHeader(title: 'Redeem Meow Credit'),
                  const SizedBox(height: AppSpacing.lg),

                  // Balance card
                  _BalanceMini(balance: widget.balance),
                  const SizedBox(height: AppSpacing.lg),

                  // Amount field
                  Text('Amount to Redeem',
                      style: AppTextStyles.body.copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  _InputField(
                    controller: _amountController,
                    hint: 'Eg, 10',
                    keyboardType: TextInputType.number,
                    enabled: _kycVerified && !_submitting,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Address field
                  Text('Receiving Address',
                      style: AppTextStyles.body.copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  _InputField(
                    controller: _addressController,
                    hint: 'Eg, b10608a77dd4bbe597a15803c3e96...',
                    enabled: _kycVerified && !_submitting,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Address warning
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.brandGold, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Please make sure that the receiving address is in '
                            'THB-LTT only. Receiving with other wallet may '
                            'result in the loss of funds.',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Submit button
                  GestureDetector(
                    onTap: (_kycVerified && !_submitting) ? _submit : null,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: _kycVerified
                            ? AppColors.brandGold
                            : AppColors.brandGold.withValues(alpha: 0.4),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                      alignment: Alignment.center,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : Text('Submit Redeem Request',
                              style: AppTextStyles.body.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // How to redeem
                  _HowToRedeem(),
                ],
              ),
            ),

            // KYC overlay
            if (!_kycLoading && !_kycVerified)
              _KycOverlay(
                onVerifyTap: () {
                  // TODO: navigate to KYC verification page when available
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'KYC verification coming soon.')),
                  );
                },
              ),
            if (_kycLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.brandGold),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _BalanceMini extends StatelessWidget {
  const _BalanceMini({required this.balance});
  final int balance;

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
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.brandGold,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('M',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Current Balance',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.brandGold)),
              Text('$balance',
                  style: AppTextStyles.sectionTitle
                      .copyWith(color: Colors.white, fontSize: 26)),
              Text('CREDITS',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.softBorder),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide:
              BorderSide(color: AppColors.softBorder.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

class _HowToRedeem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = <String>[
      'Enter the amount you wish to redeem.',
      'Enter the receiving address from your LTT Wallet to receive THB-LTT.',
      'Press on Submit Redeem Request to submit your redemption request.',
      'Once the request has been approved by the administrator, the funds will be sent to your specified receiving address.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('How to Redeem Meow Credit',
            style: AppTextStyles.body
                .copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Meow Credit can be redeemed to THB-LTT. User are required to '
          'complete the KYC for redeem before proceed.',
          style: AppTextStyles.caption.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...steps.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.brandGold),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${e.key + 1}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.brandGold)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(e.value,
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.white70)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _KycOverlay extends StatelessWidget {
  const _KycOverlay({required this.onVerifyTap});
  final VoidCallback onVerifyTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 80, left: AppSpacing.lg,
            right: AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'KYC is required for Redemption',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Please verify your identity to enable\nMeow Credit Redemption',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  onPressed: onVerifyTap,
                  child: Text('Verify Identity',
                      style: AppTextStyles.body.copyWith(
                          color: Colors.black, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
