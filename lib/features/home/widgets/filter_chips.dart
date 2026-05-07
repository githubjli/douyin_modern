part of '../home_page.dart';

class _NewsFilterChips extends StatelessWidget {
  const _NewsFilterChips({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _newsFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, int index) {
          final bool selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(_newsFilters[index]),
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

class _DramaFilterChips extends StatelessWidget {
  const _DramaFilterChips({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dramaFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, int index) {
          final bool selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(_dramaFilters[index]),
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

class _LiveFilterChips extends StatelessWidget {
  const _LiveFilterChips({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _liveFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, int index) {
          final bool selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(_liveFilters[index]),
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

class _VideoCategoryChips extends StatelessWidget {
  const _VideoCategoryChips({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> categories;
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
            label: Text(categories[index]),
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
