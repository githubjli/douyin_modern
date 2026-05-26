part of '../home_page.dart';

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.items,
    required this.kind,
    this.useDramaMetadata = false,
    this.useLiveMetadata = false,
    this.useNewsMetadata = false,
    this.videoRecommendations = const <HomeVideoItem>[],
  });

  final List<dynamic> items;
  final _CardKind kind;
  final bool useDramaMetadata;
  final bool useLiveMetadata;
  final bool useNewsMetadata;
  final List<HomeVideoItem> videoRecommendations;

  @override
  Widget build(BuildContext context) {
    final double ratio = switch (kind) {
      _CardKind.drama => 0.68,
      _ => 0.8,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: ratio * 0.75,
      ),
      itemBuilder: (_, int index) {
        final dynamic item = items[index];
        return _PortalCard(
          title: item.title as String,
          subtitle: useDramaMetadata && item is HomeDramaItem
              ? _dramaMetadata(item)
              : useLiveMetadata && item is HomeLiveItem
                  ? _liveMetadata(item)
                  : useNewsMetadata
                      ? _newsMetadata(item)
                      : item.subtitle as String,
          imageUrl: _resolveImageUrl(item),
          kind: _cardKindFor(item, kind),
          badgeOverride: _badgeOverrideForItem(
            item,
            useLiveMetadata: useLiveMetadata,
            useNewsMetadata: useNewsMetadata,
          ),
          onTap: item is HomeDramaItem
              ? () => _openDramaDetail(context, item)
              : item is HomeVideoItem
                  ? () => _openVideoDetail(context, item, videoRecommendations)
                  : item is HomeLiveItem
                      ? () => _openLiveItem(context, item)
                      : null,
        );
      },
    );
  }
}
