part of '../shop_page.dart';

enum _ShopMenuAction { orders, addresses }

class _ShopTopBar extends StatelessWidget {
  const _ShopTopBar({
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
    required this.onCartTap,
    required this.onMenuSelected,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchCleared;
  final VoidCallback onCartTap;
  final ValueChanged<_ShopMenuAction> onMenuSelected;

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
        // Cart icon
        GestureDetector(
          onTap: onCartTap,
          child: const Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.cocoaText,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        // ⋮ popup menu
        PopupMenuButton<_ShopMenuAction>(
          onSelected: onMenuSelected,
          color: AppColors.cardBackground,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.softBorder),
          ),
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.cocoaText,
            size: 22,
          ),
          itemBuilder: (_) => <PopupMenuEntry<_ShopMenuAction>>[
            PopupMenuItem<_ShopMenuAction>(
              value: _ShopMenuAction.orders,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.cocoaText,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'My Orders',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.cocoaText,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<_ShopMenuAction>(
              value: _ShopMenuAction.addresses,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.cocoaText,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'My Addresses',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.cocoaText,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
