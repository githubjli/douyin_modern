import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class FeedItem {
  const FeedItem({
    required this.username,
    required this.seriesTitle,
    required this.description,
    required this.music,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.videoUrl,
    required this.placeholderGradient,
    required this.tags,
    required this.isSeries,
    this.episodeLabel,
    this.seriesCta,
  });

  final String username;
  final String seriesTitle;
  final String description;
  final String music;
  final String likes;
  final String comments;
  final String saves;
  final String shares;
  final String videoUrl;
  final List<Color> placeholderGradient;
  final List<String> tags;
  final bool isSeries;
  final String? episodeLabel;
  final String? seriesCta;
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.enableVideo = true});

  final bool enableVideo;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const List<FeedItem> _items = <FeedItem>[
    FeedItem(
      username: '@citywalker',
      seriesTitle: 'Neon City Diaries',
      description: 'Night street vibes in neon lights ✨',
      music: 'Original Sound - Citywalker',
      likes: '24.1K',
      comments: '1,203',
      saves: '980',
      shares: '318',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      placeholderGradient: <Color>[Color(0xFF111111), Color(0xFF2C2C2C)],
      tags: <String>['#city', '#night', '#vlog'],
      isSeries: false,
    ),
    FeedItem(
      username: '@drama.club',
      seriesTitle: 'Moonlight Oath',
      description: 'She returns to the city with one hidden mission.',
      music: 'Cinematic Strings',
      likes: '88.2K',
      comments: '5,722',
      saves: '14.6K',
      shares: '3,102',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      placeholderGradient: <Color>[Color(0xFF000000), Color(0xFF3D1A1A)],
      tags: <String>['#shortdrama', '#romance'],
      isSeries: true,
      episodeLabel: 'Episode 12',
      seriesCta: 'Watch full series · 70 episodes',
    ),
    FeedItem(
      username: '@travelkid',
      seriesTitle: 'Sunrise Above Clouds',
      description: 'Sunrise above the clouds ☁️',
      music: 'Ambient Rise - Travelkid',
      likes: '54.8K',
      comments: '3,883',
      saves: '9,401',
      shares: '1,002',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      placeholderGradient: <Color>[Color(0xFF0A0A0A), Color(0xFF1B2F45)],
      tags: <String>['#travel', '#sunrise'],
      isSeries: false,
    ),
  ];

  late final PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = <int, VideoPlayerController>{};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.enableVideo) {
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
            const Positioned(top: 50, left: 12, right: 12, child: _TopOverlayTabs()),
            Positioned(
              right: 12,
              bottom: 170,
              child: _ActionRail(item: item),
            ),
            Positioned(
              left: 12,
              right: 90,
              bottom: item.isSeries ? 130 : 105,
              child: _MetaBlock(item: item),
            ),
            if (item.isSeries)
              Positioned(
                left: 12,
                right: 12,
                bottom: 90,
                child: _SeriesCtaBar(text: item.seriesCta ?? ''),
              ),
          ],
        );
      },
    );
  }
}

class _TopOverlayTabs extends StatelessWidget {
  const _TopOverlayTabs();

  @override
  Widget build(BuildContext context) {
    final List<String> tabs = <String>['For You', 'Shorts', 'Series', 'Live'];
    return Row(
      children: <Widget>[
        const Icon(Icons.menu, color: Colors.white),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs
                  .map(
                    (String label) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: label == 'Shorts' ? AppColors.brandGold : Colors.white70,
                          fontWeight: label == 'Shorts' ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const Icon(Icons.search, color: Colors.white),
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

class _ActionRail extends StatelessWidget {
  const _ActionRail({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.person)),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: AppColors.brandGold, shape: BoxShape.circle),
              child: const Icon(Icons.add, size: 14, color: AppColors.inkDark),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ActionIcon(icon: Icons.favorite, label: item.likes),
        _ActionIcon(icon: Icons.mode_comment, label: item.comments),
        _ActionIcon(icon: Icons.bookmark, label: item.saves),
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
          Icon(icon, size: 32, color: Colors.white),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(item.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
        const SizedBox(height: 6),
        Text(item.seriesTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
        const SizedBox(height: 6),
        Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: item.tags
              .map(
                (String tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Text(
          item.isSeries ? (item.episodeLabel ?? '') : '♫ ${item.music}',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _SeriesCtaBar extends StatelessWidget {
  const _SeriesCtaBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}
