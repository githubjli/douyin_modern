import 'package:flutter/material.dart';

class FeedItem {
  const FeedItem({
    required this.username,
    required this.description,
    required this.music,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.gradient,
  });

  final String username;
  final String description;
  final String music;
  final String likes;
  final String comments;
  final String shares;
  final List<Color> gradient;
}

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  static const List<FeedItem> _items = <FeedItem>[
    FeedItem(
      username: '@citywalker',
      description: 'Night street vibes in neon lights ✨',
      music: 'Original Sound - Citywalker',
      likes: '24.1K',
      comments: '1,203',
      shares: '318',
      gradient: <Color>[Color(0xFF111111), Color(0xFF2C2C2C)],
    ),
    FeedItem(
      username: '@foodlab',
      description: 'Crispy ramen experiment #food #kitchen',
      music: 'Lo-fi Beat - Foodlab',
      likes: '11.6K',
      comments: '522',
      shares: '92',
      gradient: <Color>[Color(0xFF000000), Color(0xFF3D1A1A)],
    ),
    FeedItem(
      username: '@travelkid',
      description: 'Sunrise above the clouds ☁️',
      music: 'Ambient Rise - Travelkid',
      likes: '54.8K',
      comments: '3,883',
      shares: '1,002',
      gradient: <Color>[Color(0xFF0A0A0A), Color(0xFF1B2F45)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        final FeedItem item = _items[index];
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: item.gradient,
                ),
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
