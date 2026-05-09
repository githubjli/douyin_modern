import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_assets.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../auth/application/auth_providers.dart';
import '../auth/application/auth_state.dart';
import '../drama_detail/drama_detail_page.dart';
import '../video_detail/video_detail_page.dart';
import 'data/mock_home_repository.dart';
import 'data/remote_home_repository.dart';
import 'domain/home_models.dart';
import 'domain/home_repository.dart';

part 'widgets/channel_controls.dart';
part 'widgets/channel_state_widgets.dart';
part 'widgets/filter_chips.dart';
part 'widgets/hero_widgets.dart';
part 'widgets/portal_cards.dart';
part 'widgets/section_grid.dart';

class HomePage extends ConsumerStatefulWidget {
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
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final HomeRepository _remoteRepo;
  final PageController _heroController = PageController();
  final PageController _newsHeroController = PageController();
  HomePortalData? _data;
  bool _loading = true;
  String? _notice;
  int _activeHeroIndex = 0;
  int _activeNewsHeroIndex = 0;
  int _selectedChannelIndex = 0;
  int _selectedNewsFilterIndex = 0;
  int _selectedVideoCategoryIndex = 0;
  int _selectedDramaFilterIndex = 0;
  int _selectedLiveFilterIndex = 0;
  List<HomeVideoItem>? _videoItems;
  List<HomeVideoItem>? _newsVideoItems;
  List<HomeVideoItem>? _categoryVideoItems;
  String? _videosNextUrl;
  String? _newsVideosNextUrl;
  String? _categoryVideosNextUrl;
  String? _selectedVideoCategoryQuery;
  bool _loadingMoreVideos = false;
  bool _loadingMoreNewsVideos = false;
  bool _loadingVideoCategory = false;
  bool _usingNewsVideoFallback = false;
  int _loadGeneration = 0;

  static const List<String> _channels = <String>[
    'Home',
    'News',
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
    final int loadGeneration = ++_loadGeneration;
    final bool authenticated = _shouldUseAuthenticatedFeed(
      ref.read(authControllerProvider),
    );
    HomePortalData? portal;
    String? notice;
    bool usingPortalFallback = !widget.useRemote;
    if (widget.useRemote) {
      try {
        final HomePortalData remotePortal = await _remoteRepo.getHomePortalData(
          authenticated: authenticated,
        );
        if (_isEmpty(remotePortal)) {
          notice = 'Showing local content.';
          usingPortalFallback = true;
        } else {
          portal = remotePortal;
        }
      } catch (_) {
        notice = 'Network unavailable. Showing local content.';
        usingPortalFallback = true;
      }
    }

    portal ??= await widget.mockRepository.getHomePortalData();
    final HomePortalData loadedPortal = portal;
    final List<HomeVideoItem> localNewsVideos =
        _localNewsVideos(loadedPortal.latestVideos);

    HomeVideoPage? newsVideoPage;
    bool usingNewsFallback = false;
    if (!usingPortalFallback) {
      try {
        newsVideoPage = await _getVideoPage(
          category: 'news',
          authenticated: authenticated,
        );
        if (newsVideoPage.items.isEmpty && localNewsVideos.isNotEmpty) {
          newsVideoPage = null;
        }
      } catch (_) {
        usingNewsFallback = localNewsVideos.isEmpty;
      }
    }

    if (!mounted || loadGeneration != _loadGeneration) return;
    setState(() {
      _notice = notice;
      _data = loadedPortal;
      _videoItems = loadedPortal.latestVideos;
      _newsVideoItems = newsVideoPage?.items ?? localNewsVideos;
      _videosNextUrl = loadedPortal.videosNextUrl;
      _newsVideosNextUrl = newsVideoPage?.nextUrl;
      _categoryVideoItems = null;
      _categoryVideosNextUrl = null;
      _selectedVideoCategoryIndex = 0;
      _selectedVideoCategoryQuery = null;
      _usingNewsVideoFallback = usingNewsFallback;
      _loading = false;
    });
  }

  bool _isEmpty(HomePortalData p) =>
      p.featured.isEmpty &&
      p.latestVideos.isEmpty &&
      p.shortDrama.isEmpty &&
      p.liveNow.isEmpty &&
      p.recommended.isEmpty;

  @override
  void dispose() {
    _heroController.dispose();
    _newsHeroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    ref.listen<AuthState>(
      authControllerProvider,
      (AuthState? previous, AuthState next) {
        if (previous == null) return;
        final bool wasAuthenticated = _shouldUseAuthenticatedFeed(previous);
        final bool isAuthenticated = _shouldUseAuthenticatedFeed(next);
        if (wasAuthenticated != isAuthenticated) {
          _load();
        }
      },
    );
    _shouldUseAuthenticatedFeed(authState);
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
      1 => _newsChannelContent(data),
      2 => _videoChannelContent(data),
      3 => _dramaChannelContent(data),
      4 => _liveChannelContent(data),
      5 => const <Widget>[
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
            videoRecommendations: _videoDetailRecommendations(data),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Videos', hint: 'More'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(
            items: data.latestVideos.take(6).toList(),
            kind: _CardKind.video,
            videoRecommendations: _videoDetailRecommendations(data),
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
          _SectionGrid(
            items: data.featured,
            kind: _CardKind.video,
            videoRecommendations: _videoDetailRecommendations(data),
          ),
        ],
    };
  }

  List<Widget> _newsChannelContent(HomePortalData data) {
    final List<HomeVideoItem> newsVideos =
        _newsVideoItems ?? _localNewsVideos(data.latestVideos);
    final List<dynamic> newsItems = _newsItems(data, newsVideos);
    final List<dynamic> newsHeroItems = _newsHeroItems(newsItems);
    final List<dynamic> visibleItems = _filterNewsItems(
      newsItems,
      _selectedNewsFilterIndex,
    ).take(30).toList();

    return <Widget>[
      _NewsHeroCarousel(
        items: newsHeroItems,
        controller: _newsHeroController,
        onPageChanged: (int index) {
          setState(() => _activeNewsHeroIndex = index);
        },
      ),
      if (newsHeroItems.length > 1) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        _HeroDots(
          count: newsHeroItems.length,
          activeIndex: _activeNewsHeroIndex,
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      _NewsFilterChips(
        selectedIndex: _selectedNewsFilterIndex,
        onSelected: (int index) {
          setState(() => _selectedNewsFilterIndex = index);
        },
      ),
      if (_usingNewsVideoFallback) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Showing locally loaded news videos.',
          style: AppTextStyles.caption.copyWith(fontSize: 10),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      if (visibleItems.isEmpty)
        const _ChannelEmptyCard(message: 'No news content yet')
      else
        _SectionGrid(
          items: visibleItems,
          kind: _CardKind.video,
          useNewsMetadata: true,
          videoRecommendations: _appendUniqueVideos(
            _videoDetailRecommendations(data),
            newsVideos,
          ),
        ),
      if (_newsVideosNextUrl != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        _ChannelMoreButton(
          label: _loadingMoreNewsVideos ? 'Loading...' : 'Load more',
          onPressed: _loadMoreNewsVideos,
          enabled: !_loadingMoreNewsVideos,
        ),
      ],
    ];
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

  List<Widget> _liveChannelContent(HomePortalData data) {
    final List<HomeLiveItem> loadedLive = data.liveNow;
    final HomeLiveItem? heroLive = _liveHeroItem(loadedLive);
    final List<HomeLiveItem> visibleLive = _filterLiveItems(
      loadedLive,
      _selectedLiveFilterIndex,
    ).take(30).toList();

    return <Widget>[
      _LiveChannelHero(item: heroLive),
      const SizedBox(height: AppSpacing.sm),
      _LiveFilterChips(
        selectedIndex: _selectedLiveFilterIndex,
        onSelected: (int index) {
          setState(() => _selectedLiveFilterIndex = index);
        },
      ),
      const SizedBox(height: AppSpacing.md),
      if (visibleLive.isEmpty)
        const _LiveEmptyCard()
      else
        _SectionGrid(
          items: visibleLive,
          kind: _CardKind.live,
          useLiveMetadata: true,
        ),
      if (data.liveNextUrl != null) ...<Widget>[
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
        _SectionGrid(
          items: visibleVideos,
          kind: _CardKind.video,
          videoRecommendations: _appendUniqueVideos(
            _videoDetailRecommendations(data),
            loadedVideos,
          ),
        ),
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

  Future<void> _loadMoreNewsVideos() async {
    final String? nextUrl = _newsVideosNextUrl;
    if (nextUrl == null || _loadingMoreNewsVideos) return;

    setState(() {
      _loadingMoreNewsVideos = true;
    });

    try {
      final HomeVideoPage page = await _getVideoPage(pageUrl: nextUrl);
      if (!mounted) return;
      setState(() {
        _newsVideoItems = _appendUniqueVideos(
          _newsVideoItems ?? const <HomeVideoItem>[],
          _localNewsVideos(page.items),
        );
        _newsVideosNextUrl = page.nextUrl;
        _loadingMoreNewsVideos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMoreNewsVideos = false;
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

  Future<HomeVideoPage> _getVideoPage({
    String? pageUrl,
    String? category,
    bool? authenticated,
  }) {
    final bool useAuthenticated = authenticated ??
        _shouldUseAuthenticatedFeed(ref.read(authControllerProvider));
    if (!widget.useRemote && widget.mockRepository is MockHomeRepository) {
      return (widget.mockRepository as MockHomeRepository).getVideoPage(
        pageUrl: pageUrl,
        category: category,
        authenticated: useAuthenticated,
      );
    }
    if (_remoteRepo is RemoteHomeRepository) {
      return (_remoteRepo as RemoteHomeRepository).getVideoPage(
        pageUrl: pageUrl,
        category: category,
        authenticated: useAuthenticated,
      );
    }
    if (_remoteRepo is MockHomeRepository) {
      return (_remoteRepo as MockHomeRepository).getVideoPage(
        pageUrl: pageUrl,
        category: category,
        authenticated: useAuthenticated,
      );
    }
    return Future<HomeVideoPage>.error(
      UnsupportedError('Video paging is not supported by this repository.'),
    );
  }
}

bool _shouldUseAuthenticatedFeed(AuthState authState) {
  return authState.session?.isSignedIn == true ||
      authState.status == AuthStatus.signedIn;
}

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

const List<String> _newsFilters = <String>[
  'All',
  'Videos',
  'Live',
  'Latest',
];

List<dynamic> _newsItems(
  HomePortalData data,
  List<HomeVideoItem> loadedVideos,
) {
  return <dynamic>[
    ..._localNewsVideos(loadedVideos),
    ...data.liveNow.where(_isNewsLive),
  ];
}

List<HomeVideoItem> _localNewsVideos(List<HomeVideoItem> videos) {
  return videos.where(_isNewsVideo).toList();
}

List<dynamic> _filterNewsItems(List<dynamic> items, int selectedIndex) {
  final int safeIndex = selectedIndex.clamp(0, _newsFilters.length - 1).toInt();
  final String filter = _newsFilters[safeIndex];
  return switch (filter) {
    'Videos' => items.whereType<HomeVideoItem>().toList(),
    'Live' => items.whereType<HomeLiveItem>().toList(),
    'Latest' => _sortNewsByCreatedAt(items),
    _ => items,
  };
}

List<dynamic> _sortNewsByCreatedAt(List<dynamic> items) {
  if (!items.any((dynamic item) => _newsCreatedAt(item) != null)) return items;
  final List<dynamic> sorted = List<dynamic>.of(items);
  sorted.sort((dynamic a, dynamic b) {
    final DateTime? aDate = _newsCreatedAt(a);
    final DateTime? bDate = _newsCreatedAt(b);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return sorted;
}

DateTime? _newsCreatedAt(dynamic item) {
  final String? value = switch (item) {
    HomeVideoItem video => video.createdAt,
    HomeLiveItem live => live.createdAt,
    _ => null,
  };
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

List<dynamic> _newsHeroItems(List<dynamic> items) {
  final List<dynamic> heroItems = <dynamic>[
    ...items.whereType<HomeLiveItem>().where((HomeLiveItem item) {
      final String status = _liveStatus(item);
      return status == 'live' || status == 'ready';
    }),
    ...items.whereType<HomeVideoItem>(),
    ...items.whereType<HomeLiveItem>().where((HomeLiveItem item) {
      final String status = _liveStatus(item);
      return status != 'live' && status != 'ready';
    }),
  ];
  return heroItems.isEmpty ? <dynamic>[null] : heroItems.take(5).toList();
}

bool _isNewsVideo(HomeVideoItem item) {
  return _isNewsCategory(item.category) || _isNewsCategory(item.categoryName);
}

bool _isNewsLive(HomeLiveItem item) {
  return _isNewsCategory(item.category) || _isNewsCategory(item.categoryName);
}

bool _isNewsCategory(String? value) {
  return value?.trim().toLowerCase() == 'news';
}

String _newsTitle(dynamic item) {
  if (item is HomeVideoItem) return item.title;
  if (item is HomeLiveItem) return item.title;
  return 'News';
}

String _newsMetadata(dynamic item) {
  if (item is HomeLiveItem) return _liveMetadata(item);
  if (item is HomeVideoItem) return _videoMetadata(item);
  return 'News';
}

String _newsBadgeLabel(dynamic item) {
  if (item is HomeLiveItem) return _liveBadgeLabel(item);
  if (item is HomeVideoItem) return 'Video';
  return 'News';
}

String _newsHeroBadgeLabel(dynamic item) {
  if (item is HomeVideoItem) return 'News';
  return _newsBadgeLabel(item);
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

const List<String> _liveFilters = <String>[
  'All',
  'Live',
  'Ready',
  'Ended',
];

List<HomeLiveItem> _filterLiveItems(
  List<HomeLiveItem> items,
  int selectedIndex,
) {
  final int safeIndex = selectedIndex.clamp(0, _liveFilters.length - 1).toInt();
  final String filter = _liveFilters[safeIndex];
  return switch (filter) {
    'Live' => items
        .where((HomeLiveItem item) => _liveStatus(item) == 'live')
        .toList(),
    'Ready' => items
        .where((HomeLiveItem item) => _liveStatus(item) == 'ready')
        .toList(),
    'Ended' => items
        .where((HomeLiveItem item) => _liveStatus(item) == 'ended')
        .toList(),
    _ => items,
  };
}

HomeLiveItem? _liveHeroItem(List<HomeLiveItem> items) {
  for (final HomeLiveItem item in items) {
    if (_liveStatus(item) == 'live') return item;
  }
  for (final HomeLiveItem item in items) {
    if (_liveStatus(item) == 'ready') return item;
  }
  return items.isEmpty ? null : items.first;
}

String _liveStatus(HomeLiveItem item) {
  final String? rawStatus = item.effectiveStatus?.trim().isNotEmpty == true
      ? item.effectiveStatus
      : item.status?.trim().isNotEmpty == true
          ? item.status
          : item.djangoStatus;
  final String normalized = rawStatus?.toLowerCase().trim() ?? '';
  if (normalized == 'live' ||
      normalized == 'active' ||
      normalized == 'streaming' ||
      normalized == 'started') {
    return 'live';
  }
  if (normalized == 'ready' ||
      normalized == 'scheduled' ||
      normalized == 'pending' ||
      normalized == 'waiting') {
    return 'ready';
  }
  if (normalized == 'ended' ||
      normalized == 'end' ||
      normalized == 'finished' ||
      normalized == 'closed' ||
      normalized == 'offline') {
    return 'ended';
  }
  return 'ready';
}

String _liveBadgeLabel(HomeLiveItem item) {
  return switch (_liveStatus(item)) {
    'live' => 'LIVE',
    'ended' => 'Ended',
    _ => 'Ready',
  };
}

String _liveMetadata(HomeLiveItem item) {
  final String owner = item.ownerName?.trim().isNotEmpty == true
      ? item.ownerName!.trim()
      : 'Host';
  return '$owner · ${item.viewerCount ?? 0} watching';
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


String? _badgeOverrideForItem(
  dynamic item, {
  required bool useLiveMetadata,
  required bool useNewsMetadata,
}) {
  if (item is HomeVideoItem) {
    return _videoAccessBadge(item) ??
        (useNewsMetadata ? _newsBadgeLabel(item) : null);
  }
  if (useLiveMetadata && item is HomeLiveItem) return _liveBadgeLabel(item);
  if (useNewsMetadata) return _newsBadgeLabel(item);
  return null;
}

String? _videoAccessBadge(HomeVideoItem video) {
  if (video.isMembershipVideo) return 'VIP';
  if (video.isLocked == true) return 'Locked';
  return null;
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

String _videoMetadata(HomeVideoItem video) {
  final String owner = video.ownerName?.trim().isNotEmpty == true
      ? video.ownerName!.trim()
      : 'Creator';
  return '$owner · ${video.viewCount ?? 0} views';
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

List<HomeVideoItem> _videoDetailRecommendations(HomePortalData data) {
  final List<HomeVideoItem> videos = <HomeVideoItem>[
    ...data.latestVideos,
    ...data.featured,
    ...data.recommended,
  ];
  final Set<String> seen = <String>{};
  return videos.where((HomeVideoItem video) => seen.add(video.id)).toList();
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

void _openVideoDetail(
  BuildContext context,
  HomeVideoItem video,
  List<HomeVideoItem> recommendations,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VideoDetailPage(
        video: video,
        recommendations: recommendations,
      ),
    ),
  );
}

void _showLiveComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Live detail/watch page coming soon.')),
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
