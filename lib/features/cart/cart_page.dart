import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../shop/domain/shop_models.dart';
import '../shop/product_detail_page.dart';
import 'application/cart_providers.dart';
import 'domain/cart_models.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CartItem>> cartAsync =
        ref.watch(cartNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CartTopBar(),
            Expanded(
              child: cartAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandGold,
                    strokeWidth: 2,
                  ),
                ),
                error: (_, __) => _CartErrorState(
                  onRetry: () =>
                      ref.invalidate(cartNotifierProvider),
                ),
                data: (List<CartItem> items) => items.isEmpty
                    ? const _CartEmptyState()
                    : _CartList(items: items),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _CartTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
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
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Saved Products',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class _CartList extends ConsumerWidget {
  const _CartList({required this.items});
  final List<CartItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, int i) => _CartItemCard(item: items[i]),
    );
  }
}

// ---------------------------------------------------------------------------
// Item card
// ---------------------------------------------------------------------------

class _CartItemCard extends ConsumerStatefulWidget {
  const _CartItemCard({required this.item});
  final CartItem item;

  @override
  ConsumerState<_CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends ConsumerState<_CartItemCard> {
  bool _removing = false;

  Future<void> _remove() async {
    if (_removing) return;
    setState(() => _removing = true);
    final bool ok = await ref
        .read(cartNotifierProvider.notifier)
        .removeItem(widget.item.id);
    if (!ok && mounted) {
      setState(() => _removing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove. Please try again.')),
      );
    }
  }

  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailPage(product: widget.item.product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ShopProduct p = widget.item.product;
    final String? mp = p.meowPointsPrice;
    final String? mc = p.meowCreditPrice;

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _CartThumbnail(imageUrl: p.thumbnailUrl, badge: p.badge),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.cocoaText,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (mp != null)
                      Text(
                        '$mp MP',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.brandGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      )
                    else if (mc != null)
                      Text(
                        '$mc MC',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.brandGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    if (mc != null && mp != null)
                      Text(
                        '$mc MC',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mutedOliveText,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      p.stock > 0 ? '${p.stock} in stock' : 'Out of stock',
                      style: AppTextStyles.caption.copyWith(
                        color: p.stock > 0
                            ? AppColors.mutedOliveText
                            : AppColors.brandGold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _removing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.mutedOliveText,
                      ),
                    )
                  : GestureDetector(
                      onTap: _remove,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.mutedOliveText,
                        size: 20,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartThumbnail extends StatelessWidget {
  const _CartThumbnail({this.imageUrl, this.badge});
  final String? imageUrl;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(AppSpacing.radiusMd),
      ),
      child: SizedBox(
        width: 80,
        height: 80,
        child: url == null || url.isEmpty
            ? Container(
                color: const Color(0xFF332E27),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.mutedOliveText,
                  size: 28,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF332E27),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.mutedOliveText,
                    size: 28,
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error states
// ---------------------------------------------------------------------------

class _CartEmptyState extends StatelessWidget {
  const _CartEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.mutedOliveText,
            size: 56,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No saved products yet',
            style: AppTextStyles.body.copyWith(color: AppColors.cocoaText),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap "Add to Cart" on any product to save it here.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedOliveText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CartErrorState extends StatelessWidget {
  const _CartErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Failed to load cart.',
            style: AppTextStyles.body.copyWith(color: AppColors.mutedOliveText),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
            ),
          ),
        ],
      ),
    );
  }
}
