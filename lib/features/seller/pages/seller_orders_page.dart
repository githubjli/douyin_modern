import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../data/seller_repository.dart';
import '../domain/seller_models.dart';
import 'seller_order_detail_page.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final SellerRepository _repo;
  late final TabController _tabController;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab(label: 'All', status: null),
    _Tab(label: 'Paid', status: 'paid'),
    _Tab(label: 'Shipped', status: 'shipping'),
    _Tab(label: 'Done', status: 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _repo = SellerRepository(ApiClient());
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
        title: Text('Manage Orders', style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brandGold,
          unselectedLabelColor: AppColors.mutedOliveText,
          indicatorColor: AppColors.brandGold,
          tabs: _tabs
              .map((_Tab t) => Tab(text: t.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((_Tab t) => _OrderList(repo: _repo, status: t.status))
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

// ── Order list per tab ────────────────────────────────────────────────────────

class _OrderList extends StatefulWidget {
  const _OrderList({required this.repo, required this.status});
  final SellerRepository repo;
  final String? status;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList>
    with AutomaticKeepAliveClientMixin {
  List<SellerOrder> _orders = const <SellerOrder>[];
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SellerOrder> orders =
          await widget.repo.getOrders(status: widget.status);
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

  void _openDetail(SellerOrder order) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerOrderDetailPage(
          orderNo: order.orderNo,
          repo: widget.repo,
          initialOrder: order,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _shipOrder(SellerOrder order) async {
    final _ShipResult? result = await showModalBottomSheet<_ShipResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ShipSheet(orderNo: order.orderNo),
    );
    if (result == null || !mounted) return;
    try {
      await widget.repo.shipOrder(
        orderNo: order.orderNo,
        carrier: result.carrier,
        trackingNumber: result.trackingNumber,
        trackingUrl: result.trackingUrl,
        shippedNote: result.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as shipped.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ship failed: $e')),
      );
    }
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
              Text(_error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Text(
          'No orders',
          style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brandGold,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, int i) => GestureDetector(
          onTap: () => _openDetail(_orders[i]),
          child: _SellerOrderTile(
            order: _orders[i],
            onShip: _orders[i].canShip ? () => _shipOrder(_orders[i]) : null,
          ),
        ),
      ),
    );
  }
}

// ── Order Tile ────────────────────────────────────────────────────────────────

class _SellerOrderTile extends StatelessWidget {
  const _SellerOrderTile({required this.order, this.onShip});
  final SellerOrder order;
  final VoidCallback? onShip;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = switch (order.status) {
      'completed' || 'settled' => Colors.green,
      'cancelled' => Colors.red,
      'shipping' => AppColors.brandGold,
      'paid' => Colors.blue,
      _ => AppColors.mutedOliveText,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.productTitleSnapshot ?? 'Order',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                'x${order.quantity}  •  ${order.totalAmount}${order.currency != null ? " ${order.currency}" : ""}',
                style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
              ),
              const Spacer(),
              Text(
                _formatDate(order.createdAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.mutedOliveText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (order.buyer?.displayName != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Icon(Icons.person_outline, size: 13, color: AppColors.mutedOliveText),
                const SizedBox(width: 4),
                Text(
                  order.buyer!.displayName!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 11),
                ),
              ],
            ),
          ],
          if (order.shippingAddressLine != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Icon(Icons.location_on_outlined, size: 13, color: AppColors.mutedOliveText),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.shippingAddressLine!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (onShip != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onShip,
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Mark as Shipped'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Ship Sheet ────────────────────────────────────────────────────────────────

class _ShipResult {
  const _ShipResult({
    required this.carrier,
    required this.trackingNumber,
    this.trackingUrl,
    this.note,
  });
  final String carrier;
  final String trackingNumber;
  final String? trackingUrl;
  final String? note;
}

class _ShipSheet extends StatefulWidget {
  const _ShipSheet({required this.orderNo});
  final String orderNo;

  @override
  State<_ShipSheet> createState() => _ShipSheetState();
}

class _ShipSheetState extends State<_ShipSheet> {
  final TextEditingController _carrierCtrl = TextEditingController();
  final TextEditingController _trackingCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _carrierCtrl.dispose();
    _trackingCtrl.dispose();
    _urlCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _ShipResult(
        carrier: _carrierCtrl.text.trim(),
        trackingNumber: _trackingCtrl.text.trim(),
        trackingUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Ship Order', style: AppTextStyles.cardTitle),
                const Spacer(),
                Text(
                  '#${widget.orderNo}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _shipField(
              controller: _carrierCtrl,
              label: 'Carrier *',
              hint: 'e.g. DHL, FedEx, USPS',
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _shipField(
              controller: _trackingCtrl,
              label: 'Tracking Number *',
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _shipField(
              controller: _urlCtrl,
              label: 'Tracking URL',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.sm),
            _shipField(
              controller: _noteCtrl,
              label: 'Note (optional)',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirm Shipment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shipField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatDate(String iso) {
  try {
    final DateTime dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}
