part of '../shop_page.dart';

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, this.onTap});

  final ShopProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          color: AppColors.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ProductCover(imageUrl: product.thumbnailUrl),
                    if (product.badge != null)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: product.badge == 'HOT' || product.badge == 'SALE'
                                ? AppColors.brandGold
                                : AppColors.cardBackground.withValues(alpha: 0.85),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(color: AppColors.softBorder),
                          ),
                          child: Text(
                            product.badge!,
                            style: AppTextStyles.caption.copyWith(
                              color: product.badge == 'HOT' || product.badge == 'SALE'
                                  ? AppColors.warmBackground
                                  : AppColors.brandGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.cocoaText,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            '\$${product.price}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.brandGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (product.originalPrice != null) ...<Widget>[
                            const SizedBox(width: 4),
                            Text(
                              '\$${product.originalPrice}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mutedOliveText,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.mutedOliveText,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.soldCount} sold',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mutedOliveText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCover extends StatelessWidget {
  const _ProductCover({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _ProductCoverPlaceholder();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _ProductCoverPlaceholder(),
      loadingBuilder: (_, Widget child, ImageChunkEvent? progress) =>
          progress == null ? child : _ProductCoverPlaceholder(),
    );
  }
}

class _ProductCoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF332E27),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: AppColors.mutedOliveText,
          size: 28,
        ),
      ),
    );
  }
}
