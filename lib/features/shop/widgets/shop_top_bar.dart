part of '../shop_page.dart';

class _ShopTopBar extends StatelessWidget {
  const _ShopTopBar({
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
    required this.onCartTap,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchCleared;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.only(right: AppSpacing.xs),
            child: Icon(
              Icons.arrow_back_ios,
              color: AppColors.cocoaText,
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: _ShopSearchBar(
            controller: searchController,
            onSubmitted: onSearchSubmitted,
            onCleared: onSearchCleared,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: onCartTap,
          child: const Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.cocoaText,
            size: 24,
          ),
        ),
      ],
    );
  }
}

class _ShopSearchBar extends StatefulWidget {
  const _ShopSearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onCleared,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback onCleared;

  @override
  State<_ShopSearchBar> createState() => _ShopSearchBarState();
}

class _ShopSearchBarState extends State<_ShopSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, color: AppColors.mutedOliveText, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: widget.controller,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.cocoaText,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Search products',
                hintStyle: AppTextStyles.caption.copyWith(fontSize: 10),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onSubmitted(),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              onTap: widget.onCleared,
              child: const Icon(
                Icons.close,
                color: AppColors.mutedOliveText,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}
