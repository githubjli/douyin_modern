class LiveSession {
  const LiveSession({
    required this.id,
    required this.publishConfig,
    this.title = '',
    this.viewerCount = 0,
    this.isLive = false,
    this.durationSeconds = 0,
  });

  final String id;
  final Map<String, dynamic> publishConfig;
  final String title;
  final int viewerCount;
  final bool isLive;
  final int durationSeconds;

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: json['id']?.toString() ?? '',
      publishConfig: json['publish_config'] is Map<String, dynamic>
          ? json['publish_config'] as Map<String, dynamic>
          : <String, dynamic>{},
      title: json['title']?.toString() ?? '',
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      isLive: json['is_live'] == true,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  LiveSession copyWith({int? viewerCount, bool? isLive, int? durationSeconds}) {
    return LiveSession(
      id: id,
      publishConfig: publishConfig,
      title: title,
      viewerCount: viewerCount ?? this.viewerCount,
      isLive: isLive ?? this.isLive,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
