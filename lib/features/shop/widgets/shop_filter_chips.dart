part of '../shop_page.dart';

class _ShopCategoryChips extends StatelessWidget {
  const _ShopCategoryChips({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ShopCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, int index) {
          final bool selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(categories[index].name),
            selected: selected,
            onSelected: (_) => onSelected(index),
            selectedColor: AppColors.brandGold,
            backgroundColor: AppColors.cardBackground,
            side: const BorderSide(color: AppColors.softBorder),
            labelStyle: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.warmBackground : AppColors.cocoaText,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
