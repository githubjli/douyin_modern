import 'package:meow_media/app/widgets/app_refresh_indicator.dart';
import '../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/shop_order_models.dart';
import 'domain/shop_repository.dart';
import 'order_detail_page.dart';

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

    return AppRefreshIndicator(
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
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailPage(
          orderNo: order.orderNo,
          repo: widget.repo,
          initialOrder: order,
        ),
      ),
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
                        ? AppCachedImage(
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

