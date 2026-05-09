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
    this.plan,
    this.qrCodeSaver,
  });

  final MembershipOrder order;
  final MembershipPlan? plan;
  final QrCodeSaver? qrCodeSaver;

  @override
  State<MembershipPaymentPage> createState() => _MembershipPaymentPageState();
}

class _MembershipPaymentPageState extends State<MembershipPaymentPage> {
  final GlobalKey _qrKey = GlobalKey();
  bool _savingQr = false;

  MembershipOrder get order => widget.order;

  MembershipPlan? get plan => widget.plan;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? qrPayload = _paymentQrPayload(order);
    final String tokenSymbol = _paymentTokenSymbol(order, plan);

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
                order: order,
                plan: plan,
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
              const SizedBox(height: AppSpacing.sm),
              _OrderDetailsFooter(order: order, tokenSymbol: tokenSymbol),
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
    required this.order,
    required this.plan,
    required this.tokenSymbol,
  });

  final MembershipOrder order;
  final MembershipPlan? plan;
  final String tokenSymbol;

  @override
  Widget build(BuildContext context) {
    final String amount = _paymentDisplayAmount(order);
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
                  _paymentPlanTitle(order, plan),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _durationLabel(plan),
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
          _GoldButton(
            label: saving ? 'Saving...' : 'Download QR Code',
            onTap: canSave ? onSave : null,
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

class _OrderDetailsFooter extends StatelessWidget {
  const _OrderDetailsFooter({
    required this.order,
    required this.tokenSymbol,
  });

  final MembershipOrder order;
  final String tokenSymbol;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xxs,
      children: <Widget>[
        Text(
          _paymentPlanLabel(order),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.mutedOliveText,
            fontSize: 11,
          ),
        ),
        _FooterText(label: 'Order', value: order.orderNo),
        Text(
          order.status,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.mutedOliveText,
            fontSize: 11,
          ),
        ),
        _FooterText(label: 'Status', value: order.status),
        Text(
          _paymentAmountLabel(order, tokenSymbol),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.mutedOliveText,
            fontSize: 11,
          ),
        ),
        _FooterText(
          label: 'Amount',
          value: _paymentAmountLabel(order, tokenSymbol),
        ),
        if (_trimmed(order.expiresAt) != null) ...<Widget>[
          Text(
            order.expiresAt!,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
              fontSize: 11,
            ),
          ),
          _FooterText(label: 'Expires', value: order.expiresAt!),
        ],
      ],
    );
  }
}

class _FooterText extends StatelessWidget {
  const _FooterText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: AppTextStyles.caption.copyWith(
        color: AppColors.mutedOliveText,
        fontSize: 11,
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

String _paymentPlanTitle(MembershipOrder order, MembershipPlan? plan) {
  final String? title = _trimmed(order.planTitle) ?? _trimmed(plan?.title);
  final String? code = _trimmed(order.planCode) ?? _trimmed(plan?.code);
  return title ?? code ?? 'Membership Plan';
}

String _paymentDisplayAmount(MembershipOrder order) {
  final String? rawAmount = _trimmed(order.expectedAmountLbc);
  if (rawAmount == null) return 'Amount unavailable';
  final double? numericAmount = double.tryParse(rawAmount);
  if (numericAmount == null) return rawAmount;
  return numericAmount.toStringAsFixed(2);
}

String _paymentPlanLabel(MembershipOrder order) {
  final String? title = _trimmed(order.planTitle);
  final String? code = _trimmed(order.planCode);
  if (title != null && code != null) return '$title ($code)';
  return title ?? code ?? 'Membership Plan';
}

String _paymentAmountLabel(MembershipOrder order, String tokenSymbol) {
  final String amount = _paymentDisplayAmount(order);
  if (amount == 'Amount unavailable') return amount;
  return '$amount $tokenSymbol';
}

String _paymentTokenSymbol(MembershipOrder order, MembershipPlan? plan) {
  return _trimmed(order.tokenSymbol) ??
      _trimmed(plan?.settlementTokenSymbol) ??
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
