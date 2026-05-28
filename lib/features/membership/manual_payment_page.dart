import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/widgets/back_nav_header.dart';
import '../../app/widgets/gold_button.dart';
import '../../app/widgets/gold_outline_button.dart';
import 'domain/manual_membership_repository.dart';
import 'domain/manual_payment_info.dart';
import 'domain/manual_tx_hint.dart';
import 'domain/membership_repository.dart';
import 'domain/membership_status.dart';
import 'domain/payment_asset_option.dart';
import 'platform_asset_payment_page.dart';

typedef QrCodeSaver = Future<bool> Function(GlobalKey qrKey);

class ManualPaymentPage extends StatefulWidget {
  const ManualPaymentPage({
    super.key,
    required this.paymentInfo,
    required this.repository,
    this.qrCodeSaver,
    this.displayCurrency,
    this.supportedPaymentAssets,
    this.paymentAssetOptions,
    this.membershipRepository,
    this.onMembershipActivated,
  });

  final ManualPaymentInfo paymentInfo;
  final ManualMembershipRepository repository;
  final QrCodeSaver? qrCodeSaver;
  // Overrides info.currency in display (e.g. plan's settlement token symbol).
  final String? displayCurrency;
  /// Plan's supported_payment_assets list from the API.
  final List<String>? supportedPaymentAssets;
  /// Per-asset estimated prices from payment_asset_options[] in the plan API.
  final List<PaymentAssetOption>? paymentAssetOptions;
  /// Required to create platform-asset orders (meow_points / meow_credit).
  final MembershipRepository? membershipRepository;
  /// Called after an instant payment completes successfully.
  final VoidCallback? onMembershipActivated;

  @override
  State<ManualPaymentPage> createState() => _ManualPaymentPageState();
}

class _ManualPaymentPageState extends State<ManualPaymentPage> {
  final GlobalKey _qrKey = GlobalKey();
  final TextEditingController _txController = TextEditingController();

  bool _savingQr = false;
  bool _savingQrToAlbum = false;
  bool _submittingTx = false;
  bool _checkingStatus = false;
  bool _txSubmitDisabled = false; // server said endpoint is closed
  bool _txSubmitted = false;

  MembershipStatus? _activeMembership;
  ManualTxHint? _submittedHint;

  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (_showChainPaymentSection()) _startPassivePoll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _txController.dispose();
    super.dispose();
  }

  ManualPaymentInfo get info => widget.paymentInfo;

  // ---------------------------------------------------------------------------
  // Polling — passive, 30-second interval
  // ---------------------------------------------------------------------------

  void _startPassivePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollMembershipStatus());
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollMembershipStatus() async {
    if (!mounted) return;
    try {
      final MembershipStatus? status =
          await widget.repository.getMembershipStatus();
      if (!mounted) return;
      if (status?.isActive == true) {
        setState(() => _activeMembership = status);
        _stopPoll();
      }
    } catch (_) {
      // silent — keep polling
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _checkStatusNow() async {
    if (_checkingStatus) return;
    setState(() => _checkingStatus = true);
    try {
      final MembershipStatus? status =
          await widget.repository.getMembershipStatus();
      if (!mounted) return;
      if (status?.isActive == true) {
        setState(() => _activeMembership = status);
        _stopPoll();
      } else {
        _showMessage('Membership not active yet. Please allow time for staff review.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to check status. Please try again.');
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _copyAddress() async {
    await Clipboard.setData(ClipboardData(text: info.payToAddress));
    if (!mounted) return;
    _showMessage('Address copied');
  }

  Future<void> _saveQrCode() async {
    if (_savingQr) return;
    setState(() => _savingQr = true);
    try {
      final bool saved =
          await (widget.qrCodeSaver ?? _writeQrPng)(_qrKey);
      if (!mounted) return;
      if (!saved) _showMessage('Unable to share QR. Please try again.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to save QR. Please try again.');
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  Future<void> _saveQrToAlbum() async {
    if (_savingQrToAlbum) return;
    setState(() => _savingQrToAlbum = true);
    try {
      // 1. Capture PNG while the QR widget is fully rendered.
      //    Must happen BEFORE requestAccess() — the permission dialog briefly
      //    suspends the app and a subsequent repaint can cause toImage() to
      //    return blank or null.
      final Uint8List? png = await _captureQrPng(_qrKey);
      if (!mounted) return;
      if (png == null || png.isEmpty) {
        _showMessage('Unable to capture QR. Please try again.');
        return;
      }

      // 2. Request photo-library write access (may show system dialog).
      final bool hasAccess = await Gal.requestAccess();
      if (!mounted) return;
      if (!hasAccess) {
        _showMessage(
          'Photo access denied. Enable it in Settings → Privacy → Photos.',
        );
        return;
      }

      // 3. Save the already-captured bytes.
      await Gal.putImageBytes(
        png,
        name: 'payment_qr_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      _showMessage('QR saved — check "Recents" in your Photos app');
    } on GalException catch (e) {
      if (!mounted) return;
      switch (e.type) {
        case GalExceptionType.accessDenied:
          _showMessage(
            'Photo access denied. Enable it in Settings → Privacy → Photos.',
          );
        case GalExceptionType.notEnoughSpace:
          _showMessage('Not enough storage space to save QR.');
        case GalExceptionType.notSupportedFormat:
        case GalExceptionType.unexpected:
          _showMessage('Unable to save QR. Please try again.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to save QR. Please try again.');
    } finally {
      if (mounted) setState(() => _savingQrToAlbum = false);
    }
  }

  Future<void> _submitTxid() async {
    if (_submittingTx) return;
    final String txid = _txController.text.trim();
    if (txid.isEmpty) {
      _showMessage('Please enter your transaction ID.');
      return;
    }

    setState(() => _submittingTx = true);
    try {
      final ManualTxHint hint = await widget.repository.submitTxHint(
        planCode: info.planCode,
        txid: txid,
      );
      if (!mounted) return;
      setState(() {
        _submittedHint = hint;
        _txSubmitted = true;
        _submittingTx = false;
      });
      _showMessage('Transaction submitted. Staff will verify shortly.');
    } on ManualTxSubmitDisabledException catch (e) {
      if (!mounted) return;
      setState(() {
        _txSubmitDisabled = true;
        _submittingTx = false;
      });
      _showMessage(e.message ?? 'txid submission is not available yet.');
    } on ManualTxDuplicateException {
      if (!mounted) return;
      setState(() {
        _txSubmitted = true;
        _submittingTx = false;
      });
      _showMessage('This transaction has already been submitted.');
    } on ManualTxPendingExistsException {
      if (!mounted) return;
      setState(() {
        _txSubmitted = true;
        _submittingTx = false;
      });
      _showMessage('You already have a pending payment under review.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingTx = false);
      _showMessage('Unable to submit. Please try again.');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _navigateToAssetPayment(String assetCode) async {
    final MembershipRepository? repo = widget.membershipRepository;
    if (repo == null) return;
    // Find the matching PaymentAssetOption so we can show the estimated price
    // on the confirmation screen before the order is created.
    final PaymentAssetOption? option = widget.paymentAssetOptions
        ?.where((PaymentAssetOption o) => o.assetCode == assetCode)
        .firstOrNull;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlatformAssetPaymentPage(
          planCode: info.planCode,
          planName: info.planName,
          paymentAsset: assetCode,
          estimatedPaymentAmount: option?.estimatedPaymentAmount,
          estimatedPaymentAssetLabel: option?.displayName,
          repository: repo,
          onSuccess: widget.onMembershipActivated,
        ),
      ),
    );
  }

  /// Returns non-thb_ltt assets to show as instant-payment buttons.
  List<String> _alternativeAssets() {
    final List<String>? assets = widget.supportedPaymentAssets;
    if (assets == null || assets.isEmpty) return const <String>[];
    return assets.where((String a) => a != 'thb_ltt').toList();
  }

  /// Show the chain-payment section (QR / address / txid) only when
  /// thb_ltt is explicitly supported OR when no supported_payment_assets
  /// list is provided (backwards compatibility).
  bool _showChainPaymentSection() {
    final List<String>? assets = widget.supportedPaymentAssets;
    if (assets == null) return true;
    return assets.contains('thb_ltt');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool activated = _activeMembership?.isActive == true;

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
              const BackNavHeader(title: 'Manual Payment'),
              const SizedBox(height: AppSpacing.md),
              _PlanSummaryCard(
                info: info,
                displayCurrency: widget.displayCurrency,
              ),
              Builder(
                builder: (BuildContext ctx) {
                  final List<String> alts = _alternativeAssets();
                  if (alts.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _AlternativePaymentCard(
                        assets: alts,
                        paymentAssetOptions: widget.paymentAssetOptions,
                        onPayWith: _navigateToAssetPayment,
                      ),
                    ],
                  );
                },
              ),
              if (info.purchaseMode != PurchaseMode.unknown &&
                  info.purchaseMode != PurchaseMode.newSubscription) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _PurchaseModeCard(info: info),
              ],
              const SizedBox(height: AppSpacing.md),
              if (activated)
                _SuccessCard(
                  planName: _activeMembership!.planTitle,
                  endsAt: _activeMembership!.endsAt,
                  onDone: () => Navigator.of(context).maybePop(),
                )
              else if (_showChainPaymentSection()) ...<Widget>[
                _QrSection(
                  qrKey: _qrKey,
                  address: info.payToAddress,
                  saving: _savingQr,
                  onSave: _saveQrCode,
                  savingAlbum: _savingQrToAlbum,
                  onSaveAlbum: _saveQrToAlbum,
                ),
                const SizedBox(height: AppSpacing.md),
                _AddressCard(
                  address: info.payToAddress,
                  onCopy: _copyAddress,
                ),
                const SizedBox(height: AppSpacing.sm),
                _NoticeCard(
                  currency: widget.displayCurrency ?? info.currency,
                  notice: info.notice,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_txSubmitDisabled)
                  _TxidSection(
                    controller: _txController,
                    submitting: _submittingTx,
                    submitted: _txSubmitted,
                    hint: _submittedHint,
                    onSubmit: _submitTxid,
                  ),
                if (_txSubmitDisabled)
                  _TxidDisabledCard(),
                const SizedBox(height: AppSpacing.sm),
                _CheckStatusButton(
                  checking: _checkingStatus,
                  onCheck: _checkStatusNow,
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
  const _PlanSummaryCard({required this.info, this.displayCurrency});
  final ManualPaymentInfo info;
  final String? displayCurrency;

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
                  info.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _formatAmount(info.expectedAmountLbc),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                displayCurrency ?? info.currency,
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
    // Show up to 8 decimal places, strip trailing zeros.
    return v
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _PurchaseModeCard extends StatelessWidget {
  const _PurchaseModeCard({required this.info});
  final ManualPaymentInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.08),
        border: Border.all(
            color: AppColors.brandGold.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _modeLabel(),
          if (info.currentMembership?.endsAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _InfoLine(
              label: 'Current plan expires',
              value: _fmtDate(info.currentMembership!.endsAt),
            ),
          ],
          if (info.estimatedNewEndsAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            _InfoLine(
              label: info.isRenewal ? 'Renews to' : 'New expiry',
              value: _fmtDate(info.estimatedNewEndsAt),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeLabel() {
    final String label = switch (info.purchaseMode) {
      PurchaseMode.renewal => 'Renewal — extends your current plan',
      PurchaseMode.planChange =>
        'Plan change — takes effect after current plan ends',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.brandGold,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
    );
  }

  static String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          '$label: ',
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: AppColors.mutedOliveText,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _QrSection extends StatelessWidget {
  const _QrSection({
    required this.qrKey,
    required this.address,
    required this.saving,
    required this.onSave,
    required this.savingAlbum,
    required this.onSaveAlbum,
  });

  final GlobalKey qrKey;
  final String address;
  final bool saving;
  final VoidCallback onSave;
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
          Text(
            'Scan to Pay',
            style:
                AppTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
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
                icon: saving
                    ? Icons.hourglass_top_rounded
                    : Icons.share_outlined,
                label: saving ? 'Sharing...' : 'Share QR',
                onTap: saving ? null : onSave,
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
  const _AddressCard({required this.address, required this.onCopy});
  final String address;
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
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    address,
                    softWrap: true,
                    style: AppTextStyles.body
                        .copyWith(fontSize: 12, height: 1.25),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: 'Copy address',
                  child: _IconButton(
                    icon: Icons.content_copy_rounded,
                    onTap: onCopy,
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
  const _NoticeCard({required this.currency, this.notice});
  final String currency;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final String text = notice?.isNotEmpty == true
        ? notice!
        : 'Send $currency only to the address above, then wait for staff verification.';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.10),
        border: Border.all(
            color: AppColors.brandGold.withValues(alpha: 0.36)),
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
    required this.hint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final bool submitted;
  final ManualTxHint? hint;
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
            'Already Transferred?',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Enter your transaction ID to speed up verification.',
            style: AppTextStyles.body
                .copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (submitted && hint != null) ...<Widget>[
            _TxidStatusRow(hint: hint!),
          ] else ...<Widget>[
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              style: AppTextStyles.body.copyWith(fontSize: 12),
              cursorColor: AppColors.brandGold,
              decoration: InputDecoration(
                hintText: 'e.g. b10608a77dd4bbe597a15803c3e96...',
                hintStyle:
                    AppTextStyles.caption.copyWith(fontSize: 12),
                filled: true,
                fillColor: AppColors.warmBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide:
                      const BorderSide(color: AppColors.softBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(
                    color: AppColors.brandGold.withValues(alpha: 0.58),
                  ),
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

class _TxidStatusRow extends StatelessWidget {
  const _TxidStatusRow({required this.hint});
  final ManualTxHint hint;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = hint.status.isSuccess
        ? AppColors.brandGold
        : hint.status == ManualTxHintStatus.rejected
            ? Colors.redAccent
            : AppColors.cocoaText;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.warmBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.check_circle_outline_rounded,
                  size: 14, color: AppColors.brandGold),
              const SizedBox(width: 4),
              Text(
                'Transaction ID submitted',
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            hint.txid,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption
                .copyWith(fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Status: ${hint.status.displayLabel}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint.rejectReason?.isNotEmpty == true)
            Text(
              'Reason: ${hint.rejectReason}',
              style: AppTextStyles.caption
                  .copyWith(fontSize: 11, color: Colors.redAccent),
            ),
        ],
      ),
    );
  }
}

class _TxidDisabledCard extends StatelessWidget {
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
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.mutedOliveText),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Transaction ID submission is not available in this version. '
              'Staff will verify your payment manually.',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: AppColors.mutedOliveText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckStatusButton extends StatelessWidget {
  const _CheckStatusButton({
    required this.checking,
    required this.onCheck,
  });
  final bool checking;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return GoldOutlineButton(
      icon: checking
          ? Icons.hourglass_top_rounded
          : Icons.refresh_rounded,
      label: checking ? 'Checking...' : 'Check Membership Status',
      onTap: checking ? null : onCheck,
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
            'Membership Activated',
            style:
                AppTextStyles.sectionTitle.copyWith(fontSize: 18),
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

class _AlternativePaymentCard extends StatelessWidget {
  const _AlternativePaymentCard({
    required this.assets,
    required this.onPayWith,
    this.paymentAssetOptions,
  });

  final List<String> assets;
  final List<PaymentAssetOption>? paymentAssetOptions;
  final ValueChanged<String> onPayWith;

  /// Returns the human-readable asset name, preferring the backend display_name.
  String _assetName(String asset) {
    final String? backendName = paymentAssetOptions
        ?.where((PaymentAssetOption o) => o.assetCode == asset)
        .firstOrNull
        ?.displayName;
    if (backendName != null) return backendName;
    return switch (asset) {
      'meow_points' => 'MeowPoints',
      'meow_credit' => 'MeowCredit',
      'thb_ltt'     => 'THB-LTT',
      _ => _titleCase(asset),
    };
  }

  /// Returns the estimated payment amount for this asset, if available.
  String? _estimatedAmount(String asset) {
    return paymentAssetOptions
        ?.where((PaymentAssetOption o) => o.assetCode == asset)
        .firstOrNull
        ?.estimatedPaymentAmount;
  }

  /// Formats the button label: "Pay with MeowPoints — 300 MeowPoints".
  String _label(String asset) {
    final String name = _assetName(asset);
    final String? raw = _estimatedAmount(asset);
    if (raw == null) return 'Pay with $name';
    final String formatted = _formatAmount(raw);
    return 'Pay with $name — $formatted $name';
  }

  static String _titleCase(String raw) => raw
      .split('_')
      .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String _formatAmount(String raw) {
    final double? v = double.tryParse(raw.trim());
    if (v == null) return raw.trim();
    return v
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

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
            'Other Payment Options',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...assets.map((String asset) {
            final bool isLast = asset == assets.last;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xs),
              child: _AssetButton(
                label: _label(asset),
                onTap: () => onPayWith(asset),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AssetButton extends StatelessWidget {
  const _AssetButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.brandGold.withValues(alpha: 0.08),
          border: Border.all(
              color: AppColors.brandGold.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.brandGold,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR PNG helpers
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

Future<bool> _writeQrPng(GlobalKey key) async {
  final Uint8List? png = await _captureQrPng(key);
  if (png == null || png.isEmpty) return false;

  final Directory tmp = await getTemporaryDirectory();
  final String path =
      '${tmp.path}/payment_qr_${DateTime.now().millisecondsSinceEpoch}.png';
  await File(path).writeAsBytes(png, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(path, mimeType: 'image/png')],
      subject: 'Payment QR Code',
    ),
  );
  return true;
}
