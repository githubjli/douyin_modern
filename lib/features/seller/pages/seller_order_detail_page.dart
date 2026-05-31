import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../data/seller_repository.dart';
import '../domain/seller_models.dart';

class SellerOrderDetailPage extends StatefulWidget {
  const SellerOrderDetailPage({
    super.key,
    required this.orderNo,
    required this.repo,
    this.initialOrder,
  });

  final String orderNo;
  final SellerRepository repo;
  final SellerOrder? initialOrder;

  @override
  State<SellerOrderDetailPage> createState() => _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends State<SellerOrderDetailPage> {
  SellerOrder? _order;
  bool _loading = true;
  bool _shipping = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (_order != null) _loading = false;
    _load();
  }

  Future<void> _load() async {
    try {
      final SellerOrder o = await widget.repo.getOrderDetail(widget.orderNo);
      if (!mounted) return;
      setState(() { _order = o; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      if (_order == null) setState(() => _loading = false);
    }
  }

  Future<void> _ship() async {
    final _ShipResult? result = await showModalBottomSheet<_ShipResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ShipSheet(orderNo: widget.orderNo),
    );
    if (result == null || !mounted) return;
    setState(() => _shipping = true);
    try {
      final SellerOrder updated = await widget.repo.shipOrder(
        orderNo: widget.orderNo,
        carrier: result.carrier,
        trackingNumber: result.trackingNumber,
        trackingUrl: result.trackingUrl,
        shippedNote: result.note,
      );
      if (!mounted) return;
      setState(() { _order = updated; _shipping = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as shipped.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _shipping = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
        title: Text('Order Details', style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _order == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandGold));
    }
    final SellerOrder? order = _order;
    if (order == null) {
      return Center(child: Text('Order not found', style: AppTextStyles.caption));
    }

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
          children: <Widget>[
            _StatusCard(order: order),
            const SizedBox(height: AppSpacing.sm),
            _ProductCard(order: order),
            const SizedBox(height: AppSpacing.sm),
            _BuyerCard(order: order),
            const SizedBox(height: AppSpacing.sm),
            if (order.shippingAddressLine != null) ...<Widget>[
              _ShippingCard(order: order),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (order.shipment != null) _ShipmentCard(shipment: order.shipment!),
          ],
        ),
        if (_shipping)
          const Positioned.fill(
            child: ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator(color: AppColors.brandGold))),
          ),
        if (order.canShip)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _ShipBar(onShip: _ship, context: context),
          ),
      ],
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final Color c = switch (order.status) {
      'completed' || 'settled' => Colors.green,
      'cancelled' => Colors.red,
      'shipping' => AppColors.brandGold,
      'paid' => Colors.blue,
      _ => AppColors.mutedOliveText,
    };
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(order.statusText, style: AppTextStyles.cardTitle.copyWith(color: c))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(order.statusText, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: order.orderNo));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order number copied')));
          },
          child: Row(children: <Widget>[
            Text('# ${order.orderNo}', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 11)),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded, size: 11, color: AppColors.mutedOliveText),
          ]),
        ),
        if (order.createdAt.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(_fmt(order.createdAt), style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 11)),
        ],
      ],
    ));
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Product', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
        const SizedBox(height: 6),
        if (order.productTitleSnapshot != null) Text(order.productTitleSnapshot!, style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
        const SizedBox(height: 4),
        Row(children: <Widget>[
          Text('${order.productPriceSnapshot ?? '--'}  ×  ${order.quantity}', style: AppTextStyles.caption.copyWith(color: AppColors.brandGold)),
          const Spacer(),
          Text('Total: ${order.totalAmount}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ],
    ));
  }
}

class _BuyerCard extends StatelessWidget {
  const _BuyerCard({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final SellerOrderBuyer? b = order.buyer;
    if (b == null) return const SizedBox.shrink();
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Buyer', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
        const SizedBox(height: 6),
        if (b.displayName != null) _Row('Name', b.displayName!),
        if (b.email != null) _Row('Email', b.email!),
      ],
    ));
  }
}

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Ship To', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
        const SizedBox(height: 6),
        if (order.receiverName != null) _Row('Name', order.receiverName!),
        if (order.shippingAddressLine != null) _Row('Address', order.shippingAddressLine!),
      ],
    ));
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment});
  final Map<String, dynamic> shipment;

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Shipment', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
        const SizedBox(height: 6),
        if (shipment['carrier'] != null) _Row('Carrier', shipment['carrier'].toString()),
        if (shipment['tracking_number'] != null) _Row('Tracking', shipment['tracking_number'].toString()),
        if (shipment['shipped_at'] != null) _Row('Shipped At', _fmt(shipment['shipped_at'].toString())),
      ],
    ));
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ShipBar extends StatelessWidget {
  const _ShipBar({required this.onShip, required this.context});
  final VoidCallback onShip;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm + MediaQuery.of(ctx).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onShip,
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          label: const Text('Mark as Shipped'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}

// ── Ship sheet ────────────────────────────────────────────────────────────────

class _ShipResult {
  const _ShipResult({required this.carrier, required this.trackingNumber, this.trackingUrl, this.note});
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
  final GlobalKey<FormState> _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _carrierCtrl.dispose(); _trackingCtrl.dispose(); _urlCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Ship Order', style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.md),
            _f(_carrierCtrl, 'Carrier *', hint: 'e.g. DHL, FedEx', validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: AppSpacing.sm),
            _f(_trackingCtrl, 'Tracking Number *', validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: AppSpacing.sm),
            _f(_urlCtrl, 'Tracking URL', keyboardType: TextInputType.url),
            const SizedBox(height: AppSpacing.sm),
            _f(_noteCtrl, 'Note (optional)', maxLines: 2),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!(_key.currentState?.validate() ?? false)) return;
                  Navigator.pop(context, _ShipResult(
                    carrier: _carrierCtrl.text.trim(),
                    trackingNumber: _trackingCtrl.text.trim(),
                    trackingUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
                    note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                  ));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Confirm Shipment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _f(TextEditingController ctrl, String label, {String? hint, int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, keyboardType: keyboardType, validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
    child: child,
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      SizedBox(width: 72, child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText))),
      Expanded(child: Text(value, style: AppTextStyles.caption)),
    ]),
  );
}

String _fmt(String iso) {
  try {
    final DateTime dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) { return iso; }
}
