import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/shop_order_models.dart';
import 'domain/shop_repository.dart';

/// Shows the authenticated user's full order history with live status badges.
class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key, required this.repo});

  final ShopRepository repo;

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  List<ShopOrder> _orders = const <ShopOrder>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ShopOrder> orders = await widget.repo.getOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: Text(
          'My Orders',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandGold),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppColors.mutedOliveText,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Failed to load orders',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.mutedOliveText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _load,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.brandGold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.mutedOliveText,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No orders yet',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 17,
                color: AppColors.cocoaText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Start shopping and your orders will appear here.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.brandGold,
      backgroundColor: AppColors.cardBackground,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          return _OrderCard(
            order: _orders[index],
            onTap: () => _showDetail(context, _orders[index]),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, ShopOrder order) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OrderDetailSheet(order: order),
    );
  }
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final ShopOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String unit =
        order.paymentAsset == 'meow_points' ? 'MP' : 'MC';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.softBorder),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header row: order no + status badge
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.orderNo,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mutedOliveText,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Product + thumbnail row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: order.productThumbnailSnapshot != null
                        ? CachedNetworkImage(
                            imageUrl: order.productThumbnailSnapshot!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _OrderThumbPlaceholder(),
                          )
                        : _OrderThumbPlaceholder(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.productNameSnapshot ?? 'Order ${order.orderNo}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.cocoaText,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${order.quantity}  ·  '
                        '${order.paymentAssetDisplay}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mutedOliveText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${order.totalAmountSnapshot} $unit',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brandGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            // Date row
            if (order.createdAt != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatDate(order.createdAt!),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.mutedOliveText,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final DateTime? dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _OrderThumbPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF332E27),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: AppColors.mutedOliveText,
          size: 22,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final ({Color fg, Color bg, String label}) style = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: style.fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        style.label,
        style: AppTextStyles.caption.copyWith(
          color: style.fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  ({Color fg, Color bg, String label}) _style() => switch (status) {
        'paid' => (
            fg: AppColors.brandGold,
            bg: AppColors.brandGold.withValues(alpha: 0.12),
            label: 'Paid',
          ),
        'shipping' => (
            fg: const Color(0xFF4EAAFF),
            bg: const Color(0xFF4EAAFF).withValues(alpha: 0.12),
            label: 'Shipped',
          ),
        'completed' || 'settled' => (
            fg: const Color(0xFF4CAF50),
            bg: const Color(0xFF4CAF50).withValues(alpha: 0.12),
            label: 'Completed',
          ),
        'cancelled' => (
            fg: AppColors.mutedOliveText,
            bg: AppColors.softBorder,
            label: 'Cancelled',
          ),
        'pending' || 'pending_payment' => (
            fg: const Color(0xFFFF9800),
            bg: const Color(0xFFFF9800).withValues(alpha: 0.12),
            label: 'Pending Payment',
          ),
        _ => (
            fg: AppColors.mutedOliveText,
            bg: AppColors.cardBackground,
            label: status,
          ),
      };
}

// ---------------------------------------------------------------------------
// Order detail bottom sheet
// ---------------------------------------------------------------------------

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final String unit =
        order.paymentAsset == 'meow_points' ? 'MP' : 'MC';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ScrollController ctrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg),
            ),
          ),
          child: Column(
            children: <Widget>[
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.softBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Order Details',
                      style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
                    ),
                    const Spacer(),
                    _StatusBadge(status: order.status),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.softBorder),

              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    // Product section
                    if (order.productNameSnapshot != null)
                      _DetailSection(
                        icon: Icons.inventory_2_outlined,
                        title: 'Product',
                        children: <Widget>[
                          _DetailRow(
                            label: 'Name',
                            value: order.productNameSnapshot!,
                          ),
                          _DetailRow(
                            label: 'Quantity',
                            value: '${order.quantity}',
                          ),
                        ],
                      ),

                    const SizedBox(height: AppSpacing.md),

                    // Payment section
                    _DetailSection(
                      icon: Icons.payments_outlined,
                      title: 'Payment',
                      children: <Widget>[
                        _DetailRow(
                          label: 'Method',
                          value: order.paymentAssetDisplay,
                        ),
                        _DetailRow(
                          label: 'Unit Price',
                          value:
                              '${order.unitPriceSnapshot} $unit',
                        ),
                        _DetailRow(
                          label: 'Total',
                          value:
                              '${order.totalAmountSnapshot} $unit',
                          valueColor: AppColors.brandGold,
                        ),
                        _DetailRow(
                          label: 'Order No.',
                          value: order.orderNo,
                          monospace: true,
                        ),
                        if (order.createdAt != null)
                          _DetailRow(
                            label: 'Placed',
                            value: _fmt(order.createdAt!),
                          ),
                        if (order.paidAt != null)
                          _DetailRow(
                            label: 'Paid at',
                            value: _fmt(order.paidAt!),
                          ),
                      ],
                    ),

                    // Shipping section
                    if (order.shippingAddressLine != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _DetailSection(
                        icon: Icons.local_shipping_outlined,
                        title: 'Shipping',
                        children: <Widget>[
                          if (order.shippingReceiverName != null)
                            _DetailRow(
                              label: 'Recipient',
                              value: order.shippingReceiverName!,
                            ),
                          _DetailRow(
                            label: 'Address',
                            value: order.shippingAddressLine!,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(String iso) {
    final DateTime? dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}  ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 15, color: AppColors.mutedOliveText),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.warmBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.softBorder),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: AppColors.softBorder,
            ),
            itemBuilder: (_, int i) => children[i],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
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
            child: Text(
              value,
              style: monospace
                  ? AppTextStyles.caption.copyWith(
                      color: valueColor ?? AppColors.cocoaText,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    )
                  : AppTextStyles.caption.copyWith(
                      color: valueColor ?? AppColors.cocoaText,
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
