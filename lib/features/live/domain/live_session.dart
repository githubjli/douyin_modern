class LiveSession {
  const LiveSession({
    required this.id,
    required this.publishConfig,
    this.title = '',
    this.status = '',
    this.streamKey = '',
    this.playbackUrl = '',
    this.viewerCount = 0,
    this.isLive = false,
    this.durationSeconds = 0,
  });

  final String id;
  final Map<String, dynamic> publishConfig; // inner config from publish_config.config
  final String title;
  final String status;
  final String streamKey;
  final String playbackUrl;
  final int viewerCount;
  final bool isLive;
  final int durationSeconds;

  // Parses both quick-start responses (nested live + publish_config)
  // and status responses (flat, with is_live / viewer_count).
  factory LiveSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> live =
        json['live'] is Map<String, dynamic>
            ? json['live'] as Map<String, dynamic>
            : json; // status endpoint returns flat structure

    final Map<String, dynamic> publishConfigWrapper =
        json['publish_config'] is Map<String, dynamic>
            ? json['publish_config'] as Map<String, dynamic>
            : <String, dynamic>{};

    final Map<String, dynamic> config =
        publishConfigWrapper['config'] is Map<String, dynamic>
            ? publishConfigWrapper['config'] as Map<String, dynamic>
            : <String, dynamic>{};

    final String id = live['id']?.toString() ?? '';

    return LiveSession(
      id: id,
      publishConfig: config,
      title: live['title']?.toString() ?? '',
      status: live['status']?.toString() ?? '',
      streamKey: live['stream_key']?.toString() ?? '',
      playbackUrl: live['playback_url']?.toString() ?? '',
      viewerCount: (live['viewer_count'] as num?)?.toInt() ?? 0,
      isLive: live['status'] == 'live' || live['is_live'] == true,
      durationSeconds: (live['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  LiveSession copyWith({int? viewerCount, bool? isLive, int? durationSeconds}) {
    return LiveSession(
      id: id,
      publishConfig: publishConfig,
      title: title,
      status: status,
      streamKey: streamKey,
      playbackUrl: playbackUrl,
      viewerCount: viewerCount ?? this.viewerCount,
      isLive: isLive ?? this.isLive,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
