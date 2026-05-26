part of '../home_page.dart';

class _SearchPill extends StatelessWidget {
  const _SearchPill();

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
            child: Text(
              'Search videos, dramas, live topics',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTopRow extends StatelessWidget {
  const _HomeTopRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(AppAssets.meowLogo, width: 28, height: 28),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: _SearchPill()),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ShopPage()),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.cocoaText,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.add_circle, color: AppColors.brandGold, size: 26),
      ],
    );
  }
}

class _ChannelNav extends StatelessWidget {
  const _ChannelNav({
    required this.channels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> channels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, int i) {
          final bool selected = i == selectedIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(i),
            child: Center(
              child: Text(
                channels[i],
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.brandGold : AppColors.cocoaText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.cocoaText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(hint, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}
