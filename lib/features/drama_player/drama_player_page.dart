import 'dart:async';
import 'dart:ui';

import '../../app/widgets/app_cached_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../../shared/danmaku_overlay.dart';
import '../drama_detail/drama_detail_page.dart';

// ────────────────────────────────────────────────────────────────────────────
// Public entry-point widget
// ────────────────────────────────────────────────────────────────────────────

class DramaPlayerPage extends StatefulWidget {
  const DramaPlayerPage({
    super.key,
    required this.dramaId,
    required this.seriesTitle,
    this.startEpisodeNo = 1,
    this.totalEpisodes,
  });

  final int dramaId;
  final String seriesTitle;
  final int startEpisodeNo;
  final int? totalEpisodes;

  @override
  State<DramaPlayerPage> createState() => _DramaPlayerPageState();
}

class _DramaPlayerPageState extends State<DramaPlayerPage> {
  late final ApiClient _apiClient;
  PageController? _pageController;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};

  List<DramaEpisodeItem> _episodes = const <DramaEpisodeItem>[];
  bool _loading = true;
  int _currentIndex = 0;

  // Interaction state (fetched from interaction-summary)
  bool _favorited = false;
  int _favoriteCount = 0;
  int _commentCount = 0;
  int _shareCount = 0;
  int _giftCount = 0;

  // Owner / follow
  int? _ownerId;
  String? _ownerAvatarUrl;
  bool _subscribed = false;

  // Danmaku
  bool _danmakuEnabled = true;
  List<String> _danmakuComments = const <String>[];

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _loadEpisodes();
    _loadInteractions();
    _loadDanmaku();
    _loadOwner();
  }

  Future<void> _loadOwner() async {
    try {
      final response = await _apiClient
          .get<dynamic>(Endpoints.dramaDetail(widget.dramaId));
      final dynamic data = response.data;
      if (data is! Map<String, dynamic> || !mounted) return;
      final dynamic ownerId = data['owner'] ?? data['owner_id'] ??
          data['channel_id'] ?? data['creator_id'];
      final String? avatarUrl =
          data['owner_avatar_url'] as String? ??
          data['owner_avatar'] as String? ??
          data['creator_avatar_url'] as String?;
      final dynamic subscribed = data['viewer_is_subscribed'] ??
          data['is_subscribed'];
      setState(() {
        _ownerId = ownerId is int
            ? ownerId
            : int.tryParse(ownerId?.toString() ?? '');
        _ownerAvatarUrl = avatarUrl;
        _subscribed = subscribed is bool ? subscribed : false;
      });
    } catch (_) {}
  }

  Future<void> _toggleSubscribe() async {
    final int? ownerId = _ownerId;
    if (ownerId == null) return;
    final bool next = !_subscribed;
    setState(() => _subscribed = next);
    try {
      if (next) {
        await _apiClient.post<dynamic>(
          Endpoints.channelSubscribe(ownerId),
          authenticated: true,
        );
      } else {
        await _apiClient.delete<dynamic>(
          Endpoints.channelSubscribe(ownerId),
          authenticated: true,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _subscribed = !next);
    }
  }

  Future<void> _loadInteractions() async {
    try {
      final response = await _apiClient.get<dynamic>(
        Endpoints.dramaInteractionSummary(widget.dramaId),
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is! Map<String, dynamic> || !mounted) return;
      setState(() {
        _favorited = (data['viewer_is_favorited'] as bool?) ??
            (data['is_favorited'] as bool?) ??
            _favorited;
        _favoriteCount = (data['favorite_count'] as int?) ?? _favoriteCount;
        _commentCount = (data['comment_count'] as int?) ?? _commentCount;
        _shareCount = (data['share_count'] as int?) ?? _shareCount;
        _giftCount = (data['gift_count'] as int?) ?? _giftCount;
      });
    } catch (_) {}
  }

  Future<void> _loadDanmaku() async {
    try {
      final response = await _apiClient
          .get<dynamic>(Endpoints.dramaComments(widget.dramaId));
      final dynamic data = response.data;
      List<dynamic> rows = const <dynamic>[];
      if (data is List) {
        rows = data;
      } else if (data is Map<String, dynamic>) {
        final dynamic r = data['results'] ?? data['comments'];
        if (r is List) rows = r;
      }
      final List<String> comments = rows
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> m) =>
              (m['content'] ?? m['text'] ?? m['body'] ?? '').toString().trim())
          .where((String s) => s.isNotEmpty)
          .toList();
      if (mounted && comments.isNotEmpty) {
        setState(() => _danmakuComments = comments);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final bool next = !_favorited;
    setState(() {
      _favorited = next;
      _favoriteCount += next ? 1 : -1;
    });
    try {
      if (next) {
        await _apiClient.post<dynamic>(
          Endpoints.dramaFavorite(widget.dramaId),
          authenticated: true,
        );
      } else {
        await _apiClient.delete<dynamic>(
          Endpoints.dramaFavorite(widget.dramaId),
          authenticated: true,
        );
      }
      unawaited(_loadInteractions());
    } catch (_) {
      if (mounted) {
        setState(() {
          _favorited = !next;
          _favoriteCount += next ? -1 : 1;
        });
      }
    }
  }

  Future<void> _share() async {
    final String link =
        'https://app.meowdrama.com/drama/${widget.dramaId}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
    setState(() => _shareCount++);
    try {
      await _apiClient.post<dynamic>(
        Endpoints.dramaShare(widget.dramaId),
        data: <String, String>{'channel': 'copy_link'},
        authenticated: true,
      );
      unawaited(_loadInteractions());
    } catch (_) {
      if (mounted) setState(() => _shareCount--);
    }
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DramaCommentSheet(
        dramaId: widget.dramaId,
        apiClient: _apiClient,
        initialCount: _commentCount,
        onCountChanged: (int c) {
          if (mounted) setState(() => _commentCount = c);
        },
      ),
    );
  }

  void _openGifts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DramaGiftSheet(
        dramaId: widget.dramaId,
        apiClient: _apiClient,
        onSent: () => unawaited(_loadInteractions()),
      ),
    );
  }

  Future<void> _loadEpisodes() async {
    try {
      final response = await _apiClient
          .get<dynamic>(Endpoints.dramaEpisodes(widget.dramaId));
      final List<DramaEpisodeItem> episodes = _parseEpisodes(response.data);

      // Record a play view (24h dedup on backend)
      unawaited(_apiClient.post<dynamic>(
        Endpoints.dramaView(widget.dramaId),
        authenticated: true,
      ));

      int startIndex = 0;
      for (int i = 0; i < episodes.length; i++) {
        if (episodes[i].episodeNo == widget.startEpisodeNo) {
          startIndex = i;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _currentIndex = startIndex;
        _pageController = PageController(initialPage: startIndex);
        _loading = false;
      });

      if (episodes.isNotEmpty) {
        unawaited(_activateIndex(startIndex));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DramaEpisodeItem> _parseEpisodes(dynamic data) {
    List<dynamic> rows = const <dynamic>[];
    if (data is List) {
      rows = data;
    } else if (data is Map<String, dynamic>) {
      final dynamic r = data['results'] ?? data['episodes'];
      if (r is List) rows = r;
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_mapEpisode)
        .toList();
  }

  DramaEpisodeItem _mapEpisode(Map<String, dynamic> data) {
    final int? epNo = _parseInt(data['episode_no']) ??
        _parseInt(data['number']) ??
        _parseInt(data['order']);
    return DramaEpisodeItem(
      id: data['id']?.toString() ?? 'ep-${epNo ?? 0}',
      episodeNo: epNo,
      title: data['title'] as String? ?? 'Episode ${epNo ?? ''}',
      thumbnailUrl: data['thumbnail_url'] as String? ??
          data['cover_url'] as String?,
      canWatch: data['can_watch'] as bool? ?? false,
      isFree: data['is_free'] as bool? ?? false,
      isLocked: data['is_locked'] as bool? ?? false,
      pointsPrice: _parseInt(data['points_price']),
      creditsPrice: _parseInt(data['credits_price']),
      playableUrl: data['playback_url'] as String? ??
          data['video_url'] as String? ??
          data['hls_url'] as String? ??
          data['file_url'] as String?,
    );
  }

  int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _activateIndex(int index) async {
    _currentIndex = index;
    final DramaEpisodeItem ep = _episodes[index];
    final String? url = ep.playableUrl;

    if (ep.isLocked || url == null || url.isEmpty) {
      // Pause any currently playing controller so audio stops immediately.
      for (final VideoPlayerController c in _controllers.values) {
        await c.pause();
      }
      if (mounted) setState(() {});
      return;
    }

    if (!_controllers.containsKey(index)) {
      final VideoPlayerController c =
          VideoPlayerController.networkUrl(Uri.parse(url));
      _controllers[index] = c;
      await c.initialize();
      await c.setLooping(true);
    }
    await _controllers[index]?.play();
    await _disposeNonVisible(index);
    if (mounted) setState(() {});
  }

  Future<void> _disposeNonVisible(int visible) async {
    final List<int> stale =
        _controllers.keys.where((int k) => k != visible).toList();
    for (final int k in stale) {
      final VideoPlayerController? c = _controllers.remove(k);
      await c?.pause();
      await c?.dispose();
    }
  }

  Future<void> _togglePlayPause() async {
    final VideoPlayerController? c = _controllers[_currentIndex];
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  // After a successful unlock the API response has no playback_url.
  // Re-fetch the episode detail to get the real URL, then activate.
  Future<void> _reloadEpisodeAfterUnlock(int index) async {
    final DramaEpisodeItem ep = _episodes[index];
    final int? epNo = ep.episodeNo;
    if (epNo == null) return;
    try {
      final response = await _apiClient.get<dynamic>(
        Endpoints.dramaEpisodeDetail(widget.dramaId, epNo),
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is! Map<String, dynamic>) return;
      final String? url = data['playback_url'] as String? ??
          data['video_url'] as String? ??
          data['hls_url'] as String? ??
          data['file_url'] as String?;
      if (!mounted) return;
      setState(() {
        _episodes = List<DramaEpisodeItem>.from(_episodes)
          ..[index] = ep.copyWith(
            isLocked: false,
            canWatch: true,
            playableUrl: url,
          );
      });
    } catch (_) {
      // Best-effort: mark unlocked even without a fresh URL;
      // user can retry by re-entering the page.
      if (mounted) {
        setState(() {
          _episodes = List<DramaEpisodeItem>.from(_episodes)
            ..[index] = ep.copyWith(isLocked: false, canWatch: true);
        });
      }
    }
    _pageController?.jumpToPage(index);
    unawaited(_activateIndex(index));
  }

  void _showUnlockSheet(int index) {
    final DramaEpisodeItem ep = _episodes[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnlockSheet(
        episode: ep,
        dramaId: widget.dramaId,
        apiClient: _apiClient,
        onUnlocked: (_) => unawaited(_reloadEpisodeAfterUnlock(index)),
      ),
    );
  }

  void _jumpToEpisode(int index) {
    Navigator.of(context).pop();
    _pageController?.jumpToPage(index);
  }

  void _showEpisodeSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EpisodeSelectorSheet(
        episodes: _episodes,
        currentIndex: _currentIndex,
        seriesTitle: widget.seriesTitle,
        onSelect: _jumpToEpisode,
        onLockTap: (int index) {
          Navigator.of(context).pop();
          _showUnlockSheet(index);
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final VideoPlayerController c in _controllers.values) {
      c.pause();
      c.dispose();
    }
    _controllers.clear();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_episodes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Center(
                  child: Text('No episodes available.',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final DramaEpisodeItem current = _episodes[_currentIndex];
    final int epNo = current.episodeNo ?? widget.startEpisodeNo;
    final int total =
        widget.totalEpisodes ?? _episodes.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // ── Full-screen vertical episode PageView ──────────────────────
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _episodes.length,
            onPageChanged: (int i) => unawaited(_activateIndex(i)),
            itemBuilder: (BuildContext context, int i) {
              final DramaEpisodeItem ep = _episodes[i];

              if (ep.isLocked) {
                return _LockedEpisodeOverlay(
                  episode: ep,
                  onUnlock: () => _showUnlockSheet(i),
                );
              }

              final VideoPlayerController? c = _controllers[i];
              if (c == null || !c.value.isInitialized) {
                return const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Colors.white54, strokeWidth: 1.5),
                  ),
                );
              }
              return GestureDetector(
                onTap: _togglePlayPause,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              );
            },
          ),

          // ── Top overlay: back + episode label ─────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xAA000000), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'EP $epNo · ${widget.seriesTitle}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: <Shadow>[
                              Shadow(blurRadius: 6),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom bar: episodes selector trigger ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomEpisodeBar(
              currentEpNo: epNo,
              totalEpisodes: total,
              onTap: _showEpisodeSelector,
            ),
          ),

          // ── Right-side action column ───────────────────────────────────
          if (!current.isLocked)
            Positioned(
              right: 12,
              bottom: 80,
              child: _DramaActionColumn(
                dramaId: widget.dramaId,
                ownerAvatarUrl: _ownerAvatarUrl,
                subscribed: _subscribed,
                favorited: _favorited,
                favoriteCount: _favoriteCount,
                commentCount: _commentCount,
                shareCount: _shareCount,
                giftCount: _giftCount,
                danmakuEnabled: _danmakuEnabled,
                onSubscribe: _toggleSubscribe,
                onFavorite: _toggleFavorite,
                onComment: _openComments,
                onShare: _share,
                onGift: _openGifts,
                onToggleDanmaku: () =>
                    setState(() => _danmakuEnabled = !_danmakuEnabled),
              ),
            ),

          // ── Danmaku overlay ────────────────────────────────────────────
          if (_danmakuEnabled && _danmakuComments.isNotEmpty && !current.isLocked)
            Positioned.fill(
              child: IgnorePointer(
                child: DanmakuOverlay(
                  key: ValueKey<int>(_currentIndex),
                  comments: _danmakuComments,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom episode bar (locked to bottom, tap → modal sheet)
// ---------------------------------------------------------------------------

class _BottomEpisodeBar extends StatelessWidget {
  const _BottomEpisodeBar({
    required this.currentEpNo,
    required this.totalEpisodes,
    required this.onTap,
  });

  final int currentEpNo;
  final int totalEpisodes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.grid_view_rounded,
                color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              'Episodes  ·  All $totalEpisodes  ·  Free to Watch',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modal bottom sheet with episode grid
// ---------------------------------------------------------------------------

class _EpisodeSelectorSheet extends StatefulWidget {
  const _EpisodeSelectorSheet({
    required this.episodes,
    required this.currentIndex,
    required this.seriesTitle,
    required this.onSelect,
    this.onLockTap,
  });

  final List<DramaEpisodeItem> episodes;
  final int currentIndex;
  final String seriesTitle;
  final void Function(int index) onSelect;
  final void Function(int index)? onLockTap;

  @override
  State<_EpisodeSelectorSheet> createState() =>
      _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends State<_EpisodeSelectorSheet> {
  // Pagination: show episodes in groups of 30
  static const int _pageSize = 30;
  late int _groupIndex;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.currentIndex ~/ _pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final int groupCount =
        (widget.episodes.length / _pageSize).ceil();
    final int start = _groupIndex * _pageSize;
    final int end =
        (start + _pageSize).clamp(0, widget.episodes.length);
    final List<DramaEpisodeItem> pageEpisodes =
        widget.episodes.sublist(start, end);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, ScrollController scroll) {
        return ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.warmBackground.withValues(alpha: 0.88),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
            children: <Widget>[
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header: title + episode count
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.seriesTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${widget.episodes.length} EP',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Group tabs (1–30 / 31–60 / …)
              if (groupCount > 1)
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: groupCount,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, int gi) {
                      final int s = gi * _pageSize + 1;
                      final int e = ((gi + 1) * _pageSize)
                          .clamp(0, widget.episodes.length);
                      final bool selected = gi == _groupIndex;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _groupIndex = gi),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white12,
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$s–$e',
                            style: TextStyle(
                              color: selected
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),

              // Episode grid
              Expanded(
                child: GridView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: pageEpisodes.length,
                  itemBuilder: (_, int i) {
                    final int globalIndex = start + i;
                    final DramaEpisodeItem ep = pageEpisodes[i];
                    final bool isCurrent =
                        globalIndex == widget.currentIndex;
                    final bool locked = ep.isLocked;

                    return GestureDetector(
                      onTap: locked
                          ? () => widget.onLockTap?.call(globalIndex)
                          : () => widget.onSelect(globalIndex),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.white
                              : locked
                                  ? Colors.white10
                                  : Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: locked
                            ? const Icon(Icons.lock_outline,
                                color: Colors.white54, size: 14)
                            : Text(
                                '${ep.episodeNo ?? (globalIndex + 1)}',
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Dark gradient fallback when no thumbnail is available
class _LockedBg extends StatelessWidget {
  const _LockedBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1a1a2e), Color(0xFF0d0d1a)],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Locked episode overlay (shown in PageView when episode is locked)
// ────────────────────────────────────────────────────────────────────────────

class _LockedEpisodeOverlay extends StatelessWidget {
  const _LockedEpisodeOverlay({
    required this.episode,
    required this.onUnlock,
  });

  final DramaEpisodeItem episode;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final int? points = episode.pointsPrice;
    final int? credits = episode.creditsPrice;
    final String priceLabel = credits != null && credits > 0
        ? '$credits MC'
        : points != null && points > 0
            ? '$points MP'
            : 'Unlock';

    final String? thumb = episode.thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Thumbnail background
        if (thumb != null && thumb.isNotEmpty)
          AppCachedImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const _LockedBg(),
          )
        else
          const _LockedBg(),
        // Dark overlay so text is readable
        const ColoredBox(color: Color(0x99000000)),
        // Lock UI centred
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_rounded, color: Colors.white60, size: 48),
              const SizedBox(height: 12),
              Text(
                episode.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This episode requires unlocking',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: Text('Unlock · $priceLabel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: AppColors.warmBackground,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Unlock bottom sheet
// ────────────────────────────────────────────────────────────────────────────

class _UnlockSheet extends StatefulWidget {
  const _UnlockSheet({
    required this.episode,
    required this.dramaId,
    required this.apiClient,
    required this.onUnlocked,
  });

  final DramaEpisodeItem episode;
  final int dramaId;
  final ApiClient apiClient;
  final ValueChanged<Map<String, dynamic>> onUnlocked;

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  String _paymentMethod = 'meow_points';
  bool _unlocking = false;

  Future<void> _unlock() async {
    final int? episodeId = widget.episode.numericId;
    if (episodeId == null || _unlocking) return;
    setState(() => _unlocking = true);
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.dramaEpisodeUnlock(episodeId),
        data: <String, String>{'payment_method': _paymentMethod},
        authenticated: true,
      );
      final dynamic data = response.data;
      if (!mounted) return;
      Navigator.of(context).pop();
      if (data is Map<String, dynamic>) {
        widget.onUnlocked(data);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DramaEpisodeItem ep = widget.episode;
    final int? points = ep.pointsPrice;
    final int? credits = ep.creditsPrice;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.warmBackground.withValues(alpha: 0.55),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          const Icon(Icons.lock_rounded, color: Colors.white54, size: 28),
          const SizedBox(height: 8),
          Text(
            ep.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose payment method to unlock',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              if (points != null && points > 0)
                Expanded(
                  child: _UnlockOption(
                    label: 'Meow Points',
                    price: '$points MP',
                    selected: _paymentMethod == 'meow_points',
                    onTap: () =>
                        setState(() => _paymentMethod = 'meow_points'),
                  ),
                ),
              if (points != null && points > 0 &&
                  credits != null && credits > 0)
                const SizedBox(width: 10),
              if (credits != null && credits > 0)
                Expanded(
                  child: _UnlockOption(
                    label: 'Meow Credits',
                    price: '$credits cr',
                    selected: _paymentMethod == 'meow_credit',
                    onTap: () =>
                        setState(() => _paymentMethod = 'meow_credit'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _unlocking ? null : _unlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: AppColors.warmBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _unlocking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Unlock Episode',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _UnlockOption extends StatelessWidget {
  const _UnlockOption({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGold
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.brandGold : Colors.white24,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.warmBackground : Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                color: selected
                    ? AppColors.warmBackground.withValues(alpha: 0.7)
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Right-side action column for DramaPlayerPage
// ────────────────────────────────────────────────────────────────────────────

class _DramaActionColumn extends StatelessWidget {
  const _DramaActionColumn({
    required this.dramaId,
    required this.favorited,
    required this.favoriteCount,
    required this.commentCount,
    required this.shareCount,
    required this.giftCount,
    required this.danmakuEnabled,
    required this.onFavorite,
    required this.onComment,
    required this.onShare,
    required this.onGift,
    required this.onToggleDanmaku,
    required this.onSubscribe,
    this.ownerAvatarUrl,
    this.subscribed = false,
  });

  final int dramaId;
  final String? ownerAvatarUrl;
  final bool subscribed;
  final bool favorited;
  final int favoriteCount;
  final int commentCount;
  final int shareCount;
  final int giftCount;
  final bool danmakuEnabled;
  final VoidCallback onSubscribe;
  final VoidCallback onFavorite;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onGift;
  final VoidCallback onToggleDanmaku;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = ownerAvatarUrl != null && ownerAvatarUrl!.isNotEmpty
        ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(ownerAvatarUrl!))
        : const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Avatar + follow button
        GestureDetector(
          onTap: onSubscribe,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              avatar,
              if (!subscribed)
                Positioned(
                  bottom: -6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.brandGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          size: 14, color: AppColors.warmBackground),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _DramaActionIcon(
          icon: favorited ? Icons.favorite : Icons.favorite_border,
          label: favoriteCount.toString(),
          color: favorited ? AppColors.brandGold : Colors.white,
          onTap: onFavorite,
        ),
        _DramaActionIcon(
          icon: Icons.mode_comment_outlined,
          label: commentCount.toString(),
          onTap: onComment,
        ),
        _DramaActionIcon(
          icon: Icons.share_outlined,
          label: shareCount.toString(),
          onTap: onShare,
        ),
        _DramaActionIcon(
          icon: Icons.card_giftcard_outlined,
          label: giftCount.toString(),
          onTap: onGift,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: onToggleDanmaku,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: danmakuEnabled
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(
                danmakuEnabled ? Icons.subtitles : Icons.subtitles_off,
                size: 22,
                color: danmakuEnabled ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DramaActionIcon extends StatelessWidget {
  const _DramaActionIcon({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Comment sheet for DramaPlayerPage
// ────────────────────────────────────────────────────────────────────────────

class _DramaCommentSheet extends StatefulWidget {
  const _DramaCommentSheet({
    required this.dramaId,
    required this.apiClient,
    required this.initialCount,
    required this.onCountChanged,
  });

  final int dramaId;
  final ApiClient apiClient;
  final int initialCount;
  final ValueChanged<int> onCountChanged;

  @override
  State<_DramaCommentSheet> createState() => _DramaCommentSheetState();
}

class _DramaCommentSheetState extends State<_DramaCommentSheet> {
  final TextEditingController _inputCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await widget.apiClient
          .get<dynamic>(Endpoints.dramaComments(widget.dramaId));
      final dynamic data = response.data;
      List<dynamic> rows = const <dynamic>[];
      if (data is List) {
        rows = data;
      } else if (data is Map<String, dynamic>) {
        final dynamic r = data['results'] ?? data['comments'];
        if (r is List) rows = r;
      }
      if (!mounted) return;
      setState(() {
        _comments = rows.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
      widget.onCountChanged(_comments.length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.apiClient.post<dynamic>(
        Endpoints.dramaComments(widget.dramaId),
        data: <String, String>{'content': text},
        authenticated: true,
      );
      _inputCtrl.clear();
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ScrollController scroll) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.warmBackground.withValues(alpha: 0.88),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_comments.length} Comments',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white54))
                        : ListView.builder(
                            controller: scroll,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comments.length,
                            itemBuilder: (_, int i) {
                              final Map<String, dynamic> c = _comments[i];
                              final String author =
                                  (c['author_name'] ?? c['user'] ?? 'User')
                                      .toString();
                              final String body =
                                  (c['content'] ?? c['text'] ?? c['body'] ?? '')
                                      .toString();
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.white24,
                                      child: Icon(Icons.person,
                                          size: 16, color: Colors.white),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(author,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text(body,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: MediaQuery.of(context).padding.bottom + 8,
                      top: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _inputCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a comment…',
                              hintStyle:
                                  const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white12,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _send,
                          child: _sending
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.send_rounded,
                                  color: AppColors.brandGold, size: 28),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Gift sheet for DramaPlayerPage
// ────────────────────────────────────────────────────────────────────────────

class _DramaGiftSheet extends StatefulWidget {
  const _DramaGiftSheet({
    required this.dramaId,
    required this.apiClient,
    required this.onSent,
  });

  final int dramaId;
  final ApiClient apiClient;
  final VoidCallback onSent;

  @override
  State<_DramaGiftSheet> createState() => _DramaGiftSheetState();
}

class _DramaGiftSheetState extends State<_DramaGiftSheet> {
  static const List<int> _amounts = <int>[1, 10, 30, 100, 200, 500];

  int _selectedAmount = 30;
  String _paymentMethod = 'meow_points';
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.dramaGiftSend(widget.dramaId),
        data: <String, dynamic>{
          'amount': _selectedAmount,
          'payment_method': _paymentMethod,
        },
        authenticated: true,
      );
      if (!mounted) return;
      final dynamic data = response.data;
      final double? balance = data is Map<String, dynamic>
          ? _parseDecimal(data['sender_balance'])
          : null;
      final String unit =
          _paymentMethod == 'meow_credit' ? 'Credits' : 'Points';
      final String balanceNote =
          balance != null ? '  ·  Balance: ${_fmtBalance(balance)} $unit' : '';
      Navigator.of(context).pop();
      widget.onSent();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎁 Sent $_selectedAmount $unit$balanceNote'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.warmBackground.withValues(alpha: 0.82),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Send a Gift',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                ),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: _amounts.map((int a) {
                  final bool sel = a == _selectedAmount;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAmount = a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.brandGold
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.brandGold : Colors.white24,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$a',
                        style: TextStyle(
                          color: sel
                              ? AppColors.warmBackground
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _UnlockOption(
                      label: 'Meow Points',
                      price: '$_selectedAmount MP',
                      selected: _paymentMethod == 'meow_points',
                      onTap: () =>
                          setState(() => _paymentMethod = 'meow_points'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _UnlockOption(
                      label: 'Meow Credits',
                      price: '$_selectedAmount cr',
                      selected: _paymentMethod == 'meow_credit',
                      onTap: () =>
                          setState(() => _paymentMethod = 'meow_credit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGold,
                    foregroundColor: AppColors.warmBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Send Gift',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses int, double, or decimal-string values (e.g. "300.50") → double.
double? _parseDecimal(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Formats a balance double: integer if whole, 2dp otherwise.
String _fmtBalance(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}
