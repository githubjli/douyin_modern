import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_error.dart';
import '../auth/application/auth_providers.dart';
import '../cart/application/cart_providers.dart';
import '../cart/cart_page.dart';
import 'data/mock_shop_repository.dart';
import 'data/remote_shop_repository.dart';
import 'domain/shop_models.dart';
import 'domain/shop_order_models.dart';
import 'domain/shop_repository.dart';

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

  int _activeImageIndex = 0;
  bool _detailLoading = true;

  late final PageController _imageController;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _product = widget.product;
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
      });
    } catch (_) {
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
                        _PriceRow(product: _product),
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
            widgetRef: ref,
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
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.54),
                border: Border.all(color: AppColors.softBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.brandGold,
                size: 18,
              ),
            ),
          ),
        ),
      ),
      actions: <Widget>[
        Consumer(
          builder: (_, WidgetRef ref, __) {
            final int count = ref
                .watch(cartCountProvider)
                .maybeWhen(data: (int n) => n, orElse: () => 0);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CartPage()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.cocoaText,
                      size: 24,
                    ),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppColors.brandGold,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            count > 99 ? '99' : '$count',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warmBackground,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
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
  const _PriceRow({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final String? mp = product.meowPointsPrice;
    final String? mc = product.meowCreditPrice;

    if (mp == null && mc == null) {
      return Text(
        product.price,
        style: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.brandGold,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        if (mp != null)
          _PriceChip(label: '$mp MP', primary: true),
        if (mc != null)
          _PriceChip(label: '$mc MC', primary: mp == null),
      ],
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label, required this.primary});
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: primary
            ? AppColors.brandGold.withValues(alpha: 0.15)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: primary ? AppColors.brandGold : AppColors.softBorder,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.sectionTitle.copyWith(
          color: primary ? AppColors.brandGold : AppColors.cocoaText,
          fontSize: primary ? 22 : 16,
          fontWeight: FontWeight.w700,
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

class _BuyBar extends StatefulWidget {
  const _BuyBar({
    required this.product,
    required this.repo,
    required this.isAuthenticated,
    required this.widgetRef,
  });

  final ShopProduct product;
  final ShopRepository repo;
  final bool isAuthenticated;
  final WidgetRef widgetRef;

  @override
  State<_BuyBar> createState() => _BuyBarState();
}

class _BuyBarState extends State<_BuyBar> {
  bool _loading = false;
  bool _savingToCart = false;

  Future<void> _addToCart() async {
    if (_savingToCart) return;
    setState(() => _savingToCart = true);
    try {
      final bool ok = await widget.widgetRef
          .read(cartNotifierProvider.notifier)
          .addItem(widget.product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Saved to cart!' : 'Failed to save. Please try again.'),
          backgroundColor: AppColors.cardBackground,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingToCart = false);
    }
  }

  Future<void> _buy(ShopPaymentAsset asset) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final ShopOrder order = await widget.repo.createOrder(
        productId: widget.product.id,
        quantity: 1,
        paymentAsset: asset,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order #${order.orderNo} placed! ${order.statusText}.',
          ),
          backgroundColor: AppColors.cardBackground,
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to place order. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = widget.product.stock <= 0;
    final String? mp = widget.product.meowPointsPrice;
    final String? mc = widget.product.meowCreditPrice;
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

    final bool hasMp = mp != null;
    final bool hasMc = mc != null;
    final bool hasBuyOption = hasMp || hasMc;

    Widget? buyRow;
    if (hasMp && hasMc) {
      buyRow = Row(
        children: <Widget>[
          Expanded(
            child: _BuyButton(
              label: '$mp MP',
              onPressed: _loading ? null : () => _buy(ShopPaymentAsset.meowPoints),
              filled: true,
              loading: _loading,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _BuyButton(
              label: '$mc MC',
              onPressed: _loading ? null : () => _buy(ShopPaymentAsset.meowCredit),
              filled: false,
            ),
          ),
        ],
      );
    } else if (hasMp) {
      buyRow = _BuyButton(
        label: 'Buy  ·  $mp MP',
        onPressed: _loading ? null : () => _buy(ShopPaymentAsset.meowPoints),
        filled: true,
        loading: _loading,
      );
    } else if (hasMc) {
      buyRow = _BuyButton(
        label: 'Buy  ·  $mc MC',
        onPressed: _loading ? null : () => _buy(ShopPaymentAsset.meowCredit),
        filled: true,
        loading: _loading,
      );
    }

    if (!hasBuyOption) return const SizedBox.shrink();

    return Container(
      color: AppColors.cardBackground,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 40,
            width: double.infinity,
            child: _BuyButton(
              label: 'Add to Cart',
              onPressed: _savingToCart ? null : _addToCart,
              filled: false,
              loading: _savingToCart,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(height: 48, child: buyRow),
        ],
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
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _ProductImagePlaceholder(),
      loadingBuilder: (_, Widget child, ImageChunkEvent? progress) =>
          progress == null ? child : _ProductImagePlaceholder(),
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
