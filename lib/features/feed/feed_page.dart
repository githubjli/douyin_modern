import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../drama_player/drama_player_page.dart';
import 'data/mock_feed_repository.dart';
import 'data/remote_feed_repository.dart';
import 'domain/feed_item.dart';
import 'domain/feed_repository.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    this.enableVideo = true,
    this.mockRepository = const MockFeedRepository(),
    this.remoteRepository,
    this.enableRemoteFeed = true,
    this.isActive = true,
  });

  final bool enableVideo;
  final FeedRepository mockRepository;
  final FeedRepository? remoteRepository;
  final bool enableRemoteFeed;
  final bool isActive;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final PageController _pageController;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};

  late final ApiClient _apiClient;
  late final FeedRepository _remoteRepository;

  int _currentIndex = 0;
  List<FeedItem> _items = const <FeedItem>[];
  bool _loading = true;
  String? _notice;
  bool _resumeOnTabActive = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _apiClient = ApiClient();
    _remoteRepository = widget.remoteRepository ??
        RemoteFeedRepository(apiClient: _apiClient);
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _notice = null;
      });
    }

    List<FeedItem> items = const <FeedItem>[];

    if (widget.enableRemoteFeed) {
      try {
        final List<FeedItem> remoteItems = await _remoteRepository.getShortsFeed();
        items = remoteItems
            .where((FeedItem item) =>
                item.videoUrl.isNotEmpty && item.isLocked != true)
            .toList();
        if (items.isEmpty) {
          _notice = 'Using local fallback feed.';
          assert(() {
            debugPrint('[ShortFeed] fallback reason: remote returned zero playable drama episodes');
            return true;
          }());
        }
      } catch (error) {
        _notice = 'Network unavailable. Using local feed.';
        assert(() {
          debugPrint('[ShortFeed] fallback reason: remote fetch error - $error');
          return true;
        }());
      }
    }

    if (items.isEmpty) {
      final List<FeedItem> mockItems = await widget.mockRepository.getShortsFeed();
      items = mockItems;
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });

    if (widget.enableVideo && _items.isNotEmpty) {
      await _activateIndex(0, autoPlay: widget.isActive);
    }
  }

  Future<void> _activateIndex(int index, {bool autoPlay = true}) async {
    _currentIndex = index;
    await _ensureController(index);

    final VideoPlayerController? active = _controllers[index];
    if (active != null && active.value.isInitialized) {
      if (autoPlay) {
        await active.play();
      } else {
        await active.pause();
      }
    }

    await _disposeNonVisible(index);
    if (mounted) setState(() {});
  }

  Future<void> _ensureController(int index) async {
    if (_controllers.containsKey(index)) return;

    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(_items[index].videoUrl),
    );
    _controllers[index] = controller;
    await controller.initialize();
    await controller.setLooping(true);
  }

  Future<void> _disposeNonVisible(int visibleIndex) async {
    final List<int> stale =
        _controllers.keys.where((int key) => key != visibleIndex).toList();
    for (final int key in stale) {
      final VideoPlayerController? controller = _controllers.remove(key);
      if (controller != null) {
        await controller.pause();
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

    unawaited(_activateIndex(_currentIndex, autoPlay: _resumeOnTabActive));
    _resumeOnTabActive = false;
  }

  @override
  void dispose() {
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
      return const ColoredBox(color: Colors.black);
    }

    return Stack(
      children: <Widget>[
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _items.length,
          onPageChanged: (int index) {
            _currentIndex = index;
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
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 90,
                  bottom: 115,
                  child: _CaptionBlock(item: item),
                ),
                if (item.seriesId != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _WatchFullDramaBanner(item: item),
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _notice!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
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
      return Container(color: Colors.black);
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

// ────────────────────────────────────────────────────────────────────────────
// Action column – stateful, wired to backend APIs
// ────────────────────────────────────────────────────────────────────────────

class _ActionColumn extends StatefulWidget {
  const _ActionColumn({required this.item, required this.apiClient});

  final FeedItem item;
  final ApiClient apiClient;

  @override
  State<_ActionColumn> createState() => _ActionColumnState();
}

class _ActionColumnState extends State<_ActionColumn> {
  late bool _subscribed;
  late bool _favorited;
  late int _favoriteCount;
  late int _commentCount;
  late int _shareCount;

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
        _favorited = (data['is_favorited'] as bool?) ?? _favorited;
        _favoriteCount = (data['favorite_count'] as int?) ?? _favoriteCount;
        _commentCount = (data['comment_count'] as int?) ?? _commentCount;
        _shareCount = (data['share_count'] as int?) ?? _shareCount;
        _subscribed =
            (data['viewer_is_subscribed'] as bool?) ?? _subscribed;
      });
    } catch (_) {
      // best-effort — keep local state
    }
  }

  Future<void> _toggleSubscribe() async {
    if (_busy) return;
    final int? ownerId = int.tryParse(widget.item.ownerId ?? '');
    if (ownerId == null) return;
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
        GestureDetector(
          onTap: _toggleSubscribe,
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
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          size: 14, color: Colors.white),
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
          color: _favorited ? Colors.red : Colors.white,
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
          label: item.gifts,
        ),
      ],
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
        accessLabel = '${item.pointsPrice} Points';
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
