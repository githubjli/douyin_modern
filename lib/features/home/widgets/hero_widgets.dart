part of '../home_page.dart';

class _NewsHeroCarousel extends StatelessWidget {
  const _NewsHeroCarousel({
    required this.items,
    required this.controller,
    required this.onPageChanged,
    this.videoRecommendations = const <HomeVideoItem>[],
  });

  final List<dynamic> items;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final List<HomeVideoItem> videoRecommendations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: PageView.builder(
        controller: controller,
        itemCount: items.length,
        onPageChanged: onPageChanged,
        itemBuilder: (_, int index) {
          final dynamic selectedItem = items[index];
          VoidCallback? onTap;
          if (selectedItem is HomeLiveItem) {
            onTap = () => _openLiveItem(context, selectedItem);
          } else if (selectedItem is HomeVideoItem) {
            onTap = () =>
                _openVideoDetail(context, selectedItem, videoRecommendations);
          }
          return _PortalCard(
            title: _newsTitle(selectedItem),
            subtitle: selectedItem == null
                ? 'No news content yet'
                : _newsMetadata(selectedItem),
            imageUrl:
                selectedItem == null ? null : _resolveImageUrl(selectedItem),
            kind: selectedItem is HomeLiveItem
                ? _CardKind.live
                : _CardKind.video,
            badgeOverride: selectedItem == null
                ? 'News'
                : _newsHeroBadgeLabel(selectedItem),
            compactOverlay: true,
            onTap: onTap,
          );
        },
      ),
    );
  }
}

class _DramaChannelHero extends StatelessWidget {
  const _DramaChannelHero({required this.drama});

  final HomeDramaItem? drama;

  @override
  Widget build(BuildContext context) {
    final HomeDramaItem? selectedDrama = drama;
    return SizedBox(
      height: 176,
      child: _PortalCard(
        title: selectedDrama?.title ?? 'Short Drama',
        subtitle: selectedDrama == null
            ? 'Discover bite-size drama stories'
            : _dramaMetadata(selectedDrama),
        imageUrl:
            selectedDrama == null ? null : _resolveImageUrl(selectedDrama),
        kind: _CardKind.drama,
        compactOverlay: true,
        onTap: selectedDrama == null
            ? null
            : () => _openDramaDetail(context, selectedDrama),
      ),
    );
  }
}

class _LiveChannelHero extends StatelessWidget {
  const _LiveChannelHero({required this.item});

  final HomeLiveItem? item;

  @override
  Widget build(BuildContext context) {
    final HomeLiveItem? selectedItem = item;
    return SizedBox(
      height: 176,
      child: _PortalCard(
        title: selectedItem?.title ?? 'Live',
        subtitle: selectedItem == null
            ? 'Live discovery is coming soon'
            : _liveMetadata(selectedItem),
        imageUrl: selectedItem == null ? null : _resolveImageUrl(selectedItem),
        kind: _CardKind.live,
        badgeOverride:
            selectedItem == null ? 'Ready' : _liveBadgeLabel(selectedItem),
        compactOverlay: true,
        onTap: selectedItem == null
            ? null
            : () => _openLiveItem(context, selectedItem),
      ),
    );
  }
}

class _VideoChannelHero extends StatelessWidget {
  const _VideoChannelHero({required this.video, this.recommendations = const <HomeVideoItem>[]});

  final HomeVideoItem video;
  final List<HomeVideoItem> recommendations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: _PortalCard(
        title: video.title,
        subtitle: _videoHeroMetadata(video),
        imageUrl: video.thumbnailUrl,
        kind: _CardKind.video,
        compactOverlay: true,
        onTap: () => _openVideoDetail(context, video, recommendations),
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.items,
    required this.controller,
    required this.onPageChanged,
    required this.onDramaTap,
    this.onVideoTap,
  });

  final List<dynamic> items;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<HomeDramaItem> onDramaTap;
  final ValueChanged<HomeVideoItem>? onVideoTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: PageView.builder(
        controller: controller,
        itemCount: items.length,
        onPageChanged: onPageChanged,
        itemBuilder: (_, int index) {
          final dynamic item = items[index];
          final _CardKind kind =
              item is HomeDramaItem ? _CardKind.drama : _CardKind.video;
          VoidCallback? onTap;
          if (item is HomeDramaItem) {
            onTap = () => onDramaTap(item);
          } else if (item is HomeVideoItem) {
            onTap = onVideoTap != null ? () => onVideoTap!(item) : null;
          }
          return _PortalCard(
            title: item?.title as String? ?? 'Featured Picks',
            subtitle:
                item?.subtitle as String? ?? 'Drama and video recommendations',
            imageUrl: _resolveImageUrl(item),
            kind: kind,
            compactOverlay: true,
            onTap: onTap,
          );
        },
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final int selectedIndex =
        count == 0 ? 0 : activeIndex.clamp(0, count - 1).toInt();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        count,
        (int i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == selectedIndex ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            color:
                i == selectedIndex ? AppColors.brandGold : AppColors.softBorder,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}
