import 'package:flutter/material.dart';

import 'feed_models.dart';

abstract class FeedRepository {
  Future<List<FeedItem>> getShortsFeed();
}

class MockFeedRepository implements FeedRepository {
  const MockFeedRepository();

  @override
  Future<List<FeedItem>> getShortsFeed() async {
    return const <FeedItem>[
      FeedItem(
        username: '@citywalker',
        description: 'Night street vibes in neon lights ✨',
        music: 'Original Sound - Citywalker',
        likes: '24.1K',
        comments: '1,203',
        shares: '318',
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        placeholderGradient: <Color>[Color(0xFF111111), Color(0xFF2C2C2C)],
      ),
      FeedItem(
        username: '@foodlab',
        description: 'Crispy ramen experiment #food #kitchen',
        music: 'Lo-fi Beat - Foodlab',
        likes: '11.6K',
        comments: '522',
        shares: '92',
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        placeholderGradient: <Color>[Color(0xFF000000), Color(0xFF3D1A1A)],
      ),
      FeedItem(
        username: '@travelkid',
        description: 'Sunrise above the clouds ☁️',
        music: 'Ambient Rise - Travelkid',
        likes: '54.8K',
        comments: '3,883',
        shares: '1,002',
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        placeholderGradient: <Color>[Color(0xFF0A0A0A), Color(0xFF1B2F45)],
      ),
    ];
  }
}
