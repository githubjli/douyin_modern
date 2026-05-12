import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../application/meow_credit_providers.dart';
import '../../application/recharge_notifier.dart';
import '../../data/meow_credit_repository.dart';
import '../../domain/meow_credit_wallet.dart';
import 'package:path_provider/path_provider.dart';

class MeowCreditRechargePage extends ConsumerStatefulWidget {
  const MeowCreditRechargePage({
    super.key,
    required this.package,
    required this.order,
  });

  final MeowCreditPackage package;
  final MeowCreditOrder order;

  @override
  ConsumerState<MeowCreditRechargePage> createState() =>
      _MeowCreditRechargePageState();
}

class _MeowCreditRechargePageState
    extends ConsumerState<MeowCreditRechargePage> {
  late RechargeNotifier _notifier;
  final TextEditingController _txHashController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _savingQr = false;

  static const Duration _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _notifier = RechargeNotifier(
      ref.read(meowCreditRepositoryProvider),
      widget.order,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startCountdown();
      if (mounted) _startPolling();
    });
  }

  @override
  void dispose() {
    _txHashController.dispose();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Countdown ──────────────────────────────────────────────────────────────

  void _startCountdown() {
    final String? expiresAt = widget.order.expiresAt;
    if (expiresAt == null) return;
    final DateTime? expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return;

    void tick() {
      if (!mounted) return;
      final remaining = expiry.difference(DateTime.now());
      _notifier.tick(remaining.isNegative ? Duration.zero : remaining);
      setState(() {});
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      final credited = await _notifier.pollOrder();
      if (mounted) setState(() {});
      if (credited && mounted) {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        ref.invalidate(meowCreditWalletProvider);
        ref.invalidate(meowCreditLedgerProvider);
        _showSuccessAndPop();
      }
    });
  }

  void _showSuccessAndPop() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${widget.package.totalCredit} credits added to your wallet!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _copyAddress() async {
    final messenger = ScaffoldMessenger.of(context);
    final address = widget.order.payToAddress.trim();
    if (address.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Payment address unavailable')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Address copied')));
  }

  Future<void> _shareQr() async {
    // Basic share via clipboard for now; can integrate share_plus later
    await _copyAddress();
  }

  Future<void> _saveQrToAlbum() async {
    if (_savingQr) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingQr = true);
    try {
      final boundary = _qrKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('QR not rendered');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture QR');
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/meow_credit_qr.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('QR saved')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Unable to save QR. Please try again.')));
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  Future<void> _submitTxHash() async {
    final txHash = _txHashController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (txHash.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please enter transaction hash.')));
      return;
    }
    final success = await _notifier.submitTxHint(txHash);
    if (mounted) setState(() {});
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(success
          ? 'Transaction hash submitted. Awaiting confirmation.'
          : 'Unable to submit transaction hash. Please try again.'),
    ));
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _notifier.currentState;
    final order = state.order ?? widget.order;
    final remaining = state.remaining;
    final address = order.payToAddress.trim();
    final bool expired = order.isExpired && remaining == Duration.zero;
    final bool credited = order.isCredited;

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Manual Payment',
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: Colors.white)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Selected plan card ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border.all(
                      color: AppColors.brandGold.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Selected Plan',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.brandGold)),
                        const SizedBox(height: 4),
                        Text(widget.package.name,
                            style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        Text('${widget.package.totalCredit} credits total',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white54)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(order.expectedAmount,
                            style: AppTextStyles.sectionTitle.copyWith(
                                color: AppColors.brandGold, fontSize: 28)),
                        Text(order.priceCurrency,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.brandGold)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Countdown banner ─────────────────────────────────────────
              if (order.expiresAt != null && !credited) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: expired
                        ? Colors.redAccent.withValues(alpha: 0.12)
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        expired ? 'Order expired' : 'Order expires in',
                        style: AppTextStyles.caption.copyWith(
                            color:
                                expired ? Colors.redAccent : Colors.white54),
                      ),
                      if (!expired)
                        Text(_formatDuration(remaining),
                            style: AppTextStyles.body.copyWith(
                                color: AppColors.brandGold,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],

              // ── Success banner ───────────────────────────────────────────
              if (credited) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text('Payment confirmed — credits added!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body
                          .copyWith(color: Colors.green)),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── Scan to Pay ──────────────────────────────────────────────
              if (address.isNotEmpty) ...<Widget>[
                Text('Scan to Pay',
                    style: AppTextStyles.body.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: QrImageView(
                        data: address,
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Share QR / Save to Album buttons
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _OutlineButton(
                        icon: Icons.share_outlined,
                        label: 'Share QR',
                        onTap: _shareQr,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _OutlineButton(
                        icon: Icons.download_outlined,
                        label: _savingQr ? 'Saving…' : 'Save to Album',
                        onTap: _savingQr ? null : _saveQrToAlbum,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Receiving Address ────────────────────────────────────────
              Text('Receiving Address',
                  style: AppTextStyles.body.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        address.isNotEmpty ? address : 'Address unavailable',
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.white70),
                      ),
                    ),
                    GestureDetector(
                      onTap: _copyAddress,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.brandGold),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.copy,
                            size: 16, color: AppColors.brandGold),
                      ),
                    ),
                  ],
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
                  'Send the exact ${order.priceCurrency} amount to the platform '
                  'address, then wait for staff verification.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.brandGold),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Already Transferred? ─────────────────────────────────────
              Text('Already Transferred?',
                  style: AppTextStyles.body.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your transaction ID to speed up verification.',
                style: AppTextStyles.caption.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _txHashController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Transaction hash / TX ID',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: state.submittingTxid ? null : _submitTxHash,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: state.submittingTxid
                        ? AppColors.brandGold.withValues(alpha: 0.5)
                        : AppColors.brandGold,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  alignment: Alignment.center,
                  child: state.submittingTxid
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text('Submit Transaction Hash',
                          style: AppTextStyles.body.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared outline button (Share QR / Save to Album)
// ---------------------------------------------------------------------------

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
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
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: AppColors.softBorder),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
