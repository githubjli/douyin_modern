import 'package:meow_media/app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/shop_order_models.dart';
import 'domain/shop_repository.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderNo,
    required this.repo,
    this.initialOrder,
  });

  final String orderNo;
  final ShopRepository repo;
  final ShopOrder? initialOrder;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  ShopOrder? _order;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (_order != null) _loading = false;
    _load();
  }

  Future<void> _load() async {
    try {
      final ShopOrder o = await widget.repo.getOrderDetail(widget.orderNo);
      if (!mounted) return;
      setState(() {
        _order = o;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_order != null) {
        setState(() => _loading = false);
      } else {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmReceived() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Confirm Receipt', style: AppTextStyles.cardTitle),
        content: Text(
          'Have you received your package?',
          style: AppTextStyles.caption,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: TextStyle(color: AppColors.brandGold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      final ShopOrder updated = await widget.repo.confirmReceived(widget.orderNo);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _actionLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt confirmed. Thank you!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _requestRefund() async {
    final _RefundResult? result = await showModalBottomSheet<_RefundResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      builder: (_) => _RefundSheet(order: _order!),
    );
    if (result == null || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      await widget.repo.requestRefund(
        orderNo: widget.orderNo,
        reason: result.reason,
        requestedAmount: result.amount,
      );
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund request submitted.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
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
    if (_error != null && _order == null) {
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

    final ShopOrder order = _order!;
    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 120,
          ),
          children: <Widget>[
            _StatusCard(order: order),
            const SizedBox(height: AppSpacing.sm),
            _ProductCard(order: order),
            const SizedBox(height: AppSpacing.sm),
            if (order.shippingAddressLine != null || order.shippingReceiverName != null)
              _ShippingCard(order: order),
            if (order.shippingAddressLine != null || order.shippingReceiverName != null)
              const SizedBox(height: AppSpacing.sm),
            if (order.shipment != null) ...<Widget>[
              _ShipmentCard(shipment: order.shipment!),
              const SizedBox(height: AppSpacing.sm),
            ],
            _PaymentCard(order: order),
            const SizedBox(height: AppSpacing.sm),
            if (order.refundSummary?.activeRefundRequestExists == true)
              _RefundStatusCard(order: order),
          ],
        ),
        if (_actionLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator(color: AppColors.brandGold)),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ActionBar(
            order: order,
            onConfirmReceived: _confirmReceived,
            onRequestRefund: _requestRefund,
          ),
        ),
      ],
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = switch (order.status) {
      'completed' || 'settled' => Colors.green,
      'cancelled' => Colors.red,
      'shipping' => AppColors.brandGold,
      _ => AppColors.mutedOliveText,
    };
    return _Card(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.statusText,
                  style: AppTextStyles.cardTitle.copyWith(color: statusColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order #${order.orderNo}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
                ),
                if (order.createdAt != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(order.createdAt!),
                    style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.statusText,
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: <Widget>[
          if (order.productThumbnailSnapshot != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppCachedImage(
                imageUrl: order.productThumbnailSnapshot!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
          if (order.productThumbnailSnapshot != null)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (order.productNameSnapshot != null)
                  Text(order.productNameSnapshot!, style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      '${order.paymentAssetDisplay}  ${order.unitPriceSnapshot}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
                    ),
                    const Spacer(),
                    Text(
                      'x${order.quantity}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ${order.paymentAssetDisplay}  ${order.totalAmountSnapshot}',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Shipping Address', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
          const SizedBox(height: 6),
          if (order.shippingReceiverName != null)
            Text(order.shippingReceiverName!, style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
          if (order.shippingAddressLine != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(order.shippingAddressLine!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment});
  final ShopShipment shipment;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Shipment Info', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
          const SizedBox(height: 6),
          _InfoRow(label: 'Carrier', value: shipment.carrier),
          _InfoRow(label: 'Tracking No.', value: shipment.trackingNumber),
          if (shipment.shippedAt != null)
            _InfoRow(label: 'Shipped At', value: _formatDate(shipment.shippedAt!)),
          if (shipment.trackingUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: shipment.trackingUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tracking URL copied to clipboard')),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Track Package', style: TextStyle(color: AppColors.brandGold, fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(Icons.copy_rounded, size: 13, color: AppColors.brandGold),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final ShopPaymentSummary? ps = order.paymentSummary;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Payment', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
          const SizedBox(height: 6),
          _InfoRow(label: 'Method', value: order.paymentAssetDisplay),
          _InfoRow(label: 'Amount', value: order.totalAmountSnapshot),
          if (ps != null && ps.txid != null)
            _InfoRow(label: 'Txid', value: ps.txid!),
          if (order.paidAt != null)
            _InfoRow(label: 'Paid At', value: _formatDate(order.paidAt!)),
        ],
      ),
    );
  }
}

class _RefundStatusCard extends StatelessWidget {
  const _RefundStatusCard({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? latest = order.refundSummary?.latestRefundRequest;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.replay_outlined, size: 16, color: AppColors.brandGold),
              const SizedBox(width: 6),
              Text('Refund Request', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
            ],
          ),
          if (latest != null) ...<Widget>[
            const SizedBox(height: 6),
            if (latest['status'] != null)
              _InfoRow(label: 'Status', value: _refundStatusText(latest['status'].toString())),
            if (latest['requested_amount'] != null)
              _InfoRow(label: 'Amount', value: latest['requested_amount'].toString()),
            if (latest['reason'] != null)
              _InfoRow(label: 'Reason', value: latest['reason'].toString()),
          ],
        ],
      ),
    );
  }
}

// ── Action Bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.order,
    required this.onConfirmReceived,
    required this.onRequestRefund,
  });

  final ShopOrder order;
  final VoidCallback onConfirmReceived;
  final VoidCallback onRequestRefund;

  @override
  Widget build(BuildContext context) {
    final bool showConfirm = order.canConfirmReceived;
    final bool showRefund = order.canRequestRefund;
    if (!showConfirm && !showRefund) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          if (showRefund)
            Expanded(
              child: OutlinedButton(
                onPressed: onRequestRefund,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cocoaText,
                  side: BorderSide(color: AppColors.mutedOliveText.withValues(alpha: 0.4)),
                ),
                child: const Text('Request Refund'),
              ),
            ),
          if (showConfirm && showRefund) const SizedBox(width: AppSpacing.sm),
          if (showConfirm)
            Expanded(
              child: ElevatedButton(
                onPressed: onConfirmReceived,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Receipt'),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Refund Sheet ──────────────────────────────────────────────────────────────

class _RefundResult {
  const _RefundResult({required this.reason, required this.amount});
  final String reason;
  final String amount;
}

class _RefundSheet extends StatefulWidget {
  const _RefundSheet({required this.order});
  final ShopOrder order;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.order.totalAmountSnapshot;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final String reason = _reasonCtrl.text.trim();
    final String amount = _amountCtrl.text.trim();
    if (reason.isEmpty || amount.isEmpty) return;
    Navigator.pop(context, _RefundResult(reason: reason, amount: amount));
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Request Refund', style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reasonCtrl,
            decoration: InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(
              labelText: 'Requested Amount',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }
}

String _refundStatusText(String status) => switch (status) {
      'pending' || 'pending_review' => 'Under Review',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'completed' || 'refunded' => 'Refunded',
      'cancelled' => 'Cancelled',
      _ => status,
    };

String _formatDate(String iso) {
  try {
    final DateTime dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}
