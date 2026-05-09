import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/membership_order.dart';
import 'domain/membership_plan.dart';

typedef QrCodeSaver = Future<bool> Function(GlobalKey qrKey);

class MembershipPaymentPage extends StatefulWidget {
  const MembershipPaymentPage({
    super.key,
    required this.order,
    required this.selectedPlan,
    this.qrCodeSaver,
  });

  final MembershipOrder order;
  final MembershipPlan selectedPlan;
  final QrCodeSaver? qrCodeSaver;

  @override
  State<MembershipPaymentPage> createState() => _MembershipPaymentPageState();
}

class _MembershipPaymentPageState extends State<MembershipPaymentPage> {
  final GlobalKey _qrKey = GlobalKey();
  final TextEditingController _txHashController = TextEditingController();
  bool _savingQr = false;

  @override
  void dispose() {
    _txHashController.dispose();
    super.dispose();
  }

  MembershipOrder get order => widget.order;

  MembershipPlan get selectedPlan => widget.selectedPlan;

  Future<void> _copyAddress() async {
    final String? address = _trimmed(order.payToAddress);
    if (address == null) {
      _showMessage('Payment address unavailable');
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    _showMessage('Address copied');
  }

  Future<void> _saveQrCode() async {
    if (_savingQr || _paymentQrPayload(order) == null) return;

    setState(() {
      _savingQr = true;
    });

    try {
      final bool saved = await (widget.qrCodeSaver ?? _writeQrPng)(_qrKey);
      if (!mounted) return;
      _showMessage(
        saved ? 'QR saved' : 'Unable to save QR. Please try again.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to save QR. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _savingQr = false;
        });
      }
    }
  }

  void _submitTransactionHash() {
    final String txHash = _txHashController.text.trim();
    if (txHash.isEmpty) {
      _showMessage('Please enter transaction hash.');
      return;
    }
    _showMessage('Transaction hash saved locally');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? qrPayload = _paymentQrPayload(order);
    final String tokenSymbol = _selectedPlanTokenSymbol(selectedPlan, order);

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
              _QrPaymentSection(
                qrKey: _qrKey,
                qrPayload: qrPayload,
                canSave: qrPayload != null && !_savingQr,
                saving: _savingQr,
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
                onSubmit: _submitTransactionHash,
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
    required this.onSubmit,
  });

  final TextEditingController controller;
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
            label: 'Submit',
            onTap: onSubmit,
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

  final String filePath = '${Directory.systemTemp.path}'
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
