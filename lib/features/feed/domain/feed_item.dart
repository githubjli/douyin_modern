import 'dart:ui';

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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'username': username,
        'description': description,
        'music': music,
        'likes': likes,
        'comments': comments,
        'shares': shares,
        'gifts': gifts,
        'videoUrl': videoUrl,
        'placeholderGradient':
            placeholderGradient.map((Color c) => c.toARGB32()).toList(),
        if (id != null) 'id': id,
        if (title != null) 'title': title,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (ownerId != null) 'ownerId': ownerId,
        if (ownerName != null) 'ownerName': ownerName,
        if (ownerAvatarUrl != null) 'ownerAvatarUrl': ownerAvatarUrl,
        if (category != null) 'category': category,
        if (categoryName != null) 'categoryName': categoryName,
        if (categorySlug != null) 'categorySlug': categorySlug,
        if (accessType != null) 'accessType': accessType,
        if (previewSeconds != null) 'previewSeconds': previewSeconds,
        if (canWatch != null) 'canWatch': canWatch,
        if (isLocked != null) 'isLocked': isLocked,
        if (lockReason != null) 'lockReason': lockReason,
        if (likeCount != null) 'likeCount': likeCount,
        if (commentCount != null) 'commentCount': commentCount,
        if (viewCount != null) 'viewCount': viewCount,
        if (isLiked != null) 'isLiked': isLiked,
        if (createdAt != null) 'createdAt': createdAt,
        if (seriesId != null) 'seriesId': seriesId,
        if (seriesTitle != null) 'seriesTitle': seriesTitle,
        if (episodeId != null) 'episodeId': episodeId,
        if (episodeNo != null) 'episodeNo': episodeNo,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (unlockType != null) 'unlockType': unlockType,
        if (pointsPrice != null) 'pointsPrice': pointsPrice,
        if (isFavorited != null) 'isFavorited': isFavorited,
        if (favoriteCount != null) 'favoriteCount': favoriteCount,
        if (shareCount != null) 'shareCount': shareCount,
        if (viewerIsSubscribed != null) 'viewerIsSubscribed': viewerIsSubscribed,
        if (giftCount != null) 'giftCount': giftCount,
        if (giftAmountTotal != null) 'giftAmountTotal': giftAmountTotal,
      };

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final List<int> colorValues = (json['placeholderGradient'] as List<dynamic>)
        .map((dynamic v) => v as int)
        .toList();
    return FeedItem(
      username: json['username'] as String,
      description: json['description'] as String,
      music: json['music'] as String,
      likes: json['likes'] as String,
      comments: json['comments'] as String,
      shares: json['shares'] as String,
      gifts: (json['gifts'] as String?) ?? '0',
      videoUrl: json['videoUrl'] as String,
      placeholderGradient: colorValues.map((int v) => Color(v)).toList(),
      id: json['id'] as String?,
      title: json['title'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      ownerId: json['ownerId'] as String?,
      ownerName: json['ownerName'] as String?,
      ownerAvatarUrl: json['ownerAvatarUrl'] as String?,
      category: json['category'] as String?,
      categoryName: json['categoryName'] as String?,
      categorySlug: json['categorySlug'] as String?,
      accessType: json['accessType'] as String?,
      previewSeconds: json['previewSeconds'] as int?,
      canWatch: json['canWatch'] as bool?,
      isLocked: json['isLocked'] as bool?,
      lockReason: json['lockReason'] as String?,
      likeCount: json['likeCount'] as int?,
      commentCount: json['commentCount'] as int?,
      viewCount: json['viewCount'] as int?,
      isLiked: json['isLiked'] as bool?,
      createdAt: json['createdAt'] as String?,
      seriesId: json['seriesId'] as int?,
      seriesTitle: json['seriesTitle'] as String?,
      episodeId: json['episodeId'] as int?,
      episodeNo: json['episodeNo'] as int?,
      durationSeconds: json['durationSeconds'] as int?,
      unlockType: json['unlockType'] as String?,
      pointsPrice: json['pointsPrice'] as int?,
      isFavorited: json['isFavorited'] as bool?,
      favoriteCount: json['favoriteCount'] as int?,
      shareCount: json['shareCount'] as int?,
      viewerIsSubscribed: json['viewerIsSubscribed'] as bool?,
      giftCount: json['giftCount'] as int?,
      giftAmountTotal: json['giftAmountTotal'] as int?,
    );
  }
}
