import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/back_nav_header.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../application/meow_credit_providers.dart';
import '../../data/meow_credit_repository.dart';
import '../../domain/meow_credit_wallet.dart';

// ---------------------------------------------------------------------------
// RechargeStatusPage
// Received right after the user submits a txid.
// Polls every 5 s for status updates.
// ---------------------------------------------------------------------------

class RechargeStatusPage extends ConsumerStatefulWidget {
  const RechargeStatusPage({
    super.key,
    required this.package,
    required this.recharge,
  });

  final MeowCreditPackage package;
  final MeowCreditRecharge recharge;

  @override
  ConsumerState<RechargeStatusPage> createState() => _RechargeStatusPageState();
}

class _RechargeStatusPageState extends ConsumerState<RechargeStatusPage> {
  late MeowCreditRecharge _recharge;
  Timer? _timer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _recharge = widget.recharge;
    if (!_recharge.isCredited) {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    // Poll every 5 s normally; switches to 2 s once payment is confirmed
    // (paymentOrderStatus == 'paid') so we catch the auto-credit quickly.
    final interval = (_recharge.paymentOrderStatus == 'paid')
        ? const Duration(seconds: 2)
        : const Duration(seconds: 5);
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final updated = await ref
          .read(meowCreditRepositoryProvider)
          .getRechargeDetail(_recharge.orderNo);
      if (!mounted) return;

      final bool wasPaymentPending =
          _recharge.paymentOrderStatus != 'paid';
      final bool nowPaymentPaid =
          updated.paymentOrderStatus == 'paid';

      setState(() => _recharge = updated);

      if (updated.isCredited) {
        // ✅ Fully credited — stop polling and refresh wallet.
        _timer?.cancel();
        ref.invalidate(meowCreditWalletProvider);
        ref.invalidate(meowCreditLedgerProvider);
      } else if (wasPaymentPending && nowPaymentPaid) {
        // Payment just confirmed → restart at faster 2-second interval
        // so we catch the auto-credit as soon as it lands.
        _startPolling();
      }
    } catch (_) {
      // silent — keep polling
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool credited = _recharge.isCredited;
    final bool paymentPaid = _recharge.paymentOrderStatus == 'paid';
    // 3 visual states:
    //   1. pending   — txid submitted, waiting for payment confirmation
    //   2. paid      — payment confirmed, backend is crediting
    //   3. credited  — fully done

    final String title = credited
        ? 'Credits Added!'
        : paymentPaid
            ? 'Payment Confirmed'
            : 'Awaiting Confirmation';

    final String subtitle = credited
        ? '${_recharge.totalCredit} Meow Credits have been added to your wallet.'
        : paymentPaid
            ? 'Payment received! Crediting your account — this usually takes a few seconds.'
            : 'We received your txid and are waiting for the transaction '
                'to be confirmed. This page updates automatically.';

    final String pollLabel = paymentPaid
        ? 'Crediting — checking every 2 seconds…'
        : 'Checking every 5 seconds…';

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: BackNavHeader(
                title: 'Recharge Status',
                icon: Icons.close_rounded,
                onBack: () => Navigator.of(context)
                    .popUntil((r) => r.isFirst || r.settings.name == '/'),
              ),
            ),

            const Spacer(),

            // ── Status icon ──────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: credited
                  ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey<String>('credited'),
                      color: AppColors.brandGold,
                      size: 80)
                  : paymentPaid
                      ? const Icon(Icons.verified_rounded,
                          key: ValueKey<String>('paid'),
                          color: AppColors.brandGold,
                          size: 80)
                      : const _PendingIcon(key: ValueKey<String>('pending')),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Title ────────────────────────────────────────────────────────
            Text(
              title,
              style: AppTextStyles.sectionTitle
                  .copyWith(color: Colors.white, fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Subtitle ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                style: AppTextStyles.body.copyWith(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Order info card ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _InfoCard(
                package: widget.package,
                recharge: _recharge,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Polling indicator ────────────────────────────────────────────
            if (!credited)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: paymentPaid
                            ? AppColors.brandGold
                            : AppColors.brandGold.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(pollLabel,
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.white38)),
                  ],
                ),
              ),

            const Spacer(),

            // ── Done button (only when credited) ────────────────────────────
            if (credited)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .popUntil((r) => r.isFirst || r.settings.name == '/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    child: Text('Done',
                        style: AppTextStyles.body.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
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

class _PendingIcon extends StatefulWidget {
  const _PendingIcon({super.key});

  @override
  State<_PendingIcon> createState() => _PendingIconState();
}

class _PendingIconState extends State<_PendingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: const Icon(Icons.hourglass_top_rounded,
          color: AppColors.brandGold, size: 80),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.package, required this.recharge});
  final MeowCreditPackage package;
  final MeowCreditRecharge recharge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Column(
        children: <Widget>[
          _Row(label: 'Package', value: package.name),
          const SizedBox(height: 8),
          _Row(
            label: 'Credits',
            value: '${recharge.totalCredit}',
            valueColor: AppColors.brandGold,
          ),
          const SizedBox(height: 8),
          _Row(label: 'Order #', value: recharge.orderNo),
          const SizedBox(height: 8),
          // Payment status — shows 'Paid ✓' as soon as admin confirms
          if (recharge.paymentOrderStatus.isNotEmpty) ...<Widget>[
            _Row(
              label: 'Payment',
              value: recharge.paymentOrderStatus == 'paid'
                  ? 'Paid ✓'
                  : recharge.paymentOrderStatus,
              valueColor: recharge.paymentOrderStatus == 'paid'
                  ? AppColors.brandGold
                  : Colors.white54,
            ),
            const SizedBox(height: 8),
          ],
          _Row(
            label: 'Status',
            value: recharge.isCredited
                ? 'Credited ✓'
                : recharge.status[0].toUpperCase() +
                    recharge.status.substring(1),
            valueColor:
                recharge.isCredited ? Colors.greenAccent : Colors.white70,
          ),
          if (recharge.txid != null && recharge.txid!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _Row(
              label: 'Txid',
              value:
                  '${recharge.txid!.substring(0, recharge.txid!.length.clamp(0, 16))}…',
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label,
            style: AppTextStyles.caption.copyWith(color: Colors.white54)),
        Text(value,
            style: AppTextStyles.caption
                .copyWith(color: valueColor ?? Colors.white)),
      ],
    );
  }
}
