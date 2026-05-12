import 'dart:async';

import 'package:flutter/material.dart';
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
  Timer? _countdownTimer;
  Timer? _pollTimer;

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
          '${widget.order.totalCredit} credits added to your wallet!',
        ),
        backgroundColor: Colors.green,
      ),
    );
    // Pop back to wallet page
    Navigator.of(context)
      ..pop() // recharge page
      ..pop(); // package page
  }

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
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = _notifier.currentState;
    final order = state.order ?? widget.order;
    final remaining = state.remaining;
    final pkg = widget.package;
    {

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
                      Text('Recharge',
                          style: AppTextStyles.sectionTitle
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Selected package card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      border: Border.all(
                          color: AppColors.brandGold.withValues(alpha: 0.5)),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Selected Package',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.brandGold)),
                            const SizedBox(height: 4),
                            Text(pkg.name,
                                style: AppTextStyles.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            Text('${pkg.totalCredit} Credits total',
                                style: AppTextStyles.caption
                                    .copyWith(color: Colors.white54)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(order.expectedAmount,
                                style: AppTextStyles.sectionTitle.copyWith(
                                    color: AppColors.brandGold, fontSize: 24)),
                            Text(order.priceCurrency,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.brandGold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Countdown
                  if (remaining > Duration.zero)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('Order expires in',
                              style: AppTextStyles.caption
                                  .copyWith(color: Colors.white54)),
                          Text(_formatDuration(remaining),
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.brandGold,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (state.isExpired)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Text('Order expired.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body
                              .copyWith(color: Colors.redAccent)),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // QR code
                  if (order.payToAddress.isNotEmpty) ...<Widget>[
                    Text('Scan to Pay',
                        style: AppTextStyles.sectionTitle
                            .copyWith(color: Colors.white)),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        color: Colors.white,
                        child: QrImageView(
                          data: order.payToAddress,
                          version: QrVersions.auto,
                          size: 200,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Receiving address
                  Text('Receiving Address',
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            order.payToAddress.isNotEmpty
                                ? order.payToAddress
                                : 'Address unavailable',
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
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                          color: AppColors.brandGold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Send the exact ${order.priceCurrency} amount to this address, '
                      'then wait for staff verification.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.brandGold),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Already transferred? (txid)
                  Text('Already Transferred?',
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Enter your transaction ID to speed up verification.',
                    style:
                        AppTextStyles.caption.copyWith(color: Colors.white54),
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
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
}
