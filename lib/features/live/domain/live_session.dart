class LiveSession {
  const LiveSession({
    required this.id,
    required this.streamId,
    required this.websocketUrl,
    required this.publishConfig,
    this.title = '',
    this.status = '',
    this.effectiveStatus = '',
    this.streamKey = '',
    this.playbackUrl = '',
    this.viewerCount = 0,
    this.canStart = false,
    this.canEnd = false,
  });

  // live.id — used for Django API: /api/live/{id}/start|end|status
  final String id;

  // publish_config.config.stream_id — used for Ant Media SDK: publish(streamId)
  final String streamId;

  // publish_config.config.websocket_url — Ant Media WebSocket endpoint
  final String websocketUrl;

  // Full Ant Media config map (websocket_url, stream_id, app_name, publish_mode)
  final Map<String, dynamic> publishConfig;

  final String title;
  final String status;           // Django model status
  final String effectiveStatus;  // Computed: idle|ready|waiting_for_signal|live|ended
  final String streamKey;
  final String playbackUrl;
  final int viewerCount;
  final bool canStart;
  final bool canEnd;

  bool get isLive => effectiveStatus == 'live';
  bool get isWaitingForSignal => effectiveStatus == 'waiting_for_signal';
  bool get isEnded => effectiveStatus == 'ended';

  // Handles two shapes:
  //   quick-start → { live: {...}, publish_config: { ok, config: {...} } }
  //   status      → { id, status, effective_status, can_start, can_end, ... }
  factory LiveSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> live =
        json['live'] is Map<String, dynamic>
            ? json['live'] as Map<String, dynamic>
            : json;

    final Map<String, dynamic> pubWrapper =
        json['publish_config'] is Map<String, dynamic>
            ? json['publish_config'] as Map<String, dynamic>
            : <String, dynamic>{};

    final Map<String, dynamic> config =
        pubWrapper['config'] is Map<String, dynamic>
            ? pubWrapper['config'] as Map<String, dynamic>
            : <String, dynamic>{};

    return LiveSession(
      id: live['id']?.toString() ?? '',
      streamId: config['stream_id']?.toString() ?? '',
      websocketUrl: config['websocket_url']?.toString() ?? '',
      publishConfig: config,
      title: live['title']?.toString() ?? '',
      status: live['status']?.toString() ?? '',
      effectiveStatus: live['effective_status']?.toString() ?? '',
      streamKey: live['stream_key']?.toString() ?? '',
      playbackUrl: live['playback_url']?.toString() ?? '',
      viewerCount: (live['viewer_count'] as num?)?.toInt() ?? 0,
      canStart: live['can_start'] == true,
      canEnd: live['can_end'] == true,
    );
  }

  LiveSession copyWith({
    String? effectiveStatus,
    String? status,
    int? viewerCount,
    bool? canStart,
    bool? canEnd,
  }) {
    return LiveSession(
      id: id,
      streamId: streamId,
      websocketUrl: websocketUrl,
      publishConfig: publishConfig,
      title: title,
      status: status ?? this.status,
      effectiveStatus: effectiveStatus ?? this.effectiveStatus,
      streamKey: streamKey,
      playbackUrl: playbackUrl,
      viewerCount: viewerCount ?? this.viewerCount,
      canStart: canStart ?? this.canStart,
      canEnd: canEnd ?? this.canEnd,
    );
  }
}
