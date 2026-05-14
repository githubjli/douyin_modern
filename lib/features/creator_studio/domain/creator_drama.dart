class CreatorDrama {
  const CreatorDrama({
    required this.id,
    required this.title,
    required this.status,
    required this.totalEpisodes,
    required this.viewCount,
    required this.createdAt,
    this.coverUrl,
    this.categoryName,
    this.description,
  });

  final int id;
  final String title;
  final String status;
  final int totalEpisodes;
  final int viewCount;
  final String createdAt;
  final String? coverUrl;
  final String? categoryName;
  final String? description;

  factory CreatorDrama.fromJson(Map<String, dynamic> json) {
    return CreatorDrama(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      categoryName: json['category_name'] as String?,
      description: json['description'] as String?,
    );
  }
}
