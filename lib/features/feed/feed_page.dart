import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'data/mock_feed_repository.dart';
import 'domain/feed_item.dart';
import 'domain/feed_repository.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    this.enableVideo = true,
    this.repository = const MockFeedRepository(),
  });

  final bool enableVideo;
  final FeedRepository repository;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final PageController _pageController;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};
  int _currentIndex = 0;
  List<FeedItem> _items = const <FeedItem>[];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    final List<FeedItem> items = await widget.repository.getShortsFeed();
    if (!mounted) return;
    setState(() => _items = items);
    if (widget.enableVideo && _items.isNotEmpty) {
      _activateIndex(0);
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
    if (_items.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }

    return PageView.builder(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(item.username,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text('♫ ${item.music}', style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
