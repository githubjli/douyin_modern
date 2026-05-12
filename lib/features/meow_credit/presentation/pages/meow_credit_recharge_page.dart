import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/widgets/back_nav_header.dart';
import '../../../../app/widgets/gold_button.dart';
import '../../../../app/widgets/gold_outline_button.dart';
import '../../../../core/network/api_error.dart';
import '../../application/meow_credit_providers.dart';
import '../../application/recharge_notifier.dart';
import '../../data/meow_credit_repository.dart';
import '../../domain/meow_credit_wallet.dart';

class MeowCreditRechargePage extends ConsumerStatefulWidget {
  const MeowCreditRechargePage({
    super.key,
    required this.package,
    required this.rechargeInfo,
  });

  final MeowCreditPackage package;
  final MeowCreditRechargeInfo rechargeInfo;

  @override
  ConsumerState<MeowCreditRechargePage> createState() =>
      _MeowCreditRechargePageState();
}

class _MeowCreditRechargePageState
    extends ConsumerState<MeowCreditRechargePage> {
  late final RechargeNotifier _notifier;
  final TextEditingController _txHashController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  bool _savingQr = false;

  @override
  void initState() {
    super.initState();
    _notifier = RechargeNotifier(ref.read(meowCreditRepositoryProvider));
  }

  @override
  void dispose() {
    _txHashController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _copyAddress() async {
    final messenger = ScaffoldMessenger.of(context);
    final address = widget.rechargeInfo.payToAddress.trim();
    if (address.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Payment address unavailable')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Address copied')));
  }

  Future<void> _saveQrToAlbum() async {
    if (_savingQr) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingQr = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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

  Future<void> _submitTxid() async {
    final txid = _txHashController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (txid.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please enter a transaction ID.')));
      return;
    }
    try {
      final credited =
          await _notifier.submitTxid(widget.package.code, txid);
      if (!mounted) return;
      setState(() {});
      if (credited) {
        _onCredited();
      } else {
        final reason =
            _notifier.currentState.result?.verification?.reason ?? '';
        messenger.showSnackBar(SnackBar(content: Text(_pendingMessage(reason))));
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {});
      if (e.statusCode == 409) {
        messenger.showSnackBar(
            const SnackBar(content: Text('This transaction ID has already been used.')));
      } else {
        messenger.showSnackBar(
            const SnackBar(content: Text('Submission failed. Please try again.')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
          const SnackBar(content: Text('Submission failed. Please try again.')));
    }
  }

  Future<void> _checkPayment() async {
    final messenger = ScaffoldMessenger.of(context);
    final credited = await _notifier.verifyNow();
    if (!mounted) return;
    setState(() {});
    if (credited) {
      _onCredited();
    } else {
      final reason =
          _notifier.currentState.result?.verification?.reason ?? '';
      messenger.showSnackBar(SnackBar(content: Text(_pendingMessage(reason))));
    }
  }

  void _onCredited() {
    ref.invalidate(meowCreditWalletProvider);
    ref.invalidate(meowCreditLedgerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${widget.rechargeInfo.totalCredit} credits added to your wallet!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).maybePop();
  }

  String _pendingMessage(String reason) {
    switch (reason) {
      case 'chain_lookup_failed':
        return 'Transaction ID recorded. Chain lookup failed — please try again later.';
      case 'no_matching_output':
        return 'Transaction ID recorded. No matching output found — please try again later.';
      default:
        return 'Transaction submitted. Awaiting blockchain confirmation.';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _notifier.currentState;
    final info = widget.rechargeInfo;
    final address = info.payToAddress.trim();
    final notice = info.notice?.isNotEmpty == true
        ? info.notice!
        : 'Send the exact ${info.expectedAmount} ${info.priceCurrency} to the address below.';

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const BackNavHeader(title: 'Manual Payment'),
              const SizedBox(height: AppSpacing.lg),

              // ── Selected plan card ────────────────────────────────────────
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
                        Text('${info.totalCredit} credits total',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white54)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(info.expectedAmount,
                            style: AppTextStyles.sectionTitle.copyWith(
                                color: AppColors.brandGold, fontSize: 28)),
                        Text(info.priceCurrency,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.brandGold)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Status banner ─────────────────────────────────────────────
              if (state.isCredited) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const _StatusBanner(
                  color: Colors.green,
                  icon: Icons.check_circle_outline,
                  message: 'Payment confirmed — credits added!',
                ),
              ] else if (state.isPending) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const _StatusBanner(
                  color: Colors.orange,
                  icon: Icons.hourglass_top_outlined,
                  message: 'Awaiting blockchain confirmation.',
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── QR code ───────────────────────────────────────────────────
              if (address.isNotEmpty && !state.isCredited) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                        style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: RepaintBoundary(
                          key: _qrKey,
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
                            icon: Icons.share_outlined,
                            label: 'Share QR',
                            onTap: _copyAddress,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          GoldOutlineButton(
                            icon: Icons.download_outlined,
                            label: _savingQr ? 'Saving…' : 'Save to Album',
                            onTap: _savingQr ? null : _saveQrToAlbum,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Receiving Address ─────────────────────────────────────────
              if (!state.isCredited) ...<Widget>[
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.brandGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                        color: AppColors.brandGold.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    notice,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.brandGold),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Submit txid section ───────────────────────────────────────
              if (!state.hasResult) ...<Widget>[
                Text('Already Transferred?',
                    style: AppTextStyles.body.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter your transaction ID to verify and credit your wallet.',
                  style: AppTextStyles.caption.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _txHashController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Transaction hash / TX ID',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3)),
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
                GoldButton(
                  label: 'Submit Transaction ID',
                  loading: state.submitting,
                  onTap: state.submitting ? null : _submitTxid,
                ),
              ],

              // ── Check Payment button (pending state) ──────────────────────
              if (state.isPending) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Order: ${state.result!.orderNo}',
                  style: AppTextStyles.caption.copyWith(color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                GoldButton(
                  label: 'Check Payment',
                  loading: state.verifying,
                  onTap: state.canVerify ? _checkPayment : null,
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
// Widgets
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.message,
  });
  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.body.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

