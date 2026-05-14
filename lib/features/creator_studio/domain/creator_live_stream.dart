class CreatorLiveStream {
  const CreatorLiveStream({
    required this.id,
    required this.title,
    required this.status,
    required this.viewerCount,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.thumbnailUrl,
    this.categoryName,
  });

  final int id;
  final String title;
  final String status;
  final int viewerCount;
  final String createdAt;
  final String? startedAt;
  final String? endedAt;
  final String? thumbnailUrl;
  final String? categoryName;

  factory CreatorLiveStream.fromJson(Map<String, dynamic> json) {
    return CreatorLiveStream(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      status: json['effective_status'] as String? ??
          json['status'] as String? ??
          'idle',
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      categoryName: json['category_name'] as String?,
    );
  }
}
