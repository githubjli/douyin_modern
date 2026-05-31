import 'package:meow_media/app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'data/cart_repository.dart';
import 'domain/shop_models.dart';
import 'product_detail_page.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  bool _removing = false;

  Future<void> _remove(CartItem item) async {
    setState(() => _removing = true);
    try {
      await ref.read(cartRepositoryProvider).removeItem(item.id);
      ref.invalidate(cartItemsProvider);
      ref.invalidate(cartCountProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  void _openProduct(ShopProduct product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailPage(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CartItem>> itemsAsync = ref.watch(cartItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: Text('Saved Items', style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
      ),
      body: itemsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.brandGold)),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(e.toString(), style: AppTextStyles.caption, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(cartItemsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (List<CartItem> items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.favorite_border, size: 64, color: AppColors.mutedOliveText),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No saved items',
                    style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: <Widget>[
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(cartItemsProvider);
                  await ref.read(cartItemsProvider.future);
                },
                color: AppColors.brandGold,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, int i) => _CartTile(
                    item: items[i],
                    onTap: () => _openProduct(items[i].product),
                    onRemove: () => _remove(items[i]),
                  ),
                ),
              ),
              if (_removing)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.brandGold),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ShopProduct p = item.product;
    final String price = p.meowPointsPrice != null
        ? '${p.meowPointsPrice} MP'
        : p.meowCreditPrice != null
            ? '${p.meowCreditPrice} MC'
            : p.price;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            if (p.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppCachedImage(
                  imageUrl: p.thumbnailUrl!,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.warmBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.mutedOliveText),
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    p.name,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
                  ),
                  Text(
                    p.stock > 0 ? 'In stock' : 'Out of stock',
                    style: AppTextStyles.caption.copyWith(
                      color: p.stock > 0 ? Colors.green : Colors.red,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite, color: AppColors.brandGold, size: 22),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}
