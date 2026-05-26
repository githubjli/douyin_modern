import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'domain/shop_models.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final ShopProduct product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _activeImageIndex = 0;
  late final PageController _imageController;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  List<String> get _images {
    final List<String> all = <String>[];
    if (widget.product.thumbnailUrl?.trim().isNotEmpty == true) {
      all.add(widget.product.thumbnailUrl!.trim());
    }
    for (final String img in widget.product.images) {
      if (img.trim().isNotEmpty && !all.contains(img.trim())) {
        all.add(img.trim());
      }
    }
    return all.isEmpty ? const <String>[] : all;
  }

  @override
  Widget build(BuildContext context) {
    final ShopProduct product = widget.product;
    final List<String> images = _images;

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: Column(
        children: <Widget>[
          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                _buildAppBar(context, images),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _PriceRow(product: product),
                        const SizedBox(height: AppSpacing.xs),
                        _ProductName(product: product),
                        const SizedBox(height: AppSpacing.sm),
                        _MetaRow(product: product),
                        const SizedBox(height: AppSpacing.md),
                        _Divider(),
                        const SizedBox(height: AppSpacing.md),
                        _DescriptionSection(product: product),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _AddToCartBar(product: product),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, List<String> images) {
    return SliverAppBar(
      backgroundColor: AppColors.warmBackground,
      expandedHeight: 300,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.cocoaText, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.cocoaText, size: 24),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cart coming soon.')),
          ),
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
                    itemBuilder: (_, int i) => _ProductDetailImage(url: images[i]),
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
            if (product.badge != null)
              Positioned(
                top: AppSpacing.xl + AppSpacing.md,
                left: AppSpacing.sm,
                child: _BadgeChip(badge: product.badge!),
              ),
          ],
        ),
      ),
    );
  }

  ShopProduct get product => widget.product;
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          '\$${product.price}',
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.brandGold,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (product.originalPrice != null) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '\$${product.originalPrice}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
              fontSize: 14,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.mutedOliveText,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductName extends StatelessWidget {
  const _ProductName({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    return Text(
      product.name,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 18,
        height: 1.3,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final StringBuffer meta = StringBuffer();
    if (product.category != null) meta.write(product.category!.name);
    if (product.category != null) meta.write('  ·  ');
    meta.write('${product.soldCount} sold');
    if (product.stock > 0) {
      meta.write('  ·  ${product.stock} in stock');
    } else {
      meta.write('  ·  Out of stock');
    }
    return Text(
      meta.toString(),
      style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.softBorder);
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Description',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.cocoaText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          product.description?.trim().isNotEmpty == true
              ? product.description!
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

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({required this.product});
  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = product.stock <= 0;
    return Container(
      color: AppColors.cardBackground,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: outOfStock
              ? null
              : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cart coming soon.')),
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGold,
            foregroundColor: AppColors.warmBackground,
            disabledBackgroundColor: AppColors.softBorder,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
          child: Text(outOfStock ? 'Out of Stock' : 'Add to Cart'),
        ),
      ),
    );
  }
}

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
      children: List<Widget>.generate(count, (int i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: i == selected ? 12 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: i == selected ? AppColors.brandGold : AppColors.softBorder,
          borderRadius: BorderRadius.circular(99),
        ),
      )),
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
        child: Icon(Icons.inventory_2_outlined, color: AppColors.mutedOliveText, size: 60),
      ),
    );
  }
}
