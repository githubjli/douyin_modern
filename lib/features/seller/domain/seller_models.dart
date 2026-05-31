// ── Seller Application ────────────────────────────────────────────────────────

enum SellerApplicationStatus { pending, approved, rejected }

class SellerApplication {
  const SellerApplication({
    required this.id,
    required this.storeName,
    required this.businessType,
    required this.businessDescription,
    required this.contactPhone,
    required this.contactEmail,
    required this.status,
    this.businessLicenseUrl,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  final int id;
  final String storeName;
  final String businessType;
  final String businessDescription;
  final String contactPhone;
  final String contactEmail;
  final SellerApplicationStatus status;
  final String? businessLicenseUrl;
  final String? rejectionReason;
  final String? submittedAt;
  final String? reviewedAt;

  factory SellerApplication.fromJson(Map<String, dynamic> j) =>
      SellerApplication(
        id: j['id'] as int? ?? 0,
        storeName: j['store_name'] as String? ?? '',
        businessType: j['business_type'] as String? ?? 'individual',
        businessDescription: j['business_description'] as String? ?? '',
        contactPhone: j['contact_phone'] as String? ?? '',
        contactEmail: j['contact_email'] as String? ?? '',
        status: _parseStatus(j['status'] as String?),
        businessLicenseUrl: j['business_license_url'] as String?,
        rejectionReason: j['rejection_reason'] as String?,
        submittedAt: j['submitted_at'] as String?,
        reviewedAt: j['reviewed_at'] as String?,
      );

  static SellerApplicationStatus _parseStatus(String? s) => switch (s) {
        'approved' => SellerApplicationStatus.approved,
        'rejected' => SellerApplicationStatus.rejected,
        _ => SellerApplicationStatus.pending,
      };
}

// ── Store ─────────────────────────────────────────────────────────────────────

class SellerStore {
  const SellerStore({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final bool isActive;

  factory SellerStore.fromJson(Map<String, dynamic> j) => SellerStore(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        logoUrl: j['logo_url'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (description != null) 'description': description,
      };
}

// ── Seller Product ────────────────────────────────────────────────────────────

class SellerProduct {
  const SellerProduct({
    required this.id,
    required this.name,
    required this.stock,
    this.price,
    this.meowPointsPrice,
    this.meowCreditPrice,
    this.originalPrice,
    this.thumbnailUrl,
    this.description,
    this.badge,
    this.categorySlug,
    this.soldCount = 0,
    this.isActive = true,
  });

  final int id;
  final String name;
  final int stock;
  final String? price;
  final String? meowPointsPrice;
  final String? meowCreditPrice;
  final String? originalPrice;
  final String? thumbnailUrl;
  final String? description;
  final String? badge;
  final String? categorySlug;
  final int soldCount;
  final bool isActive;

  String get displayPrice {
    if (meowPointsPrice != null) return '$meowPointsPrice MP';
    if (meowCreditPrice != null) return '$meowCreditPrice MC';
    if (price != null) return price!;
    return '--';
  }

  factory SellerProduct.fromJson(Map<String, dynamic> j) {
    final dynamic cat = j['category'];
    final String? slug = cat is Map<String, dynamic>
        ? cat['slug'] as String?
        : j['category_slug'] as String?;
    return SellerProduct(
      id: j['id'] as int? ?? 0,
      name: j['name'] as String? ?? '',
      stock: j['stock'] as int? ?? 0,
      price: j['price'] as String?,
      meowPointsPrice: j['meow_points_price'] as String?,
      meowCreditPrice: j['meow_credit_price'] as String?,
      originalPrice: j['original_price'] as String?,
      thumbnailUrl: j['thumbnail_url'] as String?,
      description: j['description'] as String?,
      badge: j['badge'] as String?,
      categorySlug: slug,
      soldCount: j['sold_count'] as int? ?? 0,
      isActive: j['is_active'] as bool? ?? true,
    );
  }
}

// ── Seller Order ──────────────────────────────────────────────────────────────

class SellerOrder {
  const SellerOrder({
    required this.orderNo,
    required this.status,
    required this.totalAmount,
    required this.quantity,
    required this.createdAt,
    this.productTitleSnapshot,
    this.productPriceSnapshot,
    this.currency,
    this.buyer,
    this.shippingAddressSnapshot,
    this.shipment,
    this.paidAt,
    this.shippedAt,
    this.completedAt,
  });

  final String orderNo;
  final String status;
  final String totalAmount;
  final int quantity;
  final String createdAt;
  final String? productTitleSnapshot;
  final String? productPriceSnapshot;
  final String? currency;
  final SellerOrderBuyer? buyer;
  final Map<String, dynamic>? shippingAddressSnapshot;
  final Map<String, dynamic>? shipment;
  final String? paidAt;
  final String? shippedAt;
  final String? completedAt;

  String get statusText => switch (status) {
        'pending_payment' || 'pending' => 'Pending payment',
        'paid' => 'Paid',
        'shipping' => 'Shipped',
        'completed' || 'settled' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  bool get canShip => status == 'paid';

  String? get shippingAddressLine {
    final Map<String, dynamic>? snap = shippingAddressSnapshot;
    if (snap == null || snap.isEmpty) return null;
    final List<String> parts = <String>[
      if ((snap['address_line1'] as String?)?.isNotEmpty == true) snap['address_line1'] as String,
      if ((snap['city'] as String?)?.isNotEmpty == true) snap['city'] as String,
      if ((snap['state'] as String?)?.isNotEmpty == true) snap['state'] as String,
      if ((snap['country'] as String?)?.isNotEmpty == true) snap['country'] as String,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  String? get receiverName => shippingAddressSnapshot?['receiver_name'] as String?;

  factory SellerOrder.fromJson(Map<String, dynamic> j) {
    final dynamic buyerRaw = j['buyer'];
    return SellerOrder(
      orderNo: j['order_no'] as String? ?? '',
      status: j['status'] as String? ?? '',
      totalAmount: (j['total_amount'] ?? '0').toString(),
      quantity: j['quantity'] as int? ?? 1,
      createdAt: j['created_at'] as String? ?? '',
      productTitleSnapshot: j['product_title_snapshot'] as String?,
      productPriceSnapshot: (j['product_price_snapshot'] ?? '').toString(),
      currency: j['currency'] as String?,
      buyer: buyerRaw is Map<String, dynamic>
          ? SellerOrderBuyer.fromJson(buyerRaw)
          : null,
      shippingAddressSnapshot:
          j['shipping_address_snapshot'] is Map<String, dynamic>
              ? j['shipping_address_snapshot'] as Map<String, dynamic>
              : null,
      shipment: j['shipment'] is Map<String, dynamic>
          ? j['shipment'] as Map<String, dynamic>
          : null,
      paidAt: j['paid_at'] as String?,
      shippedAt: j['shipped_at'] as String?,
      completedAt: j['completed_at'] as String?,
    );
  }
}

class SellerOrderBuyer {
  const SellerOrderBuyer({
    required this.id,
    this.displayName,
    this.email,
  });

  final int id;
  final String? displayName;
  final String? email;

  factory SellerOrderBuyer.fromJson(Map<String, dynamic> j) => SellerOrderBuyer(
        id: j['id'] as int? ?? 0,
        displayName: j['display_name'] as String?,
        email: j['email'] as String?,
      );
}
