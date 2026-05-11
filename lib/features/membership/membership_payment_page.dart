import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'application/payment_page_notifier.dart';
import 'domain/membership_order.dart';
import 'domain/membership_plan.dart';
import 'domain/membership_repository.dart';

typedef QrCodeSaver = Future<bool> Function(GlobalKey qrKey);

/// Outer widget — injects page-scoped [paymentPageProvider] via [ProviderScope].
class MembershipPaymentPage extends StatelessWidget {
  const MembershipPaymentPage({
    super.key,
    required this.order,
    required this.selectedPlan,
    required this.repository,
    this.qrCodeSaver,
  });

  final MembershipOrder order;
  final MembershipPlan selectedPlan;
  final MembershipRepository repository;
  final QrCodeSaver? qrCodeSaver;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        paymentPageProvider.overrideWith(
          (ref) => PaymentPageNotifier(
            initialOrder: order,
            repository: repository,
          ),
        ),
      ],
      child: _PaymentBody(
        selectedPlan: selectedPlan,
        qrCodeSaver: qrCodeSaver,
      ),
    );
  }
}

/// Inner widget — owns [Timer] lifecycle; all mutable state lives in [paymentPageProvider].
class _PaymentBody extends ConsumerStatefulWidget {
  const _PaymentBody({required this.selectedPlan, this.qrCodeSaver});

  final MembershipPlan selectedPlan;
  final QrCodeSaver? qrCodeSaver;

  @override
  ConsumerState<_PaymentBody> createState() => _PaymentBodyState();
}

class _PaymentBodyState extends ConsumerState<_PaymentBody> {
  final GlobalKey _qrKey = GlobalKey();
  final TextEditingController _txHashController = TextEditingController();
  Timer? _countdownTimer;
  Timer? _pollTimer;

  static const Duration _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    // Defer to post-frame: Riverpod forbids modifying providers during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startCountdown();
    });
  }

  @override
  void dispose() {
    _txHashController.dispose();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ---------- countdown ----------

  void _startCountdown() {
    final String? expiresAt =
        ref.read(paymentPageProvider).currentOrder.expiresAt;
    if (expiresAt == null) return;
    final DateTime? expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return;

    void tick() {
      if (!mounted) return;
      final Duration remaining = expiry.difference(DateTime.now());
      ref
          .read(paymentPageProvider.notifier)
          .tick(remaining.isNegative ? Duration.zero : remaining);
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // ---------- polling ----------

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOrder());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollOrder() async {
    if (!mounted) return;
    final bool done =
        await ref.read(paymentPageProvider.notifier).pollOrder();
    if (done) {
      _stopPolling();
      _countdownTimer?.cancel();
    }
  }

  // ---------- actions ----------

  Future<void> _verifyNow() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool success =
        await ref.read(paymentPageProvider.notifier).verifyNow();
    if (!mounted) return;
    if (success) {
      _stopPolling();
      _countdownTimer?.cancel();
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Verification failed. Please try again.')),
      );
    }
  }

  Future<void> _copyAddress() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? address =
        _trimmed(ref.read(paymentPageProvider).currentOrder.payToAddress);
    if (address == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Payment address unavailable')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Address copied')));
  }

  Future<void> _saveQrCode() async {
    final PaymentPageState pageState = ref.read(paymentPageProvider);
    if (pageState.savingQr ||
        _paymentQrPayload(pageState.currentOrder) == null) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    ref.read(paymentPageProvider.notifier).setSavingQr(value: true);
    try {
      final bool saved =
          await (widget.qrCodeSaver ?? _writeQrPng)(_qrKey);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(saved ? 'QR saved' : 'Unable to save QR. Please try again.'),
      ));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save QR. Please try again.')),
      );
    } finally {
      if (mounted) ref.read(paymentPageProvider.notifier).setSavingQr(value: false);
    }
  }

  Future<void> _submitTransactionHash() async {
    final String txHash = _txHashController.text.trim();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (txHash.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter transaction hash.')),
      );
      return;
    }
    final PaymentPageState pageState = ref.read(paymentPageProvider);
    final bool success =
        await ref.read(paymentPageProvider.notifier).submitTxHint(
          orderNo: pageState.currentOrder.orderNo,
          txid: txHash,
        );
    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Transaction hash submitted. Awaiting confirmation.'),
      ));
      _startPolling();
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Unable to submit transaction hash. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final PaymentPageState pageState = ref.watch(paymentPageProvider);
    final MembershipOrder order = pageState.currentOrder;
    final MembershipPlan selectedPlan = widget.selectedPlan;
    final bool paid = pageState.isPaid;
    final String? qrPayload = _paymentQrPayload(order);
    final String tokenSymbol =
        _selectedPlanTokenSymbol(selectedPlan, order);
    final bool expired = order.isExpired ||
        (pageState.remaining == Duration.zero &&
            order.expiresAt != null &&
            !paid);

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
              _SelectedPlanCard(
                selectedPlan: selectedPlan,
                tokenSymbol: tokenSymbol,
              ),
              const SizedBox(height: AppSpacing.md),
              if (paid)
                _PaymentSuccessCard(planTitle: selectedPlan.title)
              else ...<Widget>[
                if (order.expiresAt != null)
                  _CountdownBanner(
                    remaining: pageState.remaining,
                    expired: expired,
                  ),
                if (order.expiresAt != null) const SizedBox(height: AppSpacing.sm),
                _QrPaymentSection(
                  qrKey: _qrKey,
                  qrPayload: qrPayload,
                  canSave: qrPayload != null && !pageState.savingQr,
                  saving: pageState.savingQr,
                  onSave: _saveQrCode,
                ),
                const SizedBox(height: AppSpacing.md),
                _ReceivingAddressCard(
                  address: order.payToAddress,
                  onCopy: _copyAddress,
                ),
                const SizedBox(height: AppSpacing.sm),
                _WarningCard(tokenSymbol: tokenSymbol),
                const SizedBox(height: AppSpacing.md),
                _TransactionHashSection(
                  controller: _txHashController,
                  submitting: pageState.submittingTx,
                  onSubmit: _submitTransactionHash,
                ),
                if (pageState.txSubmitted) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _VerifyNowSection(
                    verifying: pageState.verifyingNow,
                    onVerify: _verifyNow,
                  ),
                ],
              ],
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
        Tooltip(
          message: 'Back',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
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
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Membership Purchase',
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

class _SelectedPlanCard extends StatelessWidget {
  const _SelectedPlanCard({
    required this.selectedPlan,
    required this.tokenSymbol,
  });

  final MembershipPlan selectedPlan;
  final String tokenSymbol;

  @override
  Widget build(BuildContext context) {
    final String amount = _selectedPlanDisplayAmount(selectedPlan);
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
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.38)),
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
                  selectedPlan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _durationLabel(selectedPlan),
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                amount,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                tokenSymbol,
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
}

class _QrPaymentSection extends StatelessWidget {
  const _QrPaymentSection({
    required this.qrKey,
    required this.qrPayload,
    required this.canSave,
    required this.saving,
    required this.onSave,
  });

  final GlobalKey qrKey;
  final String? qrPayload;
  final bool canSave;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final String? payload = qrPayload;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Complete the Payment',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (payload == null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warmBackground,
                border: Border.all(color: AppColors.softBorder),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                'Payment address unavailable',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
            )
          else
            Center(
              child: _QrCapture(
                key: qrKey,
                child: RepaintBoundary(
                  key: const ValueKey<String>(
                    'membership-payment-qr-boundary',
                  ),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 176,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.center,
            child: _SecondaryGoldButton(
              icon: saving
                  ? Icons.hourglass_top_rounded
                  : Icons.file_download_outlined,
              label: saving ? 'Saving...' : 'Download QR Code',
              onTap: canSave ? onSave : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCapture extends StatelessWidget {
  const _QrCapture({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _ReceivingAddressCard extends StatelessWidget {
  const _ReceivingAddressCard({required this.address, required this.onCopy});

  final String? address;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final String addressLabel = _paymentValue(
      address,
      'Payment address unavailable',
    );
    final bool hasAddress = _trimmed(address) != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Receiving Address',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.warmBackground,
              border: Border.all(color: AppColors.softBorder),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(
                    addressLabel,
                    softWrap: true,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: 'Copy address',
                  child: _IconGoldButton(
                    icon: Icons.content_copy_rounded,
                    onTap: hasAddress ? onCopy : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.tokenSymbol});

  final String tokenSymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        'Please transfer funds using $tokenSymbol only. Other currencies may be lost.',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.brandGold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TransactionHashSection extends StatelessWidget {
  const _TransactionHashSection({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Transaction Hash (Confirmation)',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            style: AppTextStyles.body.copyWith(fontSize: 12),
            cursorColor: AppColors.brandGold,
            decoration: InputDecoration(
              hintText: 'Eg, b10608a77dd4bbe597a15803c3e96...',
              hintStyle: AppTextStyles.caption.copyWith(fontSize: 12),
              filled: true,
              fillColor: AppColors.warmBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: const BorderSide(color: AppColors.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide(
                  color: AppColors.brandGold.withValues(alpha: 0.58),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _GoldButton(
            label: submitting ? 'Submitting...' : 'Submit',
            onTap: submitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _SecondaryGoldButton extends StatelessWidget {
  const _SecondaryGoldButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.46 : 1,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warmBackground,
            border: Border.all(
              color: AppColors.brandGold.withValues(alpha: 0.46),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.brandGold),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconGoldButton extends StatelessWidget {
  const _IconGoldButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.46 : 1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.brandGold.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.brandGold.withValues(alpha: 0.55),
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: 15, color: AppColors.brandGold),
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.46 : 1,
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
      ),
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.remaining, required this.expired});

  final Duration remaining;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final String label = expired
        ? 'Order expired'
        : 'Expires in ${_formatDuration(remaining)}';
    final Color color =
        expired ? Colors.redAccent : AppColors.brandGold;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.40)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            expired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

class _PaymentSuccessCard extends StatelessWidget {
  const _PaymentSuccessCard({required this.planTitle});

  final String planTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.brandGold,
            size: 52,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Payment Confirmed',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$planTitle membership is now active.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          _GoldButton(
            label: 'Done',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _VerifyNowSection extends StatelessWidget {
  const _VerifyNowSection({
    required this.verifying,
    required this.onVerify,
  });

  final bool verifying;
  final VoidCallback onVerify;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Already Transferred?',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'If you have completed the transfer, tap below to trigger an immediate check.',
            style: AppTextStyles.body.copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SecondaryGoldButton(
            icon: verifying
                ? Icons.hourglass_top_rounded
                : Icons.verified_outlined,
            label: verifying ? 'Checking...' : 'Check Payment Now',
            onTap: verifying ? null : onVerify,
          ),
        ],
      ),
    );
  }
}

Future<bool> _writeQrPng(GlobalKey qrKey) async {
  final BuildContext? context = qrKey.currentContext;
  if (context == null) return false;
  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) return false;

  final ui.Image image = await renderObject.toImage(pixelRatio: 3);
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  final Uint8List? pngBytes = byteData?.buffer.asUint8List();
  if (pngBytes == null || pngBytes.isEmpty) return false;

  final Directory dir = await getApplicationDocumentsDirectory();
  final String filePath = '${dir.path}'
      '/membership_payment_qr_${DateTime.now().millisecondsSinceEpoch}.png';
  final File file = File(filePath);
  await file.writeAsBytes(pngBytes, flush: true);
  return true;
}

String _selectedPlanDisplayAmount(MembershipPlan selectedPlan) {
  final RegExpMatch? amountMatch = RegExp(
    r'\d+(?:\.\d+)?',
  ).firstMatch(selectedPlan.price);
  final String? rawAmount = amountMatch?.group(0);
  if (rawAmount == null) return 'Amount unavailable';
  final double? numericAmount = double.tryParse(rawAmount);
  if (numericAmount == null) return rawAmount;
  return numericAmount.toStringAsFixed(2);
}

String _selectedPlanTokenSymbol(
  MembershipPlan selectedPlan,
  MembershipOrder order,
) {
  return _trimmed(selectedPlan.settlementTokenSymbol) ??
      _trimmed(order.tokenSymbol) ??
      _trimmed(order.currency) ??
      'LBC';
}

String _durationLabel(MembershipPlan? plan) {
  final int? durationDays = plan?.durationDays;
  if (durationDays == null || durationDays <= 0) return 'Duration unavailable';
  return 'Duration: $durationDays days';
}

String? _paymentQrPayload(MembershipOrder order) {
  final String? address = _trimmed(order.payToAddress);
  if (address == null) return null;
  return _trimmed(order.paymentUri) ?? _trimmed(order.qrPayload) ?? address;
}

String _paymentValue(String? value, String fallback) {
  return _trimmed(value) ?? fallback;
}

String? _trimmed(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
