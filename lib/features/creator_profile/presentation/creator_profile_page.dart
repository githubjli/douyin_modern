import 'package:meow_media/app/widgets/app_refresh_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_error.dart';
import '../../auth/application/auth_providers.dart';
import '../../drama_detail/drama_detail_page.dart';
import '../../home/domain/home_models.dart';
import '../../video_detail/video_detail_page.dart';
import '../data/creator_profile_repository.dart';
import '../domain/public_creator_profile.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

class CreatorProfilePage extends ConsumerStatefulWidget {
  const CreatorProfilePage({super.key, required this.creatorId});

  final int creatorId;

  @override
  ConsumerState<CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends ConsumerState<CreatorProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final CreatorProfileRepository _repo;

  PublicCreatorProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = ref.read(creatorProfileRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  /// Only loads the profile header.  Tab content is managed per-tab.
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.getProfile(widget.creatorId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _followLoading) return;
    setState(() => _followLoading = true);
    try {
      final result = profile.viewerIsFollowing
          ? await _repo.unfollow(widget.creatorId)
          : await _repo.follow(widget.creatorId);
      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(
          viewerIsFollowing: result.isFollowing,
          followerCount: result.followerCount,
        );
        _followLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _followLoading = false);
      // 400 typically means "you can't follow yourself" from the backend.
      final String message =
          (e is ApiError && e.statusCode == 400)
              ? 'You can\'t follow yourself.'
              : 'Failed to update follow status.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.warmBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandGold),
        ),
      );
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: AppColors.warmBackground,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Unable to load profile.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.mutedOliveText,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _loadProfile,
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: AppColors.brandGold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Hide the Follow button when the viewer is looking at their own profile.
    // AuthSession.userId is a String (e.g. "42"), profile.id is an int.
    final String? sessionUserId =
        ref.watch(authControllerProvider).session?.userId;
    final bool isOwnProfile =
        sessionUserId != null && sessionUserId == _profile!.id.toString();

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext ctx, bool innerScrolled) =>
            <Widget>[
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: _profile!,
              onBack: () => Navigator.of(context).maybePop(),
              onFollow: _toggleFollow,
              followLoading: _followLoading,
              isOwnProfile: isOwnProfile,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBar(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.brandGold,
                unselectedLabelColor: AppColors.mutedOliveText,
                indicatorColor: AppColors.brandGold,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: AppTextStyles.body.copyWith(
                  fontSize: 13,
                ),
                tabs: const <Widget>[
                  Tab(text: 'Videos'),
                  Tab(text: 'Dramas'),
                  Tab(text: 'Live'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: <Widget>[
            _VideosTab(creatorId: widget.creatorId, repo: _repo),
            _DramasTab(creatorId: widget.creatorId, repo: _repo),
            _LivesTab(creatorId: widget.creatorId, repo: _repo),
          ],
        ),
      ),
    );
  }
}

// ── Sticky tab bar delegate ────────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  const _StickyTabBar(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.warmBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          tabBar,
          const Divider(height: 1, thickness: 1, color: AppColors.softBorder),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBar old) => tabBar != old.tabBar;
}

// ── Profile header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onBack,
    required this.onFollow,
    required this.followLoading,
    this.isOwnProfile = false,
  });

  final PublicCreatorProfile profile;
  final VoidCallback onBack;
  final VoidCallback onFollow;
  final bool followLoading;

  /// When true the viewer IS this creator — the Follow button is hidden.
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Back button
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.cocoaText,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Avatar row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _Avatar(url: profile.avatarUrl, radius: 20),
              const Spacer(),
              if (!isOwnProfile)
                _FollowButton(
                  isFollowing: profile.viewerIsFollowing,
                  loading: followLoading,
                  onTap: onFollow,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Display name
          Text(
            profile.displayName,
            style: AppTextStyles.sectionTitle,
          ),

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.bio!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.mutedOliveText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Stats row
          Row(
            children: <Widget>[
              _StatItem(
                value: profile.followerCount,
                label: 'Followers',
              ),
              const SizedBox(width: AppSpacing.xl),
              _StatItem(
                value: profile.videoCount,
                label: 'Videos',
              ),
              const SizedBox(width: AppSpacing.xl),
              _StatItem(
                value: profile.totalViews,
                label: 'Views',
              ),
              const SizedBox(width: AppSpacing.xl),
              _StatItem(
                value: profile.totalLikes,
                label: 'Likes',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String? trimmed = url?.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.softBorder,
      backgroundImage: trimmed != null && trimmed.isNotEmpty
          ? CachedNetworkImageProvider(trimmed)
          : null,
      child: trimmed == null || trimmed.isEmpty
          ? Icon(
              Icons.person_rounded,
              color: AppColors.mutedOliveText,
              size: radius,
            )
          : null,
    );
  }
}

// ── Follow button ──────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.loading,
    required this.onTap,
  });

  final bool isFollowing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : AppColors.brandGold,
          border: Border.all(
            color: isFollowing
                ? AppColors.brandGold.withValues(alpha: 0.55)
                : AppColors.brandGold,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isFollowing
                      ? AppColors.brandGold
                      : AppColors.warmBackground,
                ),
              )
            else
              Text(
                isFollowing ? 'Following' : 'Follow',
                style: AppTextStyles.body.copyWith(
                  color: isFollowing
                      ? AppColors.brandGold
                      : AppColors.warmBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Stat item ──────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _formatCount(value),
          style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

// ── Videos tab ─────────────────────────────────────────────────────────────────

class _VideosTab extends StatefulWidget {
  const _VideosTab({required this.creatorId, required this.repo});

  final int creatorId;
  final CreatorProfileRepository repo;

  @override
  State<_VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<_VideosTab>
    with AutomaticKeepAliveClientMixin {
  List<PublicCreatorVideo> _items = const <PublicCreatorVideo>[];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextUrl;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({String? url}) async {
    try {
      final result = await widget.repo.getVideos(widget.creatorId, url: url);
      if (!mounted) return;
      setState(() {
        _items = url == null ? result.items : <PublicCreatorVideo>[..._items, ...result.items];
        _nextUrl = result.nextUrl;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        // Only overwrite error on initial load; keep existing items on load-more failure.
        if (url == null) _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    final String? next = _nextUrl;
    if (next == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    await _fetch(url: next);
  }

  Future<void> _refresh() async {
    setState(() {
      _items = const <PublicCreatorVideo>[];
      _nextUrl = null;
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const _VideosSkeleton();
    }

    if (_error != null) {
      return _TabError(error: _error!, onRetry: _refresh);
    }

    if (_items.isEmpty) {
      return _EmptyTab(
        icon: Icons.videocam_off_rounded,
        label: 'No videos yet',
        onRefresh: _refresh,
      );
    }

    return AppRefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.6,
        ),
        itemCount: _items.length + (_nextUrl != null ? 1 : 0),
        itemBuilder: (_, int i) {
          if (i == _items.length) {
            _loadMore();
            return const _LoadMoreIndicator();
          }
          return _VideoThumb(video: _items[i], allVideos: _items);
        },
      ),
    );
  }
}

// ── Dramas tab ─────────────────────────────────────────────────────────────────

class _DramasTab extends StatefulWidget {
  const _DramasTab({required this.creatorId, required this.repo});

  final int creatorId;
  final CreatorProfileRepository repo;

  @override
  State<_DramasTab> createState() => _DramasTabState();
}

class _DramasTabState extends State<_DramasTab>
    with AutomaticKeepAliveClientMixin {
  List<PublicCreatorDrama> _items = const <PublicCreatorDrama>[];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextUrl;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({String? url}) async {
    try {
      final result = await widget.repo.getDramas(widget.creatorId, url: url);
      if (!mounted) return;
      setState(() {
        _items = url == null ? result.items : <PublicCreatorDrama>[..._items, ...result.items];
        _nextUrl = result.nextUrl;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (url == null) _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    final String? next = _nextUrl;
    if (next == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    await _fetch(url: next);
  }

  Future<void> _refresh() async {
    setState(() {
      _items = const <PublicCreatorDrama>[];
      _nextUrl = null;
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const _DramasSkeleton();
    }

    if (_error != null) {
      return _TabError(error: _error!, onRetry: _refresh);
    }

    if (_items.isEmpty) {
      return _EmptyTab(
        icon: Icons.movie_creation_outlined,
        label: 'No dramas yet',
        onRefresh: _refresh,
      );
    }

    return AppRefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.51,
        ),
        itemCount: _items.length + (_nextUrl != null ? 1 : 0),
        itemBuilder: (_, int i) {
          if (i == _items.length) {
            _loadMore();
            return const _LoadMoreIndicator();
          }
          return _DramaTile(drama: _items[i]);
        },
      ),
    );
  }
}

// ── Lives tab ──────────────────────────────────────────────────────────────────

class _LivesTab extends StatefulWidget {
  const _LivesTab({required this.creatorId, required this.repo});

  final int creatorId;
  final CreatorProfileRepository repo;

  @override
  State<_LivesTab> createState() => _LivesTabState();
}

class _LivesTabState extends State<_LivesTab>
    with AutomaticKeepAliveClientMixin {
  List<PublicCreatorLive> _items = const <PublicCreatorLive>[];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextUrl;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({String? url}) async {
    try {
      final result = await widget.repo.getLives(widget.creatorId, url: url);
      if (!mounted) return;
      setState(() {
        _items = url == null ? result.items : <PublicCreatorLive>[..._items, ...result.items];
        _nextUrl = result.nextUrl;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (url == null) _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    final String? next = _nextUrl;
    if (next == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    await _fetch(url: next);
  }

  Future<void> _refresh() async {
    setState(() {
      _items = const <PublicCreatorLive>[];
      _nextUrl = null;
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const _LivesSkeleton();
    }

    if (_error != null) {
      return _TabError(error: _error!, onRetry: _refresh);
    }

    if (_items.isEmpty) {
      return _EmptyTab(
        icon: Icons.live_tv_outlined,
        label: 'No live history',
        onRefresh: _refresh,
      );
    }

    return AppRefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.6,
        ),
        itemCount: _items.length + (_nextUrl != null ? 1 : 0),
        itemBuilder: (_, int i) {
          if (i == _items.length) {
            _loadMore();
            return const _LoadMoreIndicator();
          }
          return _LiveTile(live: _items[i]);
        },
      ),
    );
  }
}

// ── Tile widgets ───────────────────────────────────────────────────────────────

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.video, this.allVideos = const <PublicCreatorVideo>[]});

  final PublicCreatorVideo video;
  final List<PublicCreatorVideo> allVideos;

  static HomeVideoItem _toHomeVideoItem(PublicCreatorVideo v) => HomeVideoItem(
        id: v.id.toString(),
        title: v.title,
        subtitle: '',
        thumbnailUrl: v.thumbnailUrl,
        accessType: v.accessType,
        isLocked: v.isLocked,
        viewCount: v.viewCount,
        createdAt: v.createdAt,
      );

  void _open(BuildContext context) {
    // Build a recommendations list from all sibling videos, excluding the
    // current one so the user sees the rest of the creator's content.
    final List<HomeVideoItem> recommendations = allVideos
        .where((PublicCreatorVideo v) => v.id != video.id)
        .map(_toHomeVideoItem)
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoDetailPage(
          video: _toHomeVideoItem(video),
          recommendations: recommendations,
          loadRemoteDetail: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Thumbnail
            _Thumbnail(url: video.thumbnailUrl),

            // Gradient overlay
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
                  stops: <double>[0.2, 0.6, 1.0],
                ),
              ),
            ),

            // Badge — top-left, matches _InfoBadge in video_detail
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _ContentBadge(
                label: video.isPremium ? 'VIP' : 'Video',
              ),
            ),

            // Bottom: title + views
            Positioned(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${_formatCount(video.viewCount)} views',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white54,
                      fontSize: 10,
                      height: 1.1,
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

class _DramaTile extends StatelessWidget {
  const _DramaTile({required this.drama});

  final PublicCreatorDrama drama;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DramaDetailPage(
          drama: HomeDramaItem(
            id: drama.id.toString(),
            title: drama.title,
            subtitle: drama.episodeCount > 0
                ? '${drama.episodeCount} episodes'
                : '',
            coverUrl: drama.coverUrl,
            totalEpisodes: drama.episodeCount,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _Thumbnail(url: drama.coverUrl),

            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x0D000000),
                    Color(0x55000000),
                    Color(0xDD000000),
                  ],
                  stops: <double>[0.2, 0.6, 1.0],
                ),
              ),
            ),

            // Badge — top-left, matches _InfoBadge style
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _ContentBadge(
                label: drama.isPremium ? 'VIP' : 'Drama',
              ),
            ),

            // Bottom: title + episode count
            Positioned(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    drama.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  if (drama.episodeCount > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${drama.episodeCount} eps',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white54,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.live});

  final PublicCreatorLive live;

  /// Badge label matching home-page `_liveBadgeLabel` logic.
  String get _badgeLabel {
    final String s = live.effectiveStatus.toLowerCase().trim();
    if (s == 'live' || s == 'active' || s == 'streaming' || s == 'started') {
      return 'LIVE';
    }
    if (s == 'ended' || s == 'end' || s == 'finished' || s == 'closed' || s == 'offline') {
      return 'Ended';
    }
    return 'Ready';
  }

  bool get _isLive => _badgeLabel == 'LIVE';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live detail/watch page coming soon.')),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Cover image
            _Thumbnail(url: live.coverUrl),

            // 3-stop gradient overlay — same as home _PortalCard
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
                  stops: <double>[0.2, 0.6, 1.0],
                ),
              ),
            ),

            // Badge — top-left: gold bg for LIVE, dark bg for Ended/Ready
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _isLive
                      ? AppColors.brandGold
                      : AppColors.cardBackground.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.softBorder),
                ),
                child: Text(
                  _badgeLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: _isLive ? AppColors.warmBackground : AppColors.brandGold,
                  ),
                ),
              ),
            ),

            // Bottom: title + viewer count
            Positioned(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    live.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${_formatCount(live.viewerCount)} watching',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white54,
                      fontSize: 10,
                      height: 1.1,
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

// ── Shared widgets ─────────────────────────────────────────────────────────────

/// Generic thumbnail with a grey placeholder.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final String? trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF343332),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Color(0xFF666462), size: 24),
        ),
      );
    }
    return AppCachedImage(
      imageUrl: trimmed,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: Color(0xFF343332)),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Color(0xFF343332),
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: Color(0xFF666462), size: 20),
        ),
      ),
    );
  }
}

/// Content-type badge (VIP / Video / Drama / LIVE) matching the style used by
/// [_InfoBadge] in video_detail_page and [_PortalCard] in home_page:
/// semi-transparent dark background + [AppColors.softBorder] border + gold text.
class _ContentBadge extends StatelessWidget {
  const _ContentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.75),
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
      ),
    );
  }
}

/// Centred empty-state for a tab.
/// Wraps in [RefreshIndicator] when [onRefresh] is provided so the user can
/// still pull-to-refresh even when there is no content yet.
class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.label,
    this.onRefresh,
  });

  final IconData icon;
  final String label;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final Widget inner = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: AppColors.mutedOliveText),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: AppColors.mutedOliveText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
    final Future<void> Function()? refresh = onRefresh;
    if (refresh == null) return inner;
    return AppRefreshIndicator(
      onRefresh: refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.4,
          child: inner,
        ),
      ),
    );
  }
}

/// Per-tab error state with a Retry button.
class _TabError extends StatelessWidget {
  const _TabError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.mutedOliveText,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Failed to load',
              style: AppTextStyles.body.copyWith(
                color: AppColors.cocoaText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.brandGold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small centred spinner shown at the bottom of a list while loading more.
class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

// ── Shimmer skeletons ──────────────────────────────────────────────────────────

/// Warm-dark shimmer palette consistent with the app's colour scheme.
const Color _shimmerBase = AppColors.cardBackground;      // 0xFF2B2A29
const Color _shimmerHighlight = Color(0xFF3C3A38);        // warm grey, clearly lighter

/// 3-column skeleton matching the Videos grid layout (9 cells = 3 full rows).
class _VideosSkeleton extends StatelessWidget {
  const _VideosSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _shimmerBase,
      highlightColor: _shimmerHighlight,
      child: GridView.count(
        padding: const EdgeInsets.all(AppSpacing.sm),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.6,
        children: List<Widget>.generate(
          9,
          (_) => ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 3-column skeleton matching the Dramas grid layout (9 cells = 3 full rows).
class _DramasSkeleton extends StatelessWidget {
  const _DramasSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _shimmerBase,
      highlightColor: _shimmerHighlight,
      child: GridView.count(
        padding: const EdgeInsets.all(AppSpacing.sm),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.51,
        children: List<Widget>.generate(
          9,
          (_) => ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 3-column portrait grid skeleton matching the Lives grid layout (9 cells = 3 full rows).
class _LivesSkeleton extends StatelessWidget {
  const _LivesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _shimmerBase,
      highlightColor: _shimmerHighlight,
      child: GridView.count(
        padding: const EdgeInsets.all(AppSpacing.sm),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.6,
        children: List<Widget>.generate(
          9,
          (_) => ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}
