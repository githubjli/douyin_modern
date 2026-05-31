import 'package:meow_media/app/widgets/app_refresh_indicator.dart';
import '../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/shop_order_models.dart';
import 'domain/shop_repository.dart';
import 'order_detail_page.dart';

/// Shows the authenticated user's full order history with status tab filter.
class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key, required this.repo});

  final ShopRepository repo;

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab(label: 'All',      status: null),
    _Tab(label: 'Pending',  status: 'pending_payment'),
    _Tab(label: 'Paid',     status: 'paid'),
    _Tab(label: 'Shipped',  status: 'shipping'),
    _Tab(label: 'Done',     status: 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: Text('My Orders', style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brandGold,
          unselectedLabelColor: AppColors.mutedOliveText,
          indicatorColor: AppColors.brandGold,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((_Tab t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((_Tab t) => _OrderTabList(repo: widget.repo, status: t.status))
            .toList(),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.label, required this.status});
  final String label;
  final String? status;
}

// ── Per-tab list ──────────────────────────────────────────────────────────────

class _OrderTabList extends StatefulWidget {
  const _OrderTabList({required this.repo, required this.status});
  final ShopRepository repo;
  final String? status;

  @override
  State<_OrderTabList> createState() => _OrderTabListState();
}

class _OrderTabListState extends State<_OrderTabList>
    with AutomaticKeepAliveClientMixin {
  List<ShopOrder> _orders = const <ShopOrder>[];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // getOrders doesn't support status filter from backend yet —
      // fetch all and filter client-side.
      final List<ShopOrder> all = await widget.repo.getOrders();
      if (!mounted) return;
      final List<ShopOrder> filtered = widget.status == null
          ? all
          : all.where((ShopOrder o) {
              if (widget.status == 'completed') {
                return o.status == 'completed' || o.status == 'settled';
              }
              return o.status == widget.status;
            }).toList();
      setState(() { _orders = filtered; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openDetail(ShopOrder order) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandGold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.mutedOliveText),
              const SizedBox(height: AppSpacing.sm),
              Text('Failed to load orders', style: AppTextStyles.body.copyWith(color: AppColors.mutedOliveText)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _load,
                child: const Text('Retry', style: TextStyle(color: AppColors.brandGold)),
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
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.mutedOliveText),
            const SizedBox(height: AppSpacing.sm),
            Text('No orders', style: AppTextStyles.cardTitle.copyWith(fontSize: 17, color: AppColors.cocoaText)),
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
        itemBuilder: (_, int i) => _OrderCard(
          order: _orders[i],
          onTap: () => _openDetail(_orders[i]),
        ),
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final ShopOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String unit = order.paymentAsset == 'meow_points' ? 'MP' : 'MC';
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
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.orderNo,
                    style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: order.productThumbnailSnapshot != null
                        ? AppCachedImage(
                            imageUrl: order.productThumbnailSnapshot!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _Placeholder(),
                          )
                        : _Placeholder(),
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
                        style: AppTextStyles.body.copyWith(color: AppColors.cocoaText, fontWeight: FontWeight.w600, height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${order.quantity}  ·  ${order.paymentAssetDisplay}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${order.totalAmountSnapshot} $unit',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            if (order.createdAt != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _fmt(order.createdAt!),
                style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(String iso) {
    final DateTime? dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF332E27),
        child: const Center(child: Icon(Icons.inventory_2_outlined, color: AppColors.mutedOliveText, size: 22)),
      );
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final ({Color fg, Color bg, String label}) s = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: s.fg.withValues(alpha: 0.4)),
      ),
      child: Text(s.label, style: AppTextStyles.caption.copyWith(color: s.fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  ({Color fg, Color bg, String label}) _style() => switch (status) {
        'paid' => (fg: AppColors.brandGold, bg: AppColors.brandGold.withValues(alpha: 0.12), label: 'Paid'),
        'shipping' => (fg: const Color(0xFF4EAAFF), bg: const Color(0xFF4EAAFF).withValues(alpha: 0.12), label: 'Shipped'),
        'completed' || 'settled' => (fg: const Color(0xFF4CAF50), bg: const Color(0xFF4CAF50).withValues(alpha: 0.12), label: 'Completed'),
        'cancelled' => (fg: AppColors.mutedOliveText, bg: AppColors.softBorder, label: 'Cancelled'),
        'pending' || 'pending_payment' => (fg: const Color(0xFFFF9800), bg: const Color(0xFFFF9800).withValues(alpha: 0.12), label: 'Pending'),
        _ => (fg: AppColors.mutedOliveText, bg: AppColors.cardBackground, label: status),
      };
}
