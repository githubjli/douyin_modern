import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/route_observer.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_cached_image.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/feed_dao.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../../shared/danmaku_overlay.dart';
import '../creator_profile/presentation/creator_profile_page.dart';
import '../drama_player/drama_player_page.dart';
import 'data/mock_feed_repository.dart';
import 'data/remote_feed_repository.dart';
import 'domain/feed_item.dart';
import 'domain/feed_repository.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({
    super.key,
    this.enableVideo = true,
    this.mockRepository = const MockFeedRepository(),
    this.remoteRepository,
    this.enableRemoteFeed = true,
    this.isActive = true,
    this.networkRefreshTrigger = 0,
  });

  final bool enableVideo;
  final FeedRepository mockRepository;
  final FeedRepository? remoteRepository;
  final bool enableRemoteFeed;
  final bool isActive;
  /// Incremented by the shell when network connectivity is restored.
  /// FeedPage reloads automatically whenever this value changes.
  final int networkRefreshTrigger;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> with RouteAware {
  late final PageController _pageController;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};

  late final ApiClient _apiClient;
  late final FeedRepository _remoteRepository;

  int _currentIndex = 0;
  List<FeedItem> _items = const <FeedItem>[];
  // Fetched-but-not-yet-applied fresh items. Shown as a "new videos" chip
  // so the user can choose when to apply them instead of being interrupted.
  List<FeedItem> _pendingItems = const <FeedItem>[];
  bool _loading = true;
  String? _notice;
  bool _isOffline = false;
  bool _resumeOnTabActive = false;
  bool _danmakuEnabled = true;
  final Set<int> _viewedSeriesIds = <int>{};
  List<String> _danmakuComments = const <String>[];
  int _loadGeneration = 0;
  // Incremented each time _activateIndex is called. Stale activations
  // detect the mismatch after their awaits and abort — preventing disposed
  // controllers from calling play() or _disposeNonVisible on the wrong index.
  int _activateGeneration = 0;

  FeedDao get _dao => ref.read(feedDaoProvider);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _apiClient = ApiClient();
    _remoteRepository = widget.remoteRepository ??
        RemoteFeedRepository(apiClient: _apiClient);
    _loadFeed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  // Pause when another route is pushed on top (e.g. DramaPlayerPage).
  @override
  void didPushNext() {
    _controllers[_currentIndex]?.pause();
  }

  // Resume when we come back to the foreground.
  @override
  void didPopNext() {
    if (widget.isActive) {
      _controllers[_currentIndex]?.play();
    }
  }

  Future<void> _loadFeed() async {
    final int generation = ++_loadGeneration;

    // Step 1: show valid (within TTL) cache instantly — no spinner.
    final List<FeedItem>? cached = await _dao.loadFeed();
    if (generation != _loadGeneration || !mounted) return;

    if (cached != null && cached.isNotEmpty) {
      final int lastIndex = await _dao.loadLastIndex();
      if (generation != _loadGeneration || !mounted) return;
      setState(() {
        _items = cached;
        _loading = false;
        _isOffline = false;
        _notice = '正在更新内容…';
      });
      final int startIndex = lastIndex.clamp(0, cached.length - 1);
      // Don't await — video init must not block the network fetch below.
      if (widget.enableVideo) {
        unawaited(_activateIndex(startIndex, autoPlay: widget.isActive));
      }
    } else if (mounted) {
      setState(() => _loading = true);
    }

    // Step 2: fetch from network in background.
    if (widget.enableRemoteFeed) {
      try {
        final List<FeedItem> remoteItems =
            await _remoteRepository.getShortsFeed();
        if (generation != _loadGeneration || !mounted) return;
        final List<FeedItem> fresh = remoteItems
            .where((FeedItem item) =>
                item.videoUrl.isNotEmpty && item.isLocked != true)
            .toList();

        if (fresh.isNotEmpty) {
          await _dao.saveFeed(fresh);
          if (generation != _loadGeneration || !mounted) return;

          if (_items.isEmpty) {
            // No content yet — apply immediately.
            setState(() {
              _items = fresh;
              _loading = false;
              _isOffline = false;
              _notice = null;
              _pendingItems = const <FeedItem>[];
            });
            if (widget.enableVideo) {
              unawaited(_activateIndex(0, autoPlay: widget.isActive));
            }
          } else {
            // User is already watching — don't interrupt. Park fresh data
            // behind a "new videos" chip they can tap when ready.
            setState(() {
              _pendingItems = fresh;
              _isOffline = false;
              _notice = null;
            });
          }
          return;
        }
      } catch (error) {
        assert(() {
          debugPrint('[ShortFeed] network error: $error');
          return true;
        }());
      }
    }

    // Step 3: network failed or returned nothing.
    if (generation != _loadGeneration || !mounted) return;
    if (_items.isNotEmpty) {
      // Already showing (TTL-valid) cache — just update banner.
      setState(() {
        _isOffline = true;
        _notice = '无网络连接，显示缓存内容';
      });
    } else {
      // TTL expired or no cache — try loading stale cache before empty state.
      final List<FeedItem>? stale = await _dao.loadStale();
      if (generation != _loadGeneration || !mounted) return;
      if (stale != null && stale.isNotEmpty) {
        final int lastIndex = await _dao.loadLastIndex();
        if (generation != _loadGeneration || !mounted) return;
        setState(() {
          _items = stale;
          _loading = false;
          _isOffline = true;
          _notice = '无网络连接，显示上次缓存内容';
        });
        final int startIndex = lastIndex.clamp(0, stale.length - 1);
        if (widget.enableVideo) {
          unawaited(_activateIndex(startIndex, autoPlay: widget.isActive));
        }
      } else {
        // Truly no cache — show offline empty state.
        setState(() {
          _loading = false;
          _isOffline = true;
          _notice = null;
        });
      }
    }
  }

  /// Applies pending fresh items — called when the user taps the "new videos" chip.
  void _applyPending() {
    final List<FeedItem> fresh = _pendingItems;
    if (fresh.isEmpty) return;
    _saveCurrentProgress();
    setState(() {
      _items = fresh;
      _pendingItems = const <FeedItem>[];
      _notice = null;
    });
    unawaited(_dao.saveLastIndex(0));
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    if (widget.enableVideo) {
      unawaited(_activateIndex(0, autoPlay: widget.isActive));
    }
  }

  void _saveCurrentProgress() {
    final FeedItem? item =
        _currentIndex < _items.length ? _items[_currentIndex] : null;
    final int? episodeId = item?.episodeId;
    if (episodeId == null) return;
    final VideoPlayerController? ctrl = _controllers[_currentIndex];
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final int seconds = ctrl.value.position.inSeconds;
    if (seconds > 0) {
      unawaited(_dao.saveProgress(episodeId, seconds));
    }
  }

  void _postViewStat(int index) {
    final int? seriesId = _items[index].seriesId;
    if (seriesId == null || _viewedSeriesIds.contains(seriesId)) return;
    _viewedSeriesIds.add(seriesId);
    _apiClient
        .post<dynamic>(Endpoints.dramaView(seriesId), authenticated: true)
        .ignore();
  }

  Future<void> _loadDanmaku(int index) async {
    if (index >= _items.length) return;
    final int? dramaId = _items[index].seriesId;
    if (dramaId == null) return;
    try {
      final response = await _apiClient.get<dynamic>(
        Endpoints.dramaComments(dramaId),
      );
      final List<String> comments = _parseComments(response.data);
      if (mounted && comments.isNotEmpty) {
        setState(() => _danmakuComments = comments);
      }
    } catch (_) {}
  }

  List<String> _parseComments(dynamic data) {
    final List<dynamic> rows = data is List<dynamic>
        ? data
        : data is Map<String, dynamic>
            ? ((data['results'] ?? data['comments'] ?? const <dynamic>[])
                as List<dynamic>)
            : const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> m) =>
            ((m['content'] ?? m['text'] ?? m['body'] ?? '') as Object)
                .toString()
                .trim())
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _activateIndex(int index, {bool autoPlay = true}) async {
    final int generation = ++_activateGeneration;
    _currentIndex = index;
    if (mounted) setState(() => _danmakuComments = const <String>[]);
    if (autoPlay) _postViewStat(index);
    unawaited(_loadDanmaku(index));

    // Immediately silence any currently playing controllers so there is no
    // audio overlap while the new controller is initialising.
    for (final VideoPlayerController ctrl in _controllers.values) {
      if (ctrl.value.isInitialized && ctrl.value.isPlaying) {
        unawaited(ctrl.pause());
      }
    }

    await _ensureController(index);

    // Abort if a newer _activateIndex call has started while we were awaiting.
    if (generation != _activateGeneration || !mounted) return;

    final VideoPlayerController? active = _controllers[index];
    if (active != null && active.value.isInitialized) {
      // Re-check isActive: the tab may have been switched while we were
      // awaiting init. Playing in the background causes audio-only leakage.
      if (autoPlay && widget.isActive) {
        await active.play();
      } else {
        await active.pause();
      }
    }

    if (generation != _activateGeneration || !mounted) return;

    await _disposeNonVisible(index);
    if (mounted) setState(() {});

    // Silently pre-initialise adjacent videos so swiping in either direction
    // doesn't hit a cold-start init delay.
    for (final int adj in [index + 1, index - 1]) {
      if (adj >= 0 && adj < _items.length && !_controllers.containsKey(adj)) {
        unawaited(_ensureController(adj));
      }
    }
  }

  Future<void> _ensureController(int index) async {
    if (_controllers.containsKey(index)) return;

    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(_items[index].videoUrl),
    );
    _controllers[index] = controller;
    try {
      await controller.initialize();
    } catch (_) {
      // Initialisation can fail if the controller was disposed mid-flight
      // (e.g. user swiped away before the network buffered). Remove it so the
      // next _activateIndex call starts fresh for this index.
      _controllers.remove(index);
      return;
    }
    await controller.setLooping(true);

    // Restore saved progress for this episode.
    final int? episodeId = _items[index].episodeId;
    if (episodeId != null) {
      final int? savedSeconds = await _dao.loadProgress(episodeId);
      if (savedSeconds != null && savedSeconds > 0) {
        final Duration total = controller.value.duration;
        final Duration seek = Duration(seconds: savedSeconds);
        // Only seek if there's meaningful progress and it's not at the very end.
        if (total > Duration.zero && seek < total - const Duration(seconds: 3)) {
          await controller.seekTo(seek);
        }
      }
    }
  }

  Future<void> _disposeNonVisible(int visibleIndex) async {
    // Keep prev + current + next so back-navigation doesn't re-init from scratch.
    final List<int> stale = _controllers.keys
        .where((int key) => (key - visibleIndex).abs() > 1)
        .toList();
    for (final int key in stale) {
      final VideoPlayerController? controller = _controllers.remove(key);
      if (controller != null) {
        // Only pause if initialised — calling pause() on an uninitialised
        // controller can throw or behave unpredictably.
        if (controller.value.isInitialized) {
          await controller.pause();
        }
        await controller.dispose();
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (!widget.enableVideo) {
      return;
    }

    final VideoPlayerController? controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant FeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Network restored → reload feed (respects TTL; will be fast if cache is fresh).
    if (oldWidget.networkRefreshTrigger != widget.networkRefreshTrigger) {
      unawaited(_loadFeed());
    }

    if (oldWidget.isActive == widget.isActive || !widget.enableVideo || _items.isEmpty) {
      return;
    }

    final VideoPlayerController? active = _controllers[_currentIndex];

    if (!widget.isActive) {
      final bool wasPlaying =
          active != null && active.value.isInitialized && active.value.isPlaying;
      _resumeOnTabActive = wasPlaying;
      if (wasPlaying) {
        unawaited(active.pause());
      }
      return;
    }

    if (_controllers.containsKey(_currentIndex)) {
      if (_resumeOnTabActive) {
        unawaited(active?.play());
      }
      _resumeOnTabActive = false;
      return;
    }

    // No controller present — either it was never created or it was cleared
    // mid-init when the tab switched away. Always autoplay on return so the
    // user doesn't land on a silent, frozen frame.
    unawaited(_activateIndex(_currentIndex, autoPlay: true));
    _resumeOnTabActive = false;
  }

  @override
  void dispose() {
    _saveCurrentProgress();
    appRouteObserver.unsubscribe(this);
    _pageController.dispose();
    for (final VideoPlayerController controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return _OfflineEmptyState(onRetry: _loadFeed);
    }

    return Stack(
      children: <Widget>[
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _items.length,
          onPageChanged: (int index) {
            _saveCurrentProgress();
            _currentIndex = index;
            unawaited(_dao.saveLastIndex(index));
            if (widget.enableVideo) {
              _activateIndex(index, autoPlay: widget.isActive);
            } else {
              setState(() {});
            }
          },
          itemBuilder: (BuildContext context, int index) {
            final FeedItem item = _items[index];
            final VideoPlayerController? controller = _controllers[index];

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: index == _currentIndex ? _togglePlayPause : null,
                  child: _FeedBackground(
                    item: item,
                    enableVideo: widget.enableVideo,
                    controller: controller,
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 120,
                  child: _ActionColumn(
                    item: item,
                    apiClient: _apiClient,
                    danmakuEnabled: _danmakuEnabled,
                    onToggleDanmaku: () =>
                        setState(() => _danmakuEnabled = !_danmakuEnabled),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 90,
                  bottom: 150,
                  child: _CaptionBlock(item: item),
                ),
                if (item.seriesId != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _WatchFullDramaBanner(item: item),
                  ),
                if (index == _currentIndex &&
                    _danmakuEnabled &&
                    _danmakuComments.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DanmakuOverlay(
                        key: ValueKey<String>('danmaku_$_currentIndex'),
                        comments: _danmakuComments,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_notice != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _NoticeBanner(message: _notice!, isOffline: _isOffline),
          ),
        if (_pendingItems.isNotEmpty)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _NewVideosBadge(
                count: _pendingItems.length,
                onTap: _applyPending,
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedBackground extends StatelessWidget {
  const _FeedBackground({
    required this.item,
    required this.enableVideo,
    required this.controller,
  });

  final FeedItem item;
  final bool enableVideo;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    if (!enableVideo) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: item.placeholderGradient,
          ),
        ),
      );
    }

    if (controller == null || !controller!.value.isInitialized) {
      // controller != null means it exists but is still initialising — show spinner.
      final bool initialising = controller != null;
      final String? thumb = item.thumbnailUrl;
      if (thumb != null && thumb.isNotEmpty) {
        return AppCachedImage(
          imageUrl: thumb,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => _Placeholder(item: item, showSpinner: initialising),
          errorWidget: (context, url, error) => _Placeholder(item: item, showSpinner: initialising),
        );
      }
      return _Placeholder(item: item, showSpinner: initialising);
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller!.value.size.width,
        height: controller!.value.size.height,
        child: VideoPlayer(controller!),
      ),
    );
  }
}

// Gradient placeholder shown while the video controller is initialising
// and no thumbnail URL is available (or thumbnail fails to load).
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.item, this.showSpinner = false});
  final FeedItem item;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: item.placeholderGradient,
              ),
            ),
          ),
          if (showSpinner)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                ),
              ),
            ),
        ],
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Action column – stateful, wired to backend APIs
// ────────────────────────────────────────────────────────────────────────────

class _ActionColumn extends StatefulWidget {
  const _ActionColumn({
    required this.item,
    required this.apiClient,
    this.danmakuEnabled = true,
    this.onToggleDanmaku,
  });

  final FeedItem item;
  final ApiClient apiClient;
  final bool danmakuEnabled;
  final VoidCallback? onToggleDanmaku;

  @override
  State<_ActionColumn> createState() => _ActionColumnState();
}

class _ActionColumnState extends State<_ActionColumn> {
  late bool _subscribed;
  late bool _favorited;
  late int _favoriteCount;
  late int _commentCount;
  late int _shareCount;
  late int _giftCount;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final FeedItem item = widget.item;
    _subscribed = item.viewerIsSubscribed ?? false;
    _favorited = item.isFavorited ?? false;
    _favoriteCount = item.favoriteCount ?? item.likeCount ?? 0;
    _commentCount = item.commentCount ?? 0;
    _shareCount = item.shareCount ?? 0;
    _giftCount = item.giftCount ?? 0;

    if (item.seriesId != null) {
      _refreshSummary(item.seriesId!);
    }
  }

  Future<void> _refreshSummary(int seriesId) async {
    try {
      final response = await widget.apiClient.get<dynamic>(
        Endpoints.dramaInteractionSummary(seriesId),
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is! Map<String, dynamic>) return;
      if (!mounted) return;
      setState(() {
        // API returns viewer_is_favorited in interaction-summary
        _favorited = (data['viewer_is_favorited'] as bool?) ??
            (data['is_favorited'] as bool?) ??
            _favorited;
        _favoriteCount = (data['favorite_count'] as int?) ?? _favoriteCount;
        _commentCount = (data['comment_count'] as int?) ?? _commentCount;
        _shareCount = (data['share_count'] as int?) ?? _shareCount;
        _giftCount = (data['gift_count'] as int?) ?? _giftCount;
        _subscribed = (data['viewer_is_following'] as bool?) ??
            (data['viewer_is_subscribed'] as bool?) ??
            _subscribed;
      });
    } catch (_) {
      // best-effort — keep local state
    }
  }

  void _openCreatorProfile() {
    final int? ownerId = int.tryParse(widget.item.ownerId ?? '');
    if (ownerId == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfilePage(creatorId: ownerId),
      ),
    );
  }

  Future<void> _toggleSubscribe() async {
    if (_busy) return;
    final int? ownerId = int.tryParse(widget.item.ownerId ?? '');
    if (ownerId == null) return;
    final int? seriesId = widget.item.seriesId;
    final bool next = !_subscribed;
    setState(() {
      _subscribed = next;
      _busy = true;
    });
    try {
      if (next) {
        await widget.apiClient.post<dynamic>(
          Endpoints.channelSubscribe(ownerId),
          authenticated: true,
        );
      } else {
        await widget.apiClient.delete<dynamic>(
          Endpoints.channelSubscribe(ownerId),
          authenticated: true,
        );
      }
      if (seriesId != null) unawaited(_refreshSummary(seriesId));
    } catch (_) {
      if (mounted) setState(() => _subscribed = !next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;
    final int? seriesId = widget.item.seriesId;
    if (seriesId == null) return;
    final bool next = !_favorited;
    setState(() {
      _favorited = next;
      _favoriteCount += next ? 1 : -1;
      _busy = true;
    });
    try {
      if (next) {
        await widget.apiClient.post<dynamic>(
          Endpoints.dramaFavorite(seriesId),
          authenticated: true,
        );
      } else {
        await widget.apiClient.delete<dynamic>(
          Endpoints.dramaFavorite(seriesId),
          authenticated: true,
        );
      }
      unawaited(_refreshSummary(seriesId));
    } catch (_) {
      if (mounted) {
        setState(() {
          _favorited = !next;
          _favoriteCount += next ? -1 : 1;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final int? seriesId = widget.item.seriesId;
    final String link =
        'https://app.meowdrama.com/drama/${seriesId ?? widget.item.id ?? ''}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
    if (seriesId == null) return;
    setState(() => _shareCount++);
    try {
      await widget.apiClient.post<dynamic>(
        Endpoints.dramaShare(seriesId),
        data: <String, String>{'channel': 'copy_link'},
        authenticated: true,
      );
      unawaited(_refreshSummary(seriesId));
    } catch (_) {
      if (mounted) setState(() => _shareCount--);
    }
  }

  void _openComments() {
    final int? seriesId = widget.item.seriesId;
    if (seriesId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        seriesId: seriesId,
        apiClient: widget.apiClient,
        initialCount: _commentCount,
        onCountChanged: (int count) {
          if (mounted) setState(() => _commentCount = count);
        },
      ),
    );
  }

  void _openGifts() {
    final int? seriesId = widget.item.seriesId;
    if (seriesId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftSheet(
        seriesId: seriesId,
        apiClient: widget.apiClient,
        onSent: () {
          // gift_count comes from interaction-summary, not the send response
          if (mounted) unawaited(_refreshSummary(seriesId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FeedItem item = widget.item;

    Widget avatar;
    if (item.ownerAvatarUrl != null && item.ownerAvatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(item.ownerAvatarUrl!),
      );
    } else {
      avatar = const CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white24,
        child: Icon(Icons.person, color: Colors.white),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Avatar → creator profile; "+" badge → follow
        GestureDetector(
          onTap: _openCreatorProfile,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              avatar,
              if (!_subscribed)
                Positioned(
                  bottom: -6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _toggleSubscribe,
                      behavior: HitTestBehavior.opaque,
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
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ActionIcon(
          icon: _favorited ? Icons.favorite : Icons.favorite_border,
          label: _favoriteCount.toString(),
          color: _favorited ? AppColors.brandGold : Colors.white,
          onTap: _toggleFavorite,
        ),
        _ActionIcon(
          icon: Icons.mode_comment_outlined,
          label: _commentCount.toString(),
          onTap: _openComments,
        ),
        _ActionIcon(
          icon: Icons.share_outlined,
          label: _shareCount.toString(),
          onTap: _share,
        ),
        _ActionIcon(
          icon: Icons.card_giftcard_outlined,
          label: _giftCount.toString(),
          onTap: _openGifts,
        ),
        _DanmakuToggleButton(
          enabled: widget.danmakuEnabled,
          onTap: widget.onToggleDanmaku,
        ),
      ],
    );
  }
}

class _DanmakuToggleButton extends StatelessWidget {
  const _DanmakuToggleButton({required this.enabled, this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
          ),
          child: Icon(
            enabled ? Icons.subtitles : Icons.subtitles_off,
            size: 22,
            color: enabled ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
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
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Icon(icon, size: 34, color: color),
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
// Gift bottom sheet
// ────────────────────────────────────────────────────────────────────────────

class _GiftSheet extends StatefulWidget {
  const _GiftSheet({
    required this.seriesId,
    required this.apiClient,
    required this.onSent,
  });

  final int seriesId;
  final ApiClient apiClient;
  final VoidCallback onSent;

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  static const List<int> _amounts = <int>[1, 10, 30, 100, 200, 500];

  int _selectedAmount = 30;
  String _paymentMethod = 'meow_points';
  bool _sending = false;

  Future<void> _sendGift() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.dramaGiftSend(widget.seriesId),
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
      // gift_count not in response — parent triggers _refreshSummary
      widget.onSent();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🎁 Sent $_selectedAmount $unit$balanceNote'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final String msg = _friendlyGiftError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendlyGiftError(String raw) {
    if (raw.contains('insufficient_balance')) {
      return 'Not enough balance to send this gift.';
    }
    if (raw.contains('receiver_unavailable')) {
      return 'This drama has no owner to receive gifts.';
    }
    if (raw.contains('drama_unavailable')) {
      return 'This drama is not available for gifts.';
    }
    return raw;
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
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
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
                fontSize: 16,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Amount picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _amounts.map((int amount) {
                final bool selected = _selectedAmount == amount;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAmount = amount),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 72,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandGold
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.brandGold
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('🎁', style: TextStyle(fontSize: 14)),
                        Text(
                          '$amount',
                          style: TextStyle(
                            color: selected
                                ? AppColors.warmBackground
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Payment method toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                const Text('Pay with:',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(width: 12),
                _PayToggle(
                  label: 'Points',
                  value: 'meow_points',
                  selected: _paymentMethod == 'meow_points',
                  onTap: () =>
                      setState(() => _paymentMethod = 'meow_points'),
                ),
                const SizedBox(width: 8),
                _PayToggle(
                  label: 'Credits',
                  value: 'meow_credit',
                  selected: _paymentMethod == 'meow_credit',
                  onTap: () =>
                      setState(() => _paymentMethod = 'meow_credit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Send button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _sending ? null : _sendGift,
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
                    : Text(
                        'Send $_selectedAmount Gift${_selectedAmount > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      );
  }
}

class _PayToggle extends StatelessWidget {
  const _PayToggle({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandGold : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.warmBackground : Colors.white60,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Comment bottom sheet
// ────────────────────────────────────────────────────────────────────────────

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.seriesId,
    required this.apiClient,
    required this.initialCount,
    required this.onCountChanged,
  });

  final int seriesId;
  final ApiClient apiClient;
  final int initialCount;
  final ValueChanged<int> onCountChanged;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final response = await widget.apiClient.get<dynamic>(
        Endpoints.dramaComments(widget.seriesId),
        authenticated: true,
      );
      final dynamic data = response.data;
      List<dynamic> rows = const <dynamic>[];
      if (data is List) {
        rows = data;
      } else if (data is Map<String, dynamic>) {
        final dynamic results = data['results'];
        if (results is List) rows = results;
      }
      if (!mounted) return;
      setState(() {
        _comments = rows
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
      widget.onCountChanged(_comments.length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.dramaComments(widget.seriesId),
        data: <String, String>{'content': text},
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _comments.insert(0, data);
            _inputCtrl.clear();
          });
          widget.onCountChanged(_comments.length);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: AppColors.warmBackground.withValues(alpha: 0.82),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${widget.initialCount} Comments',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text('No comments yet',
                            style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (BuildContext ctx, int i) {
                          final Map<String, dynamic> c = _comments[i];
                          final String author =
                              c['author_name'] as String? ??
                                  c['username'] as String? ??
                                  'User';
                          final String content =
                              c['content'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.person,
                                      size: 18, color: Colors.white70),
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
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(content,
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
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding:
                EdgeInsets.fromLTRB(12, 8, 12, bottom > 0 ? bottom + 8 : 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _postComment,
                  child: _posting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _WatchFullDramaBanner extends StatelessWidget {
  const _WatchFullDramaBanner({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final int total = item.episodeNo ?? 0;
    final String label = total > 0
        ? 'Watch Full Drama  ·  EP $total'
        : 'Watch Full Drama';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DramaPlayerPage(
            dramaId: item.seriesId!,
            seriesTitle: item.seriesTitle ?? 'Drama',
            startEpisodeNo: item.episodeNo ?? 1,
          ),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xBB000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.play_circle_outline_rounded,
                color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CaptionBlock extends StatelessWidget {
  const _CaptionBlock({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final bool hasDramaMeta =
        item.seriesTitle != null && item.episodeNo != null && item.title != null;

    final String seriesLabel = hasDramaMeta
        ? item.seriesTitle!
        : (item.username.isNotEmpty ? item.username : '@MeowDrama');

    final String episodeLabel = hasDramaMeta
        ? 'EP ${item.episodeNo} · ${item.title}'
        : item.description;

    String? accessLabel;
    if (item.isLocked == true) {
      if (item.pointsPrice != null && item.pointsPrice! > 0) {
        accessLabel = '${item.pointsPrice} MP';
      } else {
        accessLabel = 'Locked';
      }
    } else if (item.canWatch == true) {
      accessLabel = 'Free';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          seriesLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.cocoaText,
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          episodeLabel,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.cocoaText,
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
        if (accessLabel != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            accessLabel,
            style: const TextStyle(
              color: AppColors.mutedOliveText,
              fontSize: 12,
              shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 8)],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '♫ ${item.music}',
          style: const TextStyle(
            color: AppColors.mutedOliveText,
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ],
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

// ---------------------------------------------------------------------------
// Offline empty state — shown when there's no cache and no network.
// ---------------------------------------------------------------------------

class _OfflineEmptyState extends StatelessWidget {
  const _OfflineEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.wifi_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              '无网络连接',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请检查网络后重试',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                '重新加载',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notice banner — updating vs offline use different accent colours.
// ---------------------------------------------------------------------------

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message, required this.isOffline});

  final String message;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final Color bg = isOffline
        ? Colors.orange.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.55);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isOffline ? Icons.wifi_off : Icons.sync,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message,
                style:
                    const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// "New videos" floating chip — shown when fresh content arrived in background
// without interrupting the current session. Tapping applies the new feed.
// ---------------------------------------------------------------------------

class _NewVideosBadge extends StatelessWidget {
  const _NewVideosBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.arrow_upward_rounded,
                size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              '$count new videos',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
