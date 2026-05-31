import 'dart:ui' show ImageFilter;

import '../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_error.dart';
import '../auth/application/auth_providers.dart';
import '../meow_credit/application/meow_credit_providers.dart';
import '../meow_points/application/meow_points_providers.dart';
import '../shipping/data/shipping_address_repository.dart';
import '../shipping/domain/shipping_address.dart';
import '../shipping/presentation/address_list_page.dart';
import 'data/mock_shop_repository.dart';
import 'data/remote_shop_repository.dart';
import 'domain/shop_models.dart';
import 'domain/shop_order_models.dart';
import 'domain/shop_repository.dart';
import 'order_list_page.dart';
import 'order_success_page.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    this.repository,
    this.useRemote = true,
  });

  final ShopProduct product;
  final ShopRepository? repository;
  final bool useRemote;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  late final ShopRepository _repo;
  late ShopProduct _product;
  ShopPaymentAsset? _selectedAsset;

  int _activeImageIndex = 0;
  bool _detailLoading = true;
  int _quantity = 1;

  late final PageController _imageController;

  ShopPaymentAsset? _defaultAsset(ShopProduct p) {
    if (p.meowPointsPrice != null) return ShopPaymentAsset.meowPoints;
    if (p.meowCreditPrice != null) return ShopPaymentAsset.meowCredit;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _product = widget.product;
    _selectedAsset = _defaultAsset(widget.product);
    _repo = widget.repository ??
        (widget.useRemote
            ? RemoteShopRepository(apiClient: ref.read(apiClientProvider))
            : const MockShopRepository());
    _loadDetail();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final ShopProduct full = await _repo.getProductDetail(_product.id);
      if (!mounted) return;
      setState(() {
        _product = full;
        _detailLoading = false;
        _selectedAsset = _defaultAsset(full);
      });
    } catch (e, st) {
      debugPrint('[ProductDetail] loadDetail error: $e\n$st');
      if (!mounted) return;
      setState(() => _detailLoading = false);
    }
  }

  List<String> get _images {
    final List<String> all = <String>[];
    final String? thumb = _product.thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) all.add(thumb);
    for (final String img in _product.images) {
      final String t = img.trim();
      if (t.isNotEmpty && !all.contains(t)) all.add(t);
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = _images;
    final bool isAuthenticated = ref.watch(authControllerProvider).isSignedIn;

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: Column(
        children: <Widget>[
          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                _buildImageSliver(context, images),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _PriceRow(
                          product: _product,
                          selectedAsset: _selectedAsset,
                          onSelect: (ShopPaymentAsset a) =>
                              setState(() => _selectedAsset = a),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _ProductTitle(name: _product.name),
                        const SizedBox(height: AppSpacing.sm),
                        _MetaRow(product: _product),
                        const SizedBox(height: AppSpacing.md),
                        _SectionDivider(),
                        const SizedBox(height: AppSpacing.md),
                        _DescriptionSection(
                          description: _product.description,
                          loading: _detailLoading,
                        ),
                        if (!_detailLoading && _product.specs.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          _SectionDivider(),
                          const SizedBox(height: AppSpacing.md),
                          _SpecsSection(specs: _product.specs),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _SectionDivider(),
                        const SizedBox(height: AppSpacing.md),
                        _QuantitySelector(
                          quantity: _quantity,
                          stock: _product.stock,
                          onChanged: (int v) => setState(() => _quantity = v),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _BuyBar(
            product: _product,
            repo: _repo,
            isAuthenticated: isAuthenticated,
            selectedAsset: _selectedAsset,
            quantity: _quantity,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSliver(BuildContext context, List<String> images) {
    return SliverAppBar(
      backgroundColor: AppColors.warmBackground,
      expandedHeight: 300,
      pinned: true,
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: const Center(child: _GlassIconButton(icon: Icons.arrow_back_rounded)),
      ),
      actions: <Widget>[
        _GlassCartMenuButton(repo: _repo),
        const SizedBox(width: AppSpacing.sm),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            images.isEmpty
                ? _ProductImagePlaceholder()
                : PageView.builder(
                    controller: _imageController,
                    itemCount: images.length,
                    onPageChanged: (int i) =>
                        setState(() => _activeImageIndex = i),
                    itemBuilder: (_, int i) =>
                        _ProductDetailImage(url: images[i]),
                  ),
            if (images.length > 1)
              Positioned(
                bottom: AppSpacing.sm,
                left: 0,
                right: 0,
                child: _ImageDots(
                  count: images.length,
                  activeIndex: _activeImageIndex,
                ),
              ),
            if (_product.badge != null)
              Positioned(
                top: AppSpacing.xl + AppSpacing.md,
                left: AppSpacing.sm,
                child: _BadgeChip(badge: _product.badge!),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info widgets
// ---------------------------------------------------------------------------

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.product,
    this.selectedAsset,
    this.onSelect,
  });

  final ShopProduct product;
  final ShopPaymentAsset? selectedAsset;
  final ValueChanged<ShopPaymentAsset>? onSelect;

  @override
  Widget build(BuildContext context) {
    final String? mp = product.meowPointsPrice;
    final String? mc = product.meowCreditPrice;

    if (mp == null && mc == null) {
      return _PriceChip(label: product.price, selected: true);
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        if (mp != null)
          _PriceChip(
            label: 'MeowPoints: $mp',
            selected: selectedAsset == ShopPaymentAsset.meowPoints,
            onTap: () => onSelect?.call(ShopPaymentAsset.meowPoints),
          ),
        if (mc != null)
          _PriceChip(
            label: 'MeowCredit: $mc',
            selected: selectedAsset == ShopPaymentAsset.meowCredit,
            onTap: () => onSelect?.call(ShopPaymentAsset.meowCredit),
          ),
      ],
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGold.withValues(alpha: 0.15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: selected ? AppColors.brandGold : AppColors.softBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected) ...<Widget>[
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandGold,
                size: 14,
              ),
              const SizedBox(width: AppSpacing.xxs),
            ],
            Text(
              label,
              style: AppTextStyles.sectionTitle.copyWith(
                color: selected ? AppColors.brandGold : AppColors.mutedOliveText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTitle extends StatelessWidget {
  const _ProductTitle({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: AppTextStyles.cardTitle.copyWith(fontSize: 18, height: 1.3),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = <String>[
      if (product.category != null) product.category!.name,
      '${product.soldCount} sold',
      product.stock > 0 ? '${product.stock} in stock' : 'Out of stock',
    ];
    return Text(
      parts.join('  ·  '),
      style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.softBorder);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        color: AppColors.mutedOliveText,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.description, required this.loading});
  final String? description;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(text: 'Description'),
        const SizedBox(height: AppSpacing.xs),
        if (loading)
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.mutedOliveText,
            ),
          )
        else
          Text(
            description?.trim().isNotEmpty == true
                ? description!.trim()
                : 'No description available.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.mutedOliveText,
              height: 1.6,
            ),
          ),
      ],
    );
  }
}

class _SpecsSection extends StatelessWidget {
  const _SpecsSection({required this.specs});
  final List<ShopProductSpec> specs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(text: 'Specifications'),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.softBorder),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: specs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, thickness: 1, color: AppColors.softBorder),
            itemBuilder: (_, int i) => _SpecRow(spec: specs[i]),
          ),
        ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.spec});
  final ShopProductSpec spec;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              spec.name,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              spec.value,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.cocoaText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buy bar
// ---------------------------------------------------------------------------

class _BuyBar extends ConsumerStatefulWidget {
  const _BuyBar({
    required this.product,
    required this.repo,
    required this.isAuthenticated,
    required this.selectedAsset,
    required this.quantity,
  });

  final ShopProduct product;
  final ShopRepository repo;
  final bool isAuthenticated;
  final ShopPaymentAsset? selectedAsset;
  final int quantity;

  @override
  ConsumerState<_BuyBar> createState() => _BuyBarState();
}

class _BuyBarState extends ConsumerState<_BuyBar> {
  bool _loading = false;

  Future<void> _buy(ShopPaymentAsset asset, {int? shippingAddressId}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final ShopOrder order = await widget.repo.createOrder(
        productId: widget.product.id,
        quantity: widget.quantity,
        paymentAsset: asset,
        shippingAddressId: shippingAddressId,
      );
      if (!mounted) return;
      // Navigate to the order success page, replacing the product detail page
      // so the back button on OrderSuccessPage returns directly to the shop.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessPage(
            order: order,
            product: widget.product,
            repo: widget.repo,
          ),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.cardBackground,
        ),
      );
    } catch (e, st) {
      debugPrint('[Buy] error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to place order. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _mpSufficient(double? balance) {
    final double? cost =
        double.tryParse(widget.product.meowPointsPrice ?? '');
    if (cost == null || balance == null) return true;
    return balance >= cost;
  }

  bool _mcSufficient(double? balance) {
    final double? cost =
        double.tryParse(widget.product.meowCreditPrice ?? '');
    if (cost == null || balance == null) return true;
    return balance >= cost;
  }

  Future<void> _confirmAndBuy(
    ShopPaymentAsset asset, {
    double? mpBalance,
    double? mcBalance,
  }) async {
    final _PurchaseResult? result = await showModalBottomSheet<_PurchaseResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PurchaseConfirmSheet(
        product: widget.product,
        asset: asset,
        mpBalance: mpBalance,
        mcBalance: mcBalance,
      ),
    );
    if (result == null || !result.confirmed || !mounted) return;
    await _buy(asset, shippingAddressId: result.shippingAddressId);
  }

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = widget.product.stock <= 0;
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm + MediaQuery.of(context).padding.bottom,
    );

    if (outOfStock) {
      return _BarShell(
        padding: padding,
        child: const _BuyButton(
          label: 'Out of Stock',
          onPressed: null,
          filled: false,
        ),
      );
    }

    if (!widget.isAuthenticated) {
      return _BarShell(
        padding: padding,
        child: _BuyButton(
          label: 'Sign in to Purchase',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to make a purchase.')),
          ),
          filled: true,
        ),
      );
    }

    final ShopPaymentAsset? asset = widget.selectedAsset;

    if (asset == null) {
      // Fiat-only product: MP/MC pricing not configured in the backend.
      return _BarShell(
        padding: padding,
        child: _BuyButton(
          label: 'Buy  ·  ${widget.product.price}',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Platform currency pricing not available for this product.',
              ),
            ),
          ),
          filled: true,
        ),
      );
    }

    final double? mpBalance = ref.watch(meowPointsWalletProvider).value?.balance;
    final double? mcBalance = ref.watch(meowCreditWalletProvider).value?.balance;

    final bool isMp = asset == ShopPaymentAsset.meowPoints;
    final bool ok = isMp ? _mpSufficient(mpBalance) : _mcSufficient(mcBalance);
    final String priceStr = isMp
        ? (widget.product.meowPointsPrice ?? '')
        : (widget.product.meowCreditPrice ?? '');
    final String unit = isMp ? 'MP' : 'MC';

    return _BarShell(
      padding: padding,
      child: _BuyButton(
        label: ok ? 'Buy with ${asset.displayName}' : 'Need $priceStr $unit',
        onPressed: (_loading || !ok)
            ? null
            : () => _confirmAndBuy(
                  asset,
                  mpBalance: mpBalance,
                  mcBalance: mcBalance,
                ),
        filled: true,
        loading: _loading,
      ),
    );
  }
}

class _BarShell extends StatelessWidget {
  const _BarShell({required this.padding, required this.child});
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      padding: padding,
      child: SizedBox(height: 48, child: child),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.label,
    required this.onPressed,
    required this.filled,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGold,
            foregroundColor: AppColors.warmBackground,
            disabledBackgroundColor: AppColors.softBorder,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: AppColors.cardBackground,
            foregroundColor: AppColors.brandGold,
            disabledBackgroundColor: AppColors.softBorder,
            elevation: 0,
            side: const BorderSide(color: AppColors.brandGold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          );

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled
                      ? AppColors.warmBackground
                      : AppColors.brandGold,
                ),
              )
            : Text(label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay controls (frosted glass)
// ---------------------------------------------------------------------------

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0x33000000),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Frosted glass cart button that also pops My Orders / My Addresses
// ---------------------------------------------------------------------------

class _GlassCartMenuButton extends StatelessWidget {
  const _GlassCartMenuButton({required this.repo});
  final ShopRepository repo;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColors.cardBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.softBorder),
      ),
      onSelected: (String value) {
        switch (value) {
          case 'orders':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrderListPage(repo: repo),
              ),
            );
          case 'addresses':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AddressListPage(),
              ),
            );
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        _menuItem('orders', Icons.receipt_long_outlined, 'My Orders'),
        _menuItem('addresses', Icons.location_on_outlined, 'My Addresses'),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: <Widget>[
              const Icon(Icons.shopping_cart_outlined,
                  size: 18, color: AppColors.mutedOliveText),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Cart  (coming soon)',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.mutedOliveText,
                ),
              ),
            ],
          ),
        ),
      ],
      // Cart glass icon is the visible trigger — no separate ⋮ button
      child: const _GlassIconButton(icon: Icons.shopping_cart_outlined),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.cocoaText),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.body.copyWith(color: AppColors.cocoaText)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image helpers
// ---------------------------------------------------------------------------

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});
  final String badge;

  @override
  Widget build(BuildContext context) {
    final bool isHighlight = badge == 'HOT' || badge == 'SALE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.brandGold
            : AppColors.cardBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Text(
        badge,
        style: AppTextStyles.caption.copyWith(
          color: isHighlight ? AppColors.warmBackground : AppColors.brandGold,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImageDots extends StatelessWidget {
  const _ImageDots({required this.count, required this.activeIndex});
  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final int selected = activeIndex.clamp(0, count - 1).toInt();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        count,
        (int i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == selected ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == selected ? AppColors.brandGold : AppColors.softBorder,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailImage extends StatelessWidget {
  const _ProductDetailImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return AppCachedImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, __) => _ProductImagePlaceholder(),
      errorWidget: (_, __, ___) => _ProductImagePlaceholder(),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF332E27),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: AppColors.mutedOliveText,
          size: 60,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase result — carries confirmed flag + chosen address id
// ---------------------------------------------------------------------------

class _PurchaseResult {
  const _PurchaseResult({required this.confirmed, this.shippingAddressId});
  final bool confirmed;
  final int? shippingAddressId;
}

// ---------------------------------------------------------------------------
// Purchase confirmation sheet (with address selection)
// ---------------------------------------------------------------------------

class _PurchaseConfirmSheet extends ConsumerStatefulWidget {
  const _PurchaseConfirmSheet({
    required this.product,
    required this.asset,
    this.mpBalance,
    this.mcBalance,
  });

  final ShopProduct product;
  final ShopPaymentAsset asset;
  final double? mpBalance;
  final double? mcBalance;

  @override
  ConsumerState<_PurchaseConfirmSheet> createState() =>
      _PurchaseConfirmSheetState();
}

class _PurchaseConfirmSheetState
    extends ConsumerState<_PurchaseConfirmSheet> {
  ShippingAddress? _selectedAddress;
  bool _addressLoaded = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with the user's default address once the provider resolves.
    ref.listenManual<AsyncValue<ShippingAddress?>>(
      defaultShippingAddressProvider,
      (_, AsyncValue<ShippingAddress?> next) {
        if (!_addressLoaded && next is AsyncData<ShippingAddress?>) {
          _addressLoaded = true;
          if (mounted) setState(() => _selectedAddress = next.value);
        }
      },
      fireImmediately: true,
    );
  }

  String get _priceStr => widget.asset == ShopPaymentAsset.meowPoints
      ? '${widget.product.meowPointsPrice} MP'
      : '${widget.product.meowCreditPrice} MC';

  String get _balanceStr {
    if (widget.asset == ShopPaymentAsset.meowPoints) {
      return widget.mpBalance != null
          ? '${_fmtBal(widget.mpBalance!)} MP'
          : '—';
    }
    return widget.mcBalance != null
        ? '${_fmtBal(widget.mcBalance!)} MC'
        : '—';
  }

  static String _fmtBal(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _changeAddress() async {
    final ShippingAddress? result =
        await Navigator.of(context).push<ShippingAddress>(
      MaterialPageRoute<ShippingAddress>(
        builder: (_) => AddressListPage(
          selectionMode: true,
          selectedId: _selectedAddress?.id,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedAddress = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.softBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Confirm Purchase',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),

            // Order rows
            _ConfirmRow(label: 'Product', value: widget.product.name),
            _ConfirmRow(label: 'Payment', value: widget.asset.displayName),
            _ConfirmRow(label: 'Amount', value: _priceStr),
            _ConfirmRow(label: 'Balance', value: _balanceStr),

            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.softBorder),
            const SizedBox(height: AppSpacing.sm),

            // Address row
            _AddressRow(
              address: _selectedAddress,
              loading: !_addressLoaded,
              onTap: _changeAddress,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context)
                          .pop(const _PurchaseResult(confirmed: false)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.softBorder),
                        foregroundColor: AppColors.cocoaText,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        _PurchaseResult(
                          confirmed: true,
                          shippingAddressId: _selectedAddress?.id,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGold,
                        foregroundColor: AppColors.warmBackground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        textStyle: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Address row inside the confirmation sheet
// ---------------------------------------------------------------------------

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.loading,
    required this.onTap,
  });

  final ShippingAddress? address;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.brandGold,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.mutedOliveText,
                    ),
                  )
                : address == null
                    ? Text(
                        'No address selected  ›',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.brandGold,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                '${address!.receiverName}  ${address!.phone}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.cocoaText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Change  ›',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.brandGold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            address!.oneLine,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.mutedOliveText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
              style: AppTextStyles.caption.copyWith(
                color: AppColors.cocoaText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quantity Selector ─────────────────────────────────────────────────────────

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.stock,
    required this.onChanged,
  });

  final int quantity;
  final int stock;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text('Quantity', style: AppTextStyles.caption.copyWith(color: AppColors.cocoaText)),
        const Spacer(),
        _QtyButton(
          icon: Icons.remove,
          enabled: quantity > 1,
          onTap: () => onChanged(quantity - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            '$quantity',
            style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
          ),
        ),
        _QtyButton(
          icon: Icons.add,
          enabled: stock <= 0 || quantity < stock,
          onTap: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.brandGold.withValues(alpha: 0.15)
              : AppColors.mutedOliveText.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.brandGold : AppColors.mutedOliveText,
        ),
      ),
    );
  }
}
