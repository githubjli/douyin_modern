part of '../shop_page.dart';

enum _ShopMenuAction { orders, addresses, cart }

class _ShopTopBar extends StatelessWidget {
  const _ShopTopBar({
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
    required this.onMenuSelected,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchCleared;
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
        // Cart icon with badge — tap opens popup
        Consumer(
          builder: (BuildContext ctx, WidgetRef ref, _) {
            final int count =
                ref.watch(cartCountProvider).asData?.value ?? 0;
            return PopupMenuButton<_ShopMenuAction>(
              onSelected: onMenuSelected,
              color: AppColors.cardBackground,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                side: const BorderSide(color: AppColors.softBorder),
              ),
              child: Badge(
                isLabelVisible: count > 0,
                label: Text('$count', style: const TextStyle(fontSize: 10)),
                backgroundColor: AppColors.brandGold,
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.cocoaText,
                  size: 24,
                ),
              ),
              itemBuilder: (_) => <PopupMenuEntry<_ShopMenuAction>>[
                _menuItem(
                  _ShopMenuAction.orders,
                  Icons.receipt_long_outlined,
                  'My Orders',
                ),
                _menuItem(
                  _ShopMenuAction.addresses,
                  Icons.location_on_outlined,
                  'My Addresses',
                ),
                const PopupMenuDivider(),
                _menuItem(
                  _ShopMenuAction.cart,
                  Icons.favorite_outline,
                  count > 0 ? 'Saved Items ($count)' : 'Saved Items',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  PopupMenuItem<_ShopMenuAction> _menuItem(
    _ShopMenuAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<_ShopMenuAction>(
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
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Search products',
                hintStyle: AppTextStyles.caption.copyWith(
                  color: AppColors.mutedOliveText,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                // Fill the full 38px container height:
                // 38 - border(2) - icon/row centering ≈ 10px vertical padding each side
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
