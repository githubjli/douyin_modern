import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FeedItem {
  const FeedItem({
    required this.username,
    required this.description,
    required this.music,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.videoUrl,
  });

  final String username;
  final String description;
  final String music;
  final String likes;
  final String comments;
  final String shares;
  final String videoUrl;
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const List<FeedItem> _items = <FeedItem>[
    FeedItem(
      username: '@citywalker',
      description: 'Night street vibes in neon lights ✨',
      music: 'Original Sound - Citywalker',
      likes: '24.1K',
      comments: '1,203',
      shares: '318',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
    FeedItem(
      username: '@foodlab',
      description: 'Crispy ramen experiment #food #kitchen',
      music: 'Lo-fi Beat - Foodlab',
      likes: '11.6K',
      comments: '522',
      shares: '92',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    ),
    FeedItem(
      username: '@travelkid',
      description: 'Sunrise above the clouds ☁️',
      music: 'Ambient Rise - Travelkid',
      likes: '54.8K',
      comments: '3,883',
      shares: '1,002',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
  ];

  late final PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = <int, VideoPlayerController>{};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _activateIndex(0);
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
    final List<int> stale = _controllers.keys.where((int key) => key != visibleIndex).toList();
    for (final int key in stale) {
      final VideoPlayerController? controller = _controllers.remove(key);
      if (controller != null) {
        await controller.pause();
        await controller.dispose();
      }
    }
  }

  Future<void> _togglePlayPause() async {
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
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _items.length,
      onPageChanged: (int index) => _activateIndex(index),
      itemBuilder: (BuildContext context, int index) {
        final FeedItem item = _items[index];
        final VideoPlayerController? controller = _controllers[index];

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: index == _currentIndex ? _togglePlayPause : null,
              child: _FeedVideoBackground(controller: controller),
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

class _FeedVideoBackground extends StatelessWidget {
  const _FeedVideoBackground({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
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
        const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.person)),
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
        Text(item.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text('♫ ${item.music}', style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
