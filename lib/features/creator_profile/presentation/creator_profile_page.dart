import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
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
  List<PublicCreatorVideo> _videos = const <PublicCreatorVideo>[];
  List<PublicCreatorDrama> _dramas = const <PublicCreatorDrama>[];
  List<PublicCreatorLive> _lives = const <PublicCreatorLive>[];

  bool _loading = true;
  String? _error;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = ref.read(creatorProfileRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fire all four requests in parallel.
      final profileFuture = _repo.getProfile(widget.creatorId);
      final videosFuture = _repo.getVideos(widget.creatorId);
      final dramasFuture = _repo.getDramas(widget.creatorId);
      final livesFuture = _repo.getLives(widget.creatorId);
      await Future.wait(<Future<dynamic>>[
        profileFuture,
        videosFuture,
        dramasFuture,
        livesFuture,
      ]);
      // All futures are resolved — await again to get typed values (no I/O cost).
      final PublicCreatorProfile profile = await profileFuture;
      final List<PublicCreatorVideo> videos = await videosFuture;
      final List<PublicCreatorDrama> dramas = await dramasFuture;
      final List<PublicCreatorLive> lives = await livesFuture;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _videos = videos;
        _dramas = dramas;
        _lives = lives;
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _followLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update follow status.')),
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
                  onPressed: _loadAll,
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
              _VideosTab(videos: _videos),
              _DramasTab(dramas: _dramas),
              _LivesTab(lives: _lives),
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
  });

  final PublicCreatorProfile profile;
  final VoidCallback onBack;
  final VoidCallback onFollow;
  final bool followLoading;

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
              _Avatar(url: profile.avatarUrl, radius: 40),
              const Spacer(),
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
                value: profile.likeCount,
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
          ? NetworkImage(trimmed)
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
                  color: isFollowing ? AppColors.brandGold : AppColors.warmBackground,
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

// ── Videos tab — 3-column grid ─────────────────────────────────────────────────

class _VideosTab extends StatelessWidget {
  const _VideosTab({required this.videos});

  final List<PublicCreatorVideo> videos;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const _EmptyTab(icon: Icons.videocam_off_rounded, label: 'No videos yet');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: videos.length,
      itemBuilder: (_, int i) => _VideoThumb(video: videos[i]),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.video});

  final PublicCreatorVideo video;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Thumbnail
        _Thumbnail(url: video.thumbnailUrl),

        // Bottom gradient + title
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: <Color>[Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ),

        // VIP badge
        if (video.isPremium)
          const Positioned(
            top: 4,
            right: 4,
            child: _VipBadge(),
          ),
      ],
    );
  }
}

// ── Dramas tab — 2-column grid ─────────────────────────────────────────────────

class _DramasTab extends StatelessWidget {
  const _DramasTab({required this.dramas});

  final List<PublicCreatorDrama> dramas;

  @override
  Widget build(BuildContext context) {
    if (dramas.isEmpty) {
      return const _EmptyTab(
        icon: Icons.movie_creation_outlined,
        label: 'No dramas yet',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.xs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.xs,
        mainAxisSpacing: AppSpacing.xs,
        childAspectRatio: 2 / 3,
      ),
      itemCount: dramas.length,
      itemBuilder: (_, int i) => _DramaTile(drama: dramas[i]),
    );
  }
}

class _DramaTile extends StatelessWidget {
  const _DramaTile({required this.drama});

  final PublicCreatorDrama drama;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _Thumbnail(url: drama.coverUrl),

          // Bottom overlay: title + episode count
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[Color(0xDD000000), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    drama.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (drama.episodeCount > 0) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      '${drama.episodeCount} eps',
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // VIP badge
          if (drama.isPremium)
            const Positioned(
              top: 6,
              right: 6,
              child: _VipBadge(),
            ),
        ],
      ),
    );
  }
}

// ── Live tab — list ────────────────────────────────────────────────────────────

class _LivesTab extends StatelessWidget {
  const _LivesTab({required this.lives});

  final List<PublicCreatorLive> lives;

  @override
  Widget build(BuildContext context) {
    if (lives.isEmpty) {
      return const _EmptyTab(
        icon: Icons.live_tv_outlined,
        label: 'No live history',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: lives.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, int i) => _LiveTile(live: lives[i]),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.live});

  final PublicCreatorLive live;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Thumbnail — 16:9
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusSm),
              bottomLeft: Radius.circular(AppSpacing.radiusSm),
            ),
            child: SizedBox(
              width: 120,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _Thumbnail(url: live.coverUrl),
                  if (live.isLive)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    live.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.remove_red_eye_outlined,
                        size: 12,
                        color: AppColors.mutedOliveText,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatCount(live.viewerCount),
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFF343332),
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: Color(0xFF666462), size: 20),
        ),
      ),
    );
  }
}

/// Gold crown badge for premium / VIP content.
class _VipBadge extends StatelessWidget {
  const _VipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandGold,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'VIP',
        style: TextStyle(
          color: Color(0xFF1A1400),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Centred empty-state for a tab.
class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
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
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}
