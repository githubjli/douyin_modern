import 'package:flutter/material.dart';

class FeedItem {
  const FeedItem({
    required this.username,
    required this.description,
    required this.music,
    required this.likes,
    required this.comments,
    required this.shares,
    this.gifts = '0',
    required this.videoUrl,
    required this.placeholderGradient,
    this.id,
    this.title,
    this.thumbnailUrl,
    this.ownerId,
    this.ownerName,
    this.ownerAvatarUrl,
    this.category,
    this.categoryName,
    this.categorySlug,
    this.accessType,
    this.previewSeconds,
    this.canWatch,
    this.isLocked,
    this.lockReason,
    this.likeCount,
    this.commentCount,
    this.viewCount,
    this.isLiked,
    this.createdAt,
    this.seriesId,
    this.seriesTitle,
    this.episodeId,
    this.episodeNo,
    this.durationSeconds,
    this.unlockType,
    this.pointsPrice,
    this.isFavorited,
    this.favoriteCount,
    this.shareCount,
    this.viewerIsSubscribed,
    this.giftCount,
    this.giftAmountTotal,
  });

  final String username;
  final String description;
  final String music;
  final String likes;
  final String comments;
  final String shares;
  final String gifts;
  final String videoUrl;
  final List<Color> placeholderGradient;

  final String? id;
  final String? title;
  final String? thumbnailUrl;
  final String? ownerId;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? category;
  final String? categoryName;
  final String? categorySlug;
  final String? accessType;
  final int? previewSeconds;
  final bool? canWatch;
  final bool? isLocked;
  final String? lockReason;
  final int? likeCount;
  final int? commentCount;
  final int? viewCount;
  final bool? isLiked;
  final String? createdAt;

  final int? seriesId;
  final String? seriesTitle;
  final int? episodeId;
  final int? episodeNo;
  final int? durationSeconds;
  final String? unlockType;
  final int? pointsPrice;
  final bool? isFavorited;
  final int? favoriteCount;
  final int? shareCount;
  final bool? viewerIsSubscribed;
  final int? giftCount;
  final int? giftAmountTotal;
}
