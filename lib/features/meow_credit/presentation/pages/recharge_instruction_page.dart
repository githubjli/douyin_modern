import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/widgets/back_nav_header.dart';
import '../../../../app/widgets/gold_button.dart';
import '../../../../app/widgets/gold_outline_button.dart';
import '../../data/meow_credit_repository.dart';
import '../../domain/meow_credit_wallet.dart';
import 'recharge_status_page.dart';

// ---------------------------------------------------------------------------
// RechargeInstructionPage
// Shown after the user selects a package. Displays the pay-to address / QR
// so the user can send funds externally. No order is created at this stage.
// After the user transfers funds they paste the txid and tap Submit —
// that's when the order is created and we navigate to RechargeStatusPage.
// ---------------------------------------------------------------------------

class RechargeInstructionPage extends ConsumerStatefulWidget {
  const RechargeInstructionPage({
    super.key,
    required this.package,
    required this.info,
  });

  final MeowCreditPackage package;
  final MeowCreditRechargeInfo info;

  @override
  ConsumerState<RechargeInstructionPage> createState() =>
      _RechargeInstructionPageState();
}

class _RechargeInstructionPageState
    extends ConsumerState<RechargeInstructionPage> {
  final GlobalKey _qrKey = GlobalKey();
  final TextEditingController _txController = TextEditingController();

  bool _sharingQr = false;
  bool _savingAlbum = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _submittedTxid;
  String? _error;

  @override
  void dispose() {
    _txController.dispose();
    super.dispose();
  }

  // ── QR actions ─────────────────────────────────────────────────────────────

  Future<void> _shareQr() async {
    if (_sharingQr) return;
    setState(() => _sharingQr = true);
    try {
      final Uint8List? png = await _captureQrPng(_qrKey);
      if (png == null || png.isEmpty) {
        _showMsg('Unable to share QR. Please try again.');
        return;
      }
      final Directory tmp = await getTemporaryDirectory();
      final String path =
          '${tmp.path}/credit_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(png, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path, mimeType: 'image/png')],
          subject: 'Meow Credit Payment QR',
        ),
      );
    } catch (_) {
      if (mounted) _showMsg('Unable to share QR. Please try again.');
    } finally {
      if (mounted) setState(() => _sharingQr = false);
    }
  }

  Future<void> _saveToAlbum() async {
    if (_savingAlbum) return;
    setState(() => _savingAlbum = true);
    try {
      final Uint8List? png = await _captureQrPng(_qrKey);
      if (png == null || png.isEmpty) {
        _showMsg('Unable to save. Please try again.');
        return;
      }
      await Gal.putImageBytes(
        png,
        name: 'credit_qr_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) _showMsg('QR saved to Photos');
    } catch (_) {
      if (mounted) _showMsg('Unable to save to Photos. Please try again.');
    } finally {
      if (mounted) setState(() => _savingAlbum = false);
    }
  }

  Future<void> _copyAddress() async {
    await Clipboard.setData(ClipboardData(text: widget.info.payToAddress));
    if (mounted) _showMsg('Address copied');
  }

  // ── Submit txid ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final String txid = _txController.text.trim();
    if (txid.isEmpty) {
      setState(() => _error = 'Please enter your transaction ID.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final MeowCreditRecharge recharge = await ref
          .read(meowCreditRepositoryProvider)
          .submitTxid(widget.package.code, txid);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submittedTxid = txid;
        _submitting = false;
      });
      // Navigate to the status / polling page.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RechargeStatusPage(
            package: widget.package,
            recharge: recharge,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().contains('ApiError')
            ? e.toString().replaceFirst(RegExp(r'^ApiError\([^)]+\): '), '')
            : 'Submission failed. Check your txid and try again.';
        _submitting = false;
      });
    }
  }

  void _showMsg(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final MeowCreditPackage pkg = widget.package;
    final MeowCreditRechargeInfo info = widget.info;

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
              // ── Header ─────────────────────────────────────────────────────
              const BackNavHeader(title: 'Payment Instructions'),
              const SizedBox(height: AppSpacing.md),

              // ── Package summary ─────────────────────────────────────────────
              _PackageSummaryCard(pkg: pkg, info: info),
              const SizedBox(height: AppSpacing.md),

              // ── QR + Share / Save ───────────────────────────────────────────
              if (info.payToAddress.isNotEmpty) ...<Widget>[
                _QrSection(
                  qrKey: _qrKey,
                  address: info.payToAddress,
                  sharing: _sharingQr,
                  onShare: _shareQr,
                  savingAlbum: _savingAlbum,
                  onSaveAlbum: _saveToAlbum,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Receiving address ───────────────────────────────────────────
              _AddressCard(
                address: info.payToAddress,
                label: 'Send ${info.expectedAmount} ${info.priceCurrency} to',
                onCopy: _copyAddress,
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Notice ──────────────────────────────────────────────────────
              _NoticeCard(
                pkg: pkg,
                info: info,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Txid input / submitted state ────────────────────────────────
              _TxidSection(
                controller: _txController,
                submitting: _submitting,
                submitted: _submitted,
                submittedTxid: _submittedTxid,
                error: _error,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets — styled identically to ManualPaymentPage
// ---------------------------------------------------------------------------

class _PackageSummaryCard extends StatelessWidget {
  const _PackageSummaryCard({required this.pkg, required this.info});
  final MeowCreditPackage pkg;
  final MeowCreditRechargeInfo info;

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
                  'Selected Package',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brandGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  pkg.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pkg.totalCredit} credits'
                  '${pkg.bonusCredit > 0 ? '  (+${pkg.bonusCredit} bonus)' : ''}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.mutedOliveText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                info.expectedAmount,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                info.priceCurrency,
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

class _QrSection extends StatelessWidget {
  const _QrSection({
    required this.qrKey,
    required this.address,
    required this.sharing,
    required this.onShare,
    required this.savingAlbum,
    required this.onSaveAlbum,
  });

  final GlobalKey qrKey;
  final String address;
  final bool sharing;
  final VoidCallback onShare;
  final bool savingAlbum;
  final VoidCallback onSaveAlbum;

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
          Text('Scan to Pay',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: RepaintBoundary(
              key: qrKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: QrImageView(
                  data: address,
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              GoldOutlineButton(
                icon: sharing
                    ? Icons.hourglass_top_rounded
                    : Icons.share_outlined,
                label: sharing ? 'Sharing...' : 'Share QR',
                onTap: sharing ? null : onShare,
              ),
              const SizedBox(width: AppSpacing.sm),
              GoldOutlineButton(
                icon: savingAlbum
                    ? Icons.hourglass_top_rounded
                    : Icons.download_rounded,
                label: savingAlbum ? 'Saving...' : 'Save to Album',
                onTap: savingAlbum ? null : onSaveAlbum,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.label,
    required this.onCopy,
  });
  final String address;
  final String label;
  final VoidCallback onCopy;

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
          Text('Receiving Address',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
              fontSize: 11,
            ),
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
              children: <Widget>[
                Expanded(
                  child: Text(
                    address.isNotEmpty ? address : 'Address unavailable',
                    softWrap: true,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      height: 1.25,
                      color: address.isNotEmpty ? null : AppColors.mutedOliveText,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: 'Copy address',
                  child: _IconButton(
                    icon: Icons.content_copy_rounded,
                    onTap: address.isNotEmpty ? onCopy : null,
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.pkg, required this.info});
  final MeowCreditPackage pkg;
  final MeowCreditRechargeInfo info;

  @override
  Widget build(BuildContext context) {
    final String text = (info.notice?.isNotEmpty == true)
        ? info.notice!
        : 'Send the exact ${info.expectedAmount} ${info.priceCurrency} to '
            'the platform address, then paste your txid below to verify.';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.10),
        border:
            Border.all(color: AppColors.brandGold.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.brandGold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _TxidSection extends StatelessWidget {
  const _TxidSection({
    required this.controller,
    required this.submitting,
    required this.submitted,
    required this.submittedTxid,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final bool submitted;
  final String? submittedTxid;
  final String? error;
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
          Text('Already Transferred?',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Enter your transaction ID to speed up verification.',
            style: AppTextStyles.body.copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (submitted && submittedTxid != null) ...<Widget>[
            // Submitted confirmation row
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.warmBackground,
                border: Border.all(color: AppColors.softBorder),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: AppColors.brandGold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      submittedTxid!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            TextField(
              controller: controller,
              enabled: !submitting,
              minLines: 1,
              maxLines: 3,
              style: AppTextStyles.body.copyWith(fontSize: 12),
              cursorColor: AppColors.brandGold,
              decoration: InputDecoration(
                hintText: 'e.g. b10608a77dd4bbe597a15803c3e96...',
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
                      color: AppColors.brandGold.withValues(alpha: 0.58)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: const BorderSide(color: AppColors.softBorder),
                ),
                errorText: error,
                errorStyle: AppTextStyles.caption.copyWith(
                  color: Colors.redAccent,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GoldButton(
              label: submitting ? 'Submitting...' : 'Submit Transaction ID',
              onTap: submitting ? null : onSubmit,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.brandGold.withValues(alpha: 0.12),
          border: Border.all(
              color: AppColors.brandGold.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, size: 15, color: AppColors.brandGold),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR PNG capture helpers (shared with ManualPaymentPage)
// ---------------------------------------------------------------------------

Future<Uint8List?> _captureQrPng(GlobalKey key) async {
  final BuildContext? ctx = key.currentContext;
  if (ctx == null) return null;
  final RenderObject? ro = ctx.findRenderObject();
  if (ro is! RenderRepaintBoundary) return null;
  final ui.Image image = await ro.toImage(pixelRatio: 3);
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
