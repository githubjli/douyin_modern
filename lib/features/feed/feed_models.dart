import 'package:flutter/material.dart';

class FeedItem {
  const FeedItem({
    required this.username,
    required this.description,
    required this.music,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.videoUrl,
    required this.placeholderGradient,
  });

  final String username;
  final String description;
  final String music;
  final String likes;
  final String comments;
  final String shares;
  final String videoUrl;
  final List<Color> placeholderGradient;
}
