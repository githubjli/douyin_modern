import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/api_client.dart';
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
  });

  final bool enableVideo;
  final FeedRepository mockRepository;
  final FeedRepository? remoteRepository;
  final bool enableRemoteFeed;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final PageController _pageController;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};

  late final FeedRepository _remoteRepository;

  int _currentIndex = 0;
  List<FeedItem> _items = const <FeedItem>[];
  bool _loading = true;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _remoteRepository = widget.remoteRepository ??
        RemoteFeedRepository(apiClient: ApiClient());
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
        }
      } catch (_) {
        _notice = 'Network unavailable. Using local feed.';
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
      await _activateIndex(0);
    }
  }

  Future<void> _activateIndex(int index) async {
    _currentIndex = index;
    await _ensureController(index);

    final VideoPlayerController? active = _controllers[index];
    if (active != null && active.value.isInitialized) {
      await active.play();
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
              _activateIndex(index);
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
                  child: _ActionColumn(item: item),
                ),
                Positioned(
                  left: 12,
                  right: 90,
                  bottom: 115,
                  child: _CaptionBlock(item: item),
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

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person)),
        const SizedBox(height: 16),
        // TODO(meow-media): replace mock counter strings with backend metrics in a later phase.
        _ActionIcon(icon: Icons.favorite, label: item.likes),
        _ActionIcon(icon: Icons.mode_comment, label: item.comments),
        _ActionIcon(icon: Icons.share, label: item.shares),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 34, color: Colors.white),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
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
