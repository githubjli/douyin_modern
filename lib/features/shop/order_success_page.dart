import '../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/shop_models.dart';
import 'domain/shop_order_models.dart';
import 'domain/shop_repository.dart';
import 'order_detail_page.dart';
import 'order_list_page.dart';

/// Full-screen order success page shown immediately after a successful purchase.
class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({
    super.key,
    required this.order,
    required this.product,
    required this.repo,
  });

  final ShopOrder order;
  final ShopProduct product;
  final ShopRepository repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.xl),
              _SuccessHeader(),
              const SizedBox(height: AppSpacing.xl),
              _OrderCard(order: order, product: product),
              const Spacer(),
              _ActionButtons(order: order, repo: repo),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: animated check icon + title
// ---------------------------------------------------------------------------

class _SuccessHeader extends StatefulWidget {
  @override
  State<_SuccessHeader> createState() => _SuccessHeaderState();
}

class _SuccessHeaderState extends State<_SuccessHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ScaleTransition(
          scale: _scale,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandGold.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.brandGold, width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.brandGold,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Order Placed!',
          style: AppTextStyles.cardTitle.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Payment confirmed. Your item is being prepared.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.mutedOliveText,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Order detail card
// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.product});

  final ShopOrder order;
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Product row with thumbnail
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: product.thumbnailUrl != null
                        ? AppCachedImage(
                            imageUrl: product.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _ThumbPlaceholder(),
                          )
                        : _ThumbPlaceholder(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.cocoaText,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${order.quantity}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mutedOliveText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.softBorder),

          // Order details
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: <Widget>[
                _DetailRow(
                  label: 'Order No.',
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: order.orderNo),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order number copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          order.orderNo,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.cocoaText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: AppColors.mutedOliveText,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _DetailRow(
                  label: 'Payment',
                  value: order.paymentAssetDisplay,
                ),
                const SizedBox(height: AppSpacing.xs),
                _DetailRow(
                  label: 'Amount',
                  valueStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.brandGold,
                    fontWeight: FontWeight.w700,
                  ),
                  value: _amountLabel(),
                ),
                const SizedBox(height: AppSpacing.xs),
                _DetailRow(
                  label: 'Status',
                  child: _StatusBadge(status: order.status),
                ),
                if (order.shippingAddressLine != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailRow(
                    label: 'Ship to',
                    value: '${order.shippingReceiverName ?? ''}  '
                        '${order.shippingAddressLine}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _amountLabel() {
    final String unit = order.paymentAsset == 'meow_points' ? 'MP' : 'MC';
    return '${order.totalAmountSnapshot} $unit';
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF332E27),
      child: const Center(
        child: Icon(Icons.inventory_2_outlined,
            color: AppColors.mutedOliveText, size: 24),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value,
    this.child,
    this.valueStyle,
  }) : assert(value != null || child != null,
            '_DetailRow requires value or child');

  final String label;
  final String? value;
  final Widget? child;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
            ),
          ),
        ),
        Expanded(
          child: child ??
              Text(
                value!,
                style: valueStyle ??
                    AppTextStyles.caption.copyWith(
                      color: AppColors.cocoaText,
                      fontWeight: FontWeight.w500,
                    ),
              ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final bool isPaid = status == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid
            ? AppColors.brandGold.withValues(alpha: 0.15)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: isPaid ? AppColors.brandGold : AppColors.softBorder,
        ),
      ),
      child: Text(
        _label(),
        style: AppTextStyles.caption.copyWith(
          color: isPaid ? AppColors.brandGold : AppColors.mutedOliveText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label() => switch (status) {
        'paid' => '✓  Paid — Awaiting Shipment',
        'shipping' => '⟳  Shipped',
        'completed' || 'settled' => '✓  Completed',
        'cancelled' => '✗  Cancelled',
        _ => status,
      };
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.order, required this.repo});
  final ShopOrder order;
  final ShopRepository repo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              // Pop back past OrderSuccessPage to the shop list
              int count = 0;
              Navigator.of(context).popUntil((_) => count++ >= 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGold,
              foregroundColor: AppColors.warmBackground,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              textStyle: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailPage(
                    orderNo: order.orderNo,
                    repo: repo,
                    initialOrder: order,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.softBorder),
              foregroundColor: AppColors.cocoaText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: const Text('View Order Details'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => OrderListPage(repo: repo),
              ),
            );
          },
          child: const Text('View All Orders', style: TextStyle(color: AppColors.mutedOliveText, fontSize: 13)),
        ),
      ],
    );
  }
}
