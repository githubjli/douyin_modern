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

class MembershipPaymentPage extends StatefulWidget {
  const MembershipPaymentPage({
    super.key,
    required this.order,
    this.onDone,
    this.saveQrOverride,
  });

  static const Key qrSectionKey = ValueKey<String>('membership_payment_qr');
  static const Key qrBoundaryKey =
      ValueKey<String>('membership_payment_qr_boundary');
  static const Key qrQuietZoneKey =
      ValueKey<String>('membership_payment_qr_quiet_zone');

  final MembershipOrder order;
  final VoidCallback? onDone;
  final Future<void> Function()? saveQrOverride;

  @override
  State<MembershipPaymentPage> createState() => _MembershipPaymentPageState();
}

class _MembershipPaymentPageState extends State<MembershipPaymentPage> {
  final GlobalKey _qrBoundaryKey = GlobalKey();
  bool _savingQr = false;

  String get _qrData {
    return widget.order.paymentUri?.trim().isNotEmpty == true
        ? widget.order.paymentUri!.trim()
        : widget.order.qrPayload?.trim().isNotEmpty == true
            ? widget.order.qrPayload!.trim()
            : widget.order.payToAddress?.trim() ?? '';
  }

  Future<void> _copyPaymentValue({
    required String? value,
    required String emptyMessage,
    required String copiedMessage,
  }) async {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _showMessage(emptyMessage);
      return;
    }
    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!mounted) return;
    _showMessage(copiedMessage);
  }

  Future<void> _saveQr() async {
    if (_qrData.isEmpty || _savingQr) return;

    setState(() {
      _savingQr = true;
    });

    try {
      final Future<void> Function()? override = widget.saveQrOverride;
      if (override != null) {
        await override();
      } else {
        await _saveQrBoundaryToFile();
      }
      if (!mounted) return;
      _showMessage('QR saved');
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

  Future<void> _saveQrBoundaryToFile() async {
    final BuildContext? boundaryContext = _qrBoundaryKey.currentContext;
    final RenderObject? renderObject = boundaryContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('QR boundary unavailable');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: 3);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (bytes == null) throw StateError('QR bytes unavailable');

    final Directory directory = Directory.systemTemp;
    final String fileName =
        'membership_payment_qr_${_safeFilePart(widget.order.orderNo)}.png';
    final File file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String amountLabel = _paymentAmountLabel(widget.order);
    final String addressLabel = _paymentValue(
      widget.order.payToAddress,
      'Payment address unavailable',
    );
    final bool hasQrData = _qrData.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Complete payment',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PaymentSummaryCard(
              order: widget.order,
              amountLabel: amountLabel,
              addressLabel: addressLabel,
            ),
            const SizedBox(height: AppSpacing.sm),
            _QrPaymentCard(
              qrData: _qrData,
              boundaryKey: _qrBoundaryKey,
              hasQrData: hasQrData,
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
                    value: widget.order.expectedAmountLbc,
                    emptyMessage: 'Amount unavailable',
                    copiedMessage: 'Amount copied',
                  ),
                ),
                _PaymentPillButton(
                  label: 'Copy address',
                  icon: Icons.content_copy_rounded,
                  onTap: () => _copyPaymentValue(
                    value: widget.order.payToAddress,
                    emptyMessage: 'Payment address unavailable',
                    copiedMessage: 'Address copied',
                  ),
                ),
                _PaymentPillButton(
                  label: _savingQr ? 'Saving...' : 'Save QR',
                  icon: Icons.download_rounded,
                  onTap: hasQrData && !_savingQr ? _saveQr : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _GoldButton(
              label: 'Close',
              onTap: widget.onDone ?? () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.order,
    required this.amountLabel,
    required this.addressLabel,
  });

  final MembershipOrder order;
  final String amountLabel;
  final String addressLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warmBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PaymentInfoRow(label: 'Plan', value: _paymentPlanLabel(order)),
          _PaymentInfoRow(label: 'Order no', value: order.orderNo),
          _PaymentInfoRow(label: 'Status', value: order.status),
          _PaymentInfoRow(label: 'Amount', value: amountLabel),
          _PaymentInfoRow(label: 'Pay to', value: addressLabel),
          _PaymentInfoRow(
            label: 'Expires',
            value: _paymentValue(order.expiresAt, 'No expiry provided'),
          ),
        ],
      ),
    );
  }
}

class _QrPaymentCard extends StatelessWidget {
  const _QrPaymentCard({
    required this.qrData,
    required this.boundaryKey,
    required this.hasQrData,
  });

  final String qrData;
  final GlobalKey boundaryKey;
  final bool hasQrData;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: MembershipPaymentPage.qrSectionKey,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warmBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: <Widget>[
          if (hasQrData) ...<Widget>[
            RepaintBoundary(
              key: boundaryKey,
              child: Container(
                key: MembershipPaymentPage.qrBoundaryKey,
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Container(
                  key: MembershipPaymentPage.qrQuietZoneKey,
                  color: Colors.white,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 192,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Scan or copy the address to pay',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ] else
            Text(
              'Payment address unavailable',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontSize: 12, height: 1.2),
            ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.brandGold.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.brandGold.withValues(alpha: 0.55),
            ),
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
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
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
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

String _paymentPlanLabel(MembershipOrder order) {
  final String? title = order.planTitle?.trim();
  final String? code = order.planCode?.trim();
  if (title != null && title.isNotEmpty && code != null && code.isNotEmpty) {
    return '$title ($code)';
  }
  if (title != null && title.isNotEmpty) return title;
  if (code != null && code.isNotEmpty) return code;
  return 'Plan unavailable';
}

String _paymentAmountLabel(MembershipOrder order) {
  final String? amount = order.expectedAmountLbc?.trim();
  if (amount == null || amount.isEmpty) return 'Amount unavailable';
  final String? currency = order.currency?.trim();
  if (currency == null || currency.isEmpty) return amount;
  return '$amount $currency';
}

String _paymentValue(String? value, String fallback) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return fallback;
  return trimmed;
}

String _safeFilePart(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
