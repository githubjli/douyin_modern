part of '../shop_page.dart';

class _ShopBannerCarousel extends StatelessWidget {
  const _ShopBannerCarousel({
    required this.banners,
    required this.controller,
    required this.onPageChanged,
  });

  final List<ShopBanner> banners;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: PageView.builder(
        controller: controller,
        itemCount: banners.length,
        onPageChanged: onPageChanged,
        itemBuilder: (_, int index) {
          final ShopBanner banner = banners[index];
          return _ShopBannerCard(banner: banner);
        },
      ),
    );
  }
}

class _ShopBannerCard extends StatelessWidget {
  const _ShopBannerCard({required this.banner});

  final ShopBanner banner;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _ShopBannerCover(imageUrl: banner.imageUrl),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x0D000000),
                  Color(0x55000000),
                  Color(0xB3000000),
                ],
                stops: <double>[0.2, 0.6, 1],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xs,
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  banner.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
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

class _ShopBannerCover extends StatelessWidget {
  const _ShopBannerCover({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _ShopBannerPlaceholder();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _ShopBannerPlaceholder(),
      loadingBuilder: (_, Widget child, ImageChunkEvent? progress) =>
          progress == null ? child : _ShopBannerPlaceholder(),
    );
  }
}

class _ShopBannerPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3B2E1A), Color(0xFF1F1A12)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_outlined,
          color: AppColors.mutedOliveText,
          size: 40,
        ),
      ),
    );
  }
}

class _ShopBannerDots extends StatelessWidget {
  const _ShopBannerDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final int selected = count == 0 ? 0 : activeIndex.clamp(0, count - 1).toInt();
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
