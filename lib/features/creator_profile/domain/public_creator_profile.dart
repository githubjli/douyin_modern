/// Wrapper for a paginated API response page.
class PagedResult<T> {
  const PagedResult({required this.items, this.nextUrl});

  final List<T> items;

  /// Full URL for the next page, or `null` when this is the last page.
  final String? nextUrl;

  bool get hasMore => nextUrl != null;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Public user/creator profile returned by:
///   GET /api/public/users/{id}/     — all users
///   GET /api/public/creators/{id}/  — creators only (legacy)
class PublicCreatorProfile {
  const PublicCreatorProfile({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.bio,
    this.isCreator = false,
    this.subscriberCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.videoCount = 0,
    this.dramaCount = 0,
    this.liveCount = 0,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalGifts = 0,
    this.viewerIsFollowing = false,
  });

  final int id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final bool isCreator;
  final int subscriberCount;
  final int followerCount;
  final int followingCount;
  /// Public video count (published, non-private).
  final int videoCount;
  /// Published drama count.
  final int dramaCount;
  /// Non-private live session count.
  final int liveCount;
  /// Total views across videos + dramas + lives.
  final int totalViews;
  /// Total likes across videos + dramas + lives.
  final int totalLikes;
  /// Total gift value received (sum of gift amounts, not transaction count).
  final int totalGifts;
  final bool viewerIsFollowing;

  factory PublicCreatorProfile.fromJson(Map<String, dynamic> json) {
    // Display name: display_name > nickname > username
    final String displayName = json['display_name']?.toString().trim().isNotEmpty == true
        ? json['display_name'] as String
        : json['nickname']?.toString().trim().isNotEmpty == true
            ? json['nickname'] as String
            : json['username']?.toString() ?? '';

    // Avatar: avatar_url > avatar
    final String? avatarUrl = (json['avatar_url'] as String?)?.trim().isNotEmpty == true
        ? json['avatar_url'] as String
        : (json['avatar'] as String?)?.trim().isNotEmpty == true
            ? json['avatar'] as String
            : null;

    // Bio: bio > description
    final String? bio = (json['bio'] as String?)?.trim().isNotEmpty == true
        ? json['bio'] as String
        : (json['description'] as String?)?.trim().isNotEmpty == true
            ? json['description'] as String
            : null;

    // Follower count: follower_count > followers_count
    final int followerCount =
        (json['follower_count'] as num?)?.toInt() ??
        (json['followers_count'] as num?)?.toInt() ?? 0;

    return PublicCreatorProfile(
      id: (json['id'] as num).toInt(),
      displayName: displayName,
      username: json['username']?.toString(),
      avatarUrl: avatarUrl,
      bio: bio,
      isCreator: json['is_creator'] as bool? ?? false,
      subscriberCount: (json['subscriber_count'] as num?)?.toInt() ?? 0,
      followerCount: followerCount,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      videoCount: (json['video_count'] as num?)?.toInt() ?? 0,
      dramaCount: (json['drama_count'] as num?)?.toInt() ?? 0,
      liveCount:  (json['live_count']  as num?)?.toInt() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ??
          (json['view_count'] as num?)?.toInt() ?? 0,
      totalLikes: (json['total_likes'] as num?)?.toInt() ??
          (json['like_count'] as num?)?.toInt() ?? 0,
      totalGifts: (json['total_gifts'] as num?)?.toInt() ?? 0,
      viewerIsFollowing: json['viewer_is_following'] as bool? ?? false,
    );
  }

  PublicCreatorProfile copyWith({bool? viewerIsFollowing, int? followerCount}) {
    return PublicCreatorProfile(
      id: id,
      displayName: displayName,
      username: username,
      avatarUrl: avatarUrl,
      bio: bio,
      isCreator: isCreator,
      subscriberCount: subscriberCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount,
      videoCount: videoCount,
      dramaCount: dramaCount,
      liveCount: liveCount,
      totalViews: totalViews,
      totalLikes: totalLikes,
      totalGifts: totalGifts,
      viewerIsFollowing: viewerIsFollowing ?? this.viewerIsFollowing,
    );
  }
}

/// Public video in creator's profile (GET /api/public/creators/{id}/videos/)
class PublicCreatorVideo {
  const PublicCreatorVideo({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.accessType = 'free',
    this.isLocked = false,
    this.viewCount = 0,
    this.likeCount = 0,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? thumbnailUrl;
  final String accessType;
  final bool isLocked;
  final int viewCount;
  final int likeCount;
  final String? createdAt;

  bool get isPremium => accessType != 'free';

  factory PublicCreatorVideo.fromJson(Map<String, dynamic> json) {
    return PublicCreatorVideo(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      accessType: json['access_type'] as String? ?? 'free',
      isLocked: json['is_locked'] as bool? ?? false,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Public drama in creator's profile (GET /api/public/creators/{id}/dramas/)
class PublicCreatorDrama {
  const PublicCreatorDrama({
    required this.id,
    required this.title,
    this.coverUrl,
    this.episodeCount = 0,
    this.accessType = 'free',
    this.status,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? coverUrl;
  final int episodeCount;
  final String accessType;
  final String? status;
  final String? createdAt;

  bool get isPremium => accessType != 'free';

  factory PublicCreatorDrama.fromJson(Map<String, dynamic> json) {
    return PublicCreatorDrama(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      accessType: json['access_type'] as String? ?? 'free',
      status: json['status'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Live session in creator's history (GET /api/public/creators/{id}/lives/)
class PublicCreatorLive {
  const PublicCreatorLive({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.previewImageUrl,
    this.snapshotUrl,
    this.effectiveStatus = '',
    this.viewerCount = 0,
    this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? thumbnailUrl;
  final String? previewImageUrl;
  final String? snapshotUrl;
  final String effectiveStatus;
  final int viewerCount;
  final String? startedAt;
  final String? endedAt;
  final String? createdAt;

  bool get isLive => effectiveStatus == 'live';

  /// Priority: thumbnailUrl → previewImageUrl → snapshotUrl → null.
  String? get coverUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (previewImageUrl != null && previewImageUrl!.isNotEmpty) return previewImageUrl;
    if (snapshotUrl != null && snapshotUrl!.isNotEmpty) return snapshotUrl;
    return null;
  }

  factory PublicCreatorLive.fromJson(Map<String, dynamic> json) {
    return PublicCreatorLive(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      previewImageUrl: json['preview_image_url'] as String?,
      snapshotUrl: json['snapshot_url'] as String?,
      effectiveStatus: json['effective_status'] as String? ?? '',
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Result returned after follow / unfollow.
class FollowResult {
  const FollowResult({required this.isFollowing, required this.followerCount});

  final bool isFollowing;
  final int followerCount;

  factory FollowResult.fromJson(Map<String, dynamic> json) {
    return FollowResult(
      isFollowing: json['viewer_is_following'] as bool? ?? false,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
    );
  }
}
