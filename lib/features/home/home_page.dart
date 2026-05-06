import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_assets.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../drama_detail/drama_detail_page.dart';
import 'data/mock_home_repository.dart';
import 'data/remote_home_repository.dart';
import 'domain/home_models.dart';
import 'domain/home_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.useRemote = true,
    this.remoteRepository,
    this.mockRepository = const MockHomeRepository(),
  });

  final bool useRemote;
  final HomeRepository? remoteRepository;
  final HomeRepository mockRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeRepository _remoteRepo;
  final PageController _heroController = PageController();
  HomePortalData? _data;
  bool _loading = true;
  String? _notice;
  int _activeHeroIndex = 0;
  int _selectedChannelIndex = 0;
  int _selectedVideoCategoryIndex = 0;
  int _selectedDramaFilterIndex = 0;
  List<HomeVideoItem>? _videoItems;
  List<HomeVideoItem>? _categoryVideoItems;
  String? _videosNextUrl;
  String? _categoryVideosNextUrl;
  String? _selectedVideoCategoryQuery;
  bool _loadingMoreVideos = false;
  bool _loadingVideoCategory = false;

  static const List<String> _channels = <String>[
    'Home',
    'Videos',
    'Short Drama',
    'Live',
    'Shop',
  ];

  @override
  void initState() {
    super.initState();
    _remoteRepo =
        widget.remoteRepository ?? RemoteHomeRepository(apiClient: ApiClient());
    _load();
  }

  Future<void> _load() async {
    HomePortalData? portal;
    if (widget.useRemote) {
      try {
        portal = await _remoteRepo.getHomePortalData();
        if (_isEmpty(portal)) {
          _notice = 'Showing local content.';
        }
      } catch (_) {
        _notice = 'Network unavailable. Showing local content.';
      }
    }

    portal ??= await widget.mockRepository.getHomePortalData();
    final HomePortalData loadedPortal = portal;
    if (!mounted) return;
    setState(() {
      _data = loadedPortal;
      _videoItems = loadedPortal.latestVideos;
      _videosNextUrl = loadedPortal.videosNextUrl;
      _categoryVideoItems = null;
      _categoryVideosNextUrl = null;
      _selectedVideoCategoryIndex = 0;
      _selectedVideoCategoryQuery = null;
      _loading = false;
    });
  }

  bool _isEmpty(HomePortalData p) =>
      p.latestVideos.isEmpty && p.shortDrama.isEmpty && p.liveNow.isEmpty;

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final HomePortalData? data = _data;
    if (_loading || data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<dynamic> heroItems = _heroItemsFor(data);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const _HomeTopRow(),
          const SizedBox(height: AppSpacing.md),
          _ChannelNav(
            channels: _channels,
            selectedIndex: _selectedChannelIndex,
            onSelected: (int index) {
              setState(() => _selectedChannelIndex = index);
            },
          ),
          if (_notice != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_notice!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          ..._channelContent(data, heroItems),
        ],
      ),
    );
  }

  List<Widget> _channelContent(HomePortalData data, List<dynamic> heroItems) {
    return switch (_selectedChannelIndex) {
      1 => _videoChannelContent(data),
      2 => _dramaChannelContent(data),
      3 => <Widget>[
          const _SectionHeader(title: 'Live', hint: 'Live'),
          const SizedBox(height: AppSpacing.sm),
          data.liveNow.isEmpty
              ? const _LiveEmptyCard()
              : _SectionGrid(
                  items: data.liveNow.take(30).toList(),
                  kind: _CardKind.live,
                ),
          if (data.liveNextUrl != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const _ChannelMoreButton(),
          ],
        ],
      4 => const <Widget>[
          _ChannelEmptyCard(message: 'Shop is coming soon'),
        ],
      _ => <Widget>[
          _HeroCarousel(
            items: heroItems,
            controller: _heroController,
            onPageChanged: (int index) {
              setState(() => _activeHeroIndex = index);
            },
            onDramaTap: (HomeDramaItem drama) => _openDramaDetail(context, drama),
          ),
          const SizedBox(height: AppSpacing.xs),
          _HeroDots(count: heroItems.length, activeIndex: _activeHeroIndex),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Recommended for you today', hint: 'For you'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(
            items: _completeRecommendedItems(data),
            kind: _CardKind.video,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Videos', hint: 'More'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(
            items: data.latestVideos.take(6).toList(),
            kind: _CardKind.video,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Short Drama', hint: 'More'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(
            items: data.shortDrama.take(6).toList(),
            kind: _CardKind.drama,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Live', hint: 'More'),
          const SizedBox(height: AppSpacing.sm),
          data.liveNow.isEmpty
              ? const _LiveEmptyCard()
              : _SectionGrid(
                  items: data.liveNow.take(6).toList(),
                  kind: _CardKind.live,
                ),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'More', hint: 'Explore'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(items: data.featured, kind: _CardKind.video),
        ],
    };
  }

  List<Widget> _dramaChannelContent(HomePortalData data) {
    final List<HomeDramaItem> loadedDramas = data.shortDrama;
    final HomeDramaItem? heroDrama = _dramaHeroItem(loadedDramas);
    final List<HomeDramaItem> visibleDramas = _filterDramas(
      loadedDramas,
      _selectedDramaFilterIndex,
    ).take(30).toList();

    return <Widget>[
      _DramaChannelHero(drama: heroDrama),
      const SizedBox(height: AppSpacing.sm),
      _DramaFilterChips(
        selectedIndex: _selectedDramaFilterIndex,
        onSelected: (int index) {
          setState(() => _selectedDramaFilterIndex = index);
        },
      ),
      const SizedBox(height: AppSpacing.md),
      if (visibleDramas.isEmpty)
        const _ChannelEmptyCard(message: 'No loaded dramas available yet.')
      else
        _SectionGrid(
          items: visibleDramas,
          kind: _CardKind.drama,
          useDramaMetadata: true,
        ),
      if (data.dramasNextUrl != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        const _ChannelMoreButton(),
      ],
    ];
  }

  List<Widget> _videoChannelContent(HomePortalData data) {
    final List<HomeVideoItem> loadedVideos = _videoItems ?? data.latestVideos;
    final List<_VideoCategoryOption> categories =
        _videoCategories(_videoCategorySource(data, loadedVideos));
    final int selectedIndex = categories.isEmpty
        ? 0
        : _selectedVideoCategoryIndex.clamp(0, categories.length - 1).toInt();
    final _VideoCategoryOption selectedCategory = categories.isEmpty
        ? const _VideoCategoryOption(label: 'All')
        : categories[selectedIndex];
    final bool isAllSelected = selectedCategory.label == 'All';
    final bool usingCategoryPage = !isAllSelected && _categoryVideoItems != null;
    final List<HomeVideoItem> visibleVideos = isAllSelected
        ? loadedVideos
        : usingCategoryPage
            ? _categoryVideoItems!
            : _filterVideosByCategory(loadedVideos, selectedCategory.label);
    final HomeVideoItem? heroVideo =
        _videoHeroItem(visibleVideos) ?? _videoHeroItem(loadedVideos);
    final String? nextUrl = usingCategoryPage ? _categoryVideosNextUrl : _videosNextUrl;

    return <Widget>[
      if (heroVideo != null) ...<Widget>[
        _VideoChannelHero(video: heroVideo),
        const SizedBox(height: AppSpacing.sm),
      ],
      _VideoCategoryChips(
        categories: categories.map((_VideoCategoryOption c) => c.label).toList(),
        selectedIndex: selectedIndex,
        onSelected: (int index) => _selectVideoCategory(categories, index),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_loadingVideoCategory)
        const _ChannelLoadingCard(message: 'Loading videos...')
      else if (visibleVideos.isEmpty)
        const _ChannelEmptyCard(message: 'No loaded videos available yet.')
      else
        _SectionGrid(items: visibleVideos, kind: _CardKind.video),
      if (nextUrl != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        _ChannelMoreButton(
          label: _loadingMoreVideos ? 'Loading...' : 'Load more',
          onPressed: _loadMoreVideos,
          enabled: !_loadingMoreVideos,
        ),
      ],
    ];
  }

  Future<void> _selectVideoCategory(
    List<_VideoCategoryOption> categories,
    int index,
  ) async {
    final _VideoCategoryOption category = categories[index];
    setState(() {
      _selectedVideoCategoryIndex = index;
      _selectedVideoCategoryQuery = category.queryValue;
      if (category.label == 'All') {
        _categoryVideoItems = null;
        _categoryVideosNextUrl = null;
        _loadingVideoCategory = false;
      } else {
        _loadingVideoCategory = true;
        _categoryVideoItems = null;
        _categoryVideosNextUrl = null;
      }
    });

    if (category.label == 'All') return;

    try {
      final HomeVideoPage page = await _getVideoPage(
        category: category.queryValue ?? category.label,
      );
      if (!mounted || _selectedVideoCategoryQuery != category.queryValue) return;
      setState(() {
        _categoryVideoItems = _filterVideosByCategory(page.items, category.label);
        _categoryVideosNextUrl = page.nextUrl;
        _loadingVideoCategory = false;
      });
    } catch (_) {
      if (!mounted || _selectedVideoCategoryQuery != category.queryValue) return;
      setState(() {
        _loadingVideoCategory = false;
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    final bool loadingCategory = _categoryVideoItems != null;
    final String? nextUrl = loadingCategory ? _categoryVideosNextUrl : _videosNextUrl;
    if (nextUrl == null || _loadingMoreVideos) return;

    setState(() {
      _loadingMoreVideos = true;
    });

    try {
      final HomeVideoPage page = await _getVideoPage(pageUrl: nextUrl);
      if (!mounted) return;
      setState(() {
        if (loadingCategory) {
          final String selectedLabel = _selectedVideoCategoryLabel;
          _categoryVideoItems = _appendUniqueVideos(
            _categoryVideoItems ?? const <HomeVideoItem>[],
            _filterVideosByCategory(page.items, selectedLabel),
          );
          _categoryVideosNextUrl = page.nextUrl;
        } else {
          _videoItems = _appendUniqueVideos(
            _videoItems ?? const <HomeVideoItem>[],
            page.items,
          );
          _videosNextUrl = page.nextUrl;
        }
        _loadingMoreVideos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMoreVideos = false;
      });
    }
  }

  String get _selectedVideoCategoryLabel {
    final HomePortalData? data = _data;
    if (data == null) return 'All';
    final List<_VideoCategoryOption> categories =
        _videoCategories(_videoCategorySource(data, _videoItems ?? data.latestVideos));
    if (categories.isEmpty) return 'All';
    final int index = _selectedVideoCategoryIndex.clamp(0, categories.length - 1).toInt();
    return categories[index].label;
  }

  Future<HomeVideoPage> _getVideoPage({String? pageUrl, String? category}) {
    if (!widget.useRemote && widget.mockRepository is MockHomeRepository) {
      return (widget.mockRepository as MockHomeRepository).getVideoPage(
        pageUrl: pageUrl,
        category: category,
      );
    }
    if (_remoteRepo is RemoteHomeRepository) {
      return (_remoteRepo as RemoteHomeRepository).getVideoPage(
        pageUrl: pageUrl,
        category: category,
      );
    }
    if (_remoteRepo is MockHomeRepository) {
      return (_remoteRepo as MockHomeRepository).getVideoPage(
        pageUrl: pageUrl,
        category: category,
      );
    }
    return Future<HomeVideoPage>.error(
      UnsupportedError('Video paging is not supported by this repository.'),
    );
  }
}

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

enum _CardKind { featured, video, drama, live }

class _VideoCategoryOption {
  const _VideoCategoryOption({required this.label, this.queryValue});

  final String label;
  final String? queryValue;
}

List<dynamic> _heroItemsFor(HomePortalData data) {
  final List<dynamic> items = <dynamic>[
    ...data.shortDrama.take(3),
    ...data.featured.take(2),
  ];
  return items.isEmpty ? <dynamic>[null] : items;
}

List<HomeVideoItem> _videoCategorySource(
  HomePortalData data,
  List<HomeVideoItem> loadedVideos,
) {
  final List<HomeVideoItem> items = <HomeVideoItem>[
    ...loadedVideos,
    ...data.recommended,
    ...data.featured,
  ];
  final Set<String> seen = <String>{};
  return items.where((HomeVideoItem item) => seen.add(item.id)).toList();
}

const List<String> _dramaFilters = <String>[
  'All',
  'Free',
  'Locked',
  'Completed',
];

List<HomeDramaItem> _filterDramas(
  List<HomeDramaItem> dramas,
  int selectedIndex,
) {
  final int safeIndex = selectedIndex.clamp(0, _dramaFilters.length - 1).toInt();
  final String filter = _dramaFilters[safeIndex];
  return switch (filter) {
    'Free' => dramas
        .where((HomeDramaItem drama) => (drama.freeEpisodeCount ?? 0) > 0)
        .toList(),
    'Locked' => dramas
        .where((HomeDramaItem drama) => (drama.lockedEpisodeCount ?? 0) > 0)
        .toList(),
    'Completed' => dramas
        .where((HomeDramaItem drama) => drama.isCompleted == true)
        .toList(),
    _ => dramas,
  };
}

HomeDramaItem? _dramaHeroItem(List<HomeDramaItem> dramas) {
  for (final HomeDramaItem drama in dramas) {
    if (drama.coverUrl?.trim().isNotEmpty ?? false) return drama;
  }
  return dramas.isEmpty ? null : dramas.first;
}

String _dramaMetadata(HomeDramaItem drama) {
  return '${drama.totalEpisodes ?? 0} episodes • '
      'Free ${drama.freeEpisodeCount ?? 0} • '
      'Locked ${drama.lockedEpisodeCount ?? 0}';
}

List<_VideoCategoryOption> _videoCategories(List<HomeVideoItem> videos) {
  final List<_VideoCategoryOption> categories = <_VideoCategoryOption>[
    const _VideoCategoryOption(label: 'All'),
  ];
  final Set<String> seen = <String>{'All'};
  for (final HomeVideoItem video in videos) {
    final String label = _videoCategory(video);
    if (seen.add(label)) {
      categories.add(_VideoCategoryOption(
        label: label,
        queryValue: _videoCategoryQueryValue(video) ?? label,
      ));
    }
  }
  return categories;
}

String? _videoCategoryQueryValue(HomeVideoItem video) {
  final String? category = video.category?.trim();
  if (category != null && category.isNotEmpty) return category;
  final String? categoryName = video.categoryName?.trim();
  if (categoryName != null && categoryName.isNotEmpty) return categoryName;
  return null;
}

List<HomeVideoItem> _filterVideosByCategory(
  List<HomeVideoItem> videos,
  String category,
) {
  if (category == 'All') return videos;
  return videos
      .where((HomeVideoItem video) => _videoCategory(video) == category)
      .toList();
}

String _videoCategory(HomeVideoItem video) {
  final String? categoryName = video.categoryName?.trim();
  if (categoryName != null && categoryName.isNotEmpty) return categoryName;
  final String? category = video.category?.trim();
  if (category != null && category.isNotEmpty) return category;
  return 'Other';
}

HomeVideoItem? _videoHeroItem(List<HomeVideoItem> videos) {
  for (final HomeVideoItem video in videos) {
    if (video.thumbnailUrl?.trim().isNotEmpty ?? false) return video;
  }
  return videos.isEmpty ? null : videos.first;
}

String _videoHeroMetadata(HomeVideoItem video) {
  final String category = _videoCategory(video);
  return category == 'Other' ? video.subtitle : '$category • ${video.subtitle}';
}

List<HomeVideoItem> _appendUniqueVideos(
  List<HomeVideoItem> current,
  List<HomeVideoItem> next,
) {
  final Set<String> seen = current.map((HomeVideoItem item) => item.id).toSet();
  return <HomeVideoItem>[
    ...current,
    ...next.where((HomeVideoItem item) => seen.add(item.id)),
  ];
}

List<dynamic> _completeRecommendedItems(HomePortalData data) {
  final List<dynamic> items = <dynamic>[...data.recommended];
  final Set<String> seen = items.map(_homeItemKey).toSet();
  final List<dynamic> candidates = <dynamic>[
    ...data.latestVideos,
    ...data.featured,
    ...data.shortDrama,
    ...data.liveNow,
  ];

  for (final dynamic candidate in candidates) {
    if (items.length >= 6) break;
    if (seen.add(_homeItemKey(candidate))) {
      items.add(candidate);
    }
  }

  if (items.length >= 6) return items.take(6).toList();
  if (items.length >= 3) return items.take(3).toList();
  return items;
}

String _homeItemKey(dynamic item) {
  if (item is HomeVideoItem) return 'video:${item.id}';
  if (item is HomeDramaItem) return 'drama:${item.id}';
  if (item is HomeLiveItem) return 'live:${item.id}';
  return Object.hash(item.runtimeType, item).toString();
}

_CardKind _cardKindFor(dynamic item, _CardKind fallback) {
  if (item is HomeDramaItem) return _CardKind.drama;
  if (item is HomeLiveItem) return _CardKind.live;
  return fallback;
}

void _openDramaDetail(BuildContext context, HomeDramaItem drama) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DramaDetailPage(drama: drama),
    ),
  );
}

String? _resolveImageUrl(dynamic item) {
  if (item is HomeVideoItem) {
    return item.thumbnailUrl;
  }
  if (item is HomeDramaItem) {
    return item.coverUrl ?? item.thumbnailUrl;
  }
  if (item is HomeLiveItem) {
    return item.thumbnailUrl;
  }
  return null;
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.items,
    required this.kind,
    this.useDramaMetadata = false,
  });

  final List<dynamic> items;
  final _CardKind kind;
  final bool useDramaMetadata;

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
              : item.subtitle as String,
          imageUrl: _resolveImageUrl(item),
          kind: _cardKindFor(item, kind),
          onTap: item is HomeDramaItem
              ? () => _openDramaDetail(context, item)
              : null,
        );
      },
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

class _VideoChannelHero extends StatelessWidget {
  const _VideoChannelHero({required this.video});

  final HomeVideoItem video;

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

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.items,
    required this.controller,
    required this.onPageChanged,
    required this.onDramaTap,
  });

  final List<dynamic> items;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<HomeDramaItem> onDramaTap;

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
          return _PortalCard(
            title: item?.title as String? ?? 'Featured Picks',
            subtitle:
                item?.subtitle as String? ?? 'Drama and video recommendations',
            imageUrl: _resolveImageUrl(item),
            kind: kind,
            compactOverlay: true,
            onTap: item is HomeDramaItem ? () => onDramaTap(item) : null,
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

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.title,
    required this.subtitle,
    required this.kind,
    this.imageUrl,
    this.compactOverlay = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final _CardKind kind;
  final String? imageUrl;
  final bool compactOverlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String badge = switch (kind) {
      _CardKind.featured => 'Video',
      _CardKind.video => 'Video',
      _CardKind.drama => 'Drama',
      _CardKind.live => 'LIVE',
    };

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _CardCover(imageUrl: imageUrl, kind: kind),
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
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: kind == _CardKind.live
                      ? AppColors.brandGold
                      : AppColors.cardBackground.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.softBorder),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.caption.copyWith(
                    color: kind == _CardKind.live
                        ? AppColors.warmBackground
                        : AppColors.brandGold,
                  ),
                ),
              ),
            ),
            Positioned(
              left: compactOverlay ? AppSpacing.xs : AppSpacing.sm,
              right: compactOverlay ? AppSpacing.xs : AppSpacing.sm,
              bottom: compactOverlay ? AppSpacing.xs : AppSpacing.sm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: compactOverlay ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: compactOverlay ? 16 : 11,
                      height: compactOverlay ? 1.2 : 1.08,
                    ),
                  ),
                  SizedBox(height: compactOverlay ? 2 : AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: compactOverlay ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: compactOverlay ? Colors.white70 : Colors.white54,
                      fontSize: compactOverlay ? 12 : 10,
                      height: compactOverlay ? null : 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardCover extends StatelessWidget {
  const _CardCover({required this.imageUrl, required this.kind});

  final String? imageUrl;
  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    final String? trimmedUrl = imageUrl?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return _CardCoverPlaceholder(kind: kind);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Image.network(
        trimmedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _CardCoverPlaceholder(kind: kind),
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return _CardCoverPlaceholder(kind: kind);
        },
      ),
    );
  }
}

class _CardCoverPlaceholder extends StatelessWidget {
  const _CardCoverPlaceholder({required this.kind});

  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    final (_GradientSpec gradientSpec, IconData icon, String label, bool liveBadge) =
        switch (kind) {
      _CardKind.drama => (
          const _GradientSpec(Color(0xFF463522), Color(0xFF221A15)),
          Icons.theaters,
          'Drama',
          false
        ),
      _CardKind.live => (
          const _GradientSpec(Color(0xFF2E2419), Color(0xFF171514)),
          Icons.live_tv,
          'Live',
          true
        ),
      _ => (
          const _GradientSpec(Color(0xFF3B352A), Color(0xFF1F1E1D)),
          Icons.ondemand_video,
          'Video',
          false
        ),
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[gradientSpec.start, gradientSpec.end],
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (liveBadge)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandGold,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  'LIVE',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.warmBackground),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: AppColors.mutedOliveText, size: 30),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientSpec {
  const _GradientSpec(this.start, this.end);

  final Color start;
  final Color end;
}

class _LiveEmptyCard extends StatelessWidget {
  const _LiveEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const _ChannelEmptyCard(message: 'No live streams right now.');
  }
}

class _ChannelMoreButton extends StatelessWidget {
  const _ChannelMoreButton({
    this.label = 'More',
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton(
        onPressed: enabled
            ? onPressed ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('More loading coming soon.')),
                  );
                }
            : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandGold,
          side: const BorderSide(color: AppColors.softBorder),
          textStyle: AppTextStyles.caption,
        ),
        child: Text(label),
      ),
    );
  }
}

class _ChannelLoadingCard extends StatelessWidget {
  const _ChannelLoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(message, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ChannelEmptyCard extends StatelessWidget {
  const _ChannelEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}
