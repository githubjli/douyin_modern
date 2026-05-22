class CreatorVideo {
  const CreatorVideo({
    required this.id,
    required this.title,
    required this.visibility,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.giftCount,
    required this.shareCount,
    required this.createdAt,
    this.thumbnailUrl,
    this.categoryName,
    this.accessType,
  });

  final int id;
  final String title;
  final String visibility;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int giftCount;
  final int shareCount;
  final String createdAt;
  final String? thumbnailUrl;
  final String? categoryName;
  final String? accessType;

  factory CreatorVideo.fromJson(Map<String, dynamic> json) {
    return CreatorVideo(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      giftCount: (json['gift_count'] as num?)?.toInt() ?? 0,
      shareCount: (json['share_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      categoryName: json['category_name'] as String?,
      accessType: json['access_type'] as String?,
    );
  }
}
