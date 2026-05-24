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
    this.canStart = true,
    this.canEnd = true,
    this.maxStartRetry = 20,
    this.thumbnailUrl,
    this.previewImageUrl,
    this.snapshotUrl,
    this.thumbnailCaptureStatus,
    this.thumbnailCapturedAt,
  });

  // live.id — used for Django API: /api/live/{id}/start|end|status
  final String id;

  // stream_id — used for Ant Media SDK: publish(streamId)
  // Preferred source: publish_session.stream_id → publish_config.config.stream_id
  final String streamId;

  // WebSocket endpoint for Ant Media signaling
  // Preferred source: publish_session.websocket_url → publish_config.config.websocket_url
  final String websocketUrl;

  // Full Ant Media config map (backward-compat, from publish_config.config)
  final Map<String, dynamic> publishConfig;

  final String title;
  final String status;            // Django model status
  final String effectiveStatus;   // e.g. waiting_for_publisher | publishing | live | ended | failed
  final String streamKey;
  final String playbackUrl;
  final int viewerCount;
  final bool canStart;            // Gate "Go Live" button
  final bool canEnd;              // Gate "End" button
  final int maxStartRetry;        // From publish_session.max_start_retry (default 20)

  // ── Cover / thumbnail ──────────────────────────────────────────────────────
  /// Backend ffmpeg-generated thumbnail (recommended primary).
  final String? thumbnailUrl;

  /// Ant Media real-time preview fallback.
  final String? previewImageUrl;

  /// Legacy compat alias for previewImageUrl.
  final String? snapshotUrl;

  /// pending | success | failed
  final String? thumbnailCaptureStatus;

  final String? thumbnailCapturedAt;

  /// Priority: thumbnailUrl → previewImageUrl → snapshotUrl → null.
  /// Skips empty strings.
  String? get coverUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (previewImageUrl != null && previewImageUrl!.isNotEmpty) return previewImageUrl;
    if (snapshotUrl != null && snapshotUrl!.isNotEmpty) return snapshotUrl;
    return null;
  }

  bool get isThumbnailPending => thumbnailCaptureStatus == 'pending';
  bool get isThumbnailReady   => thumbnailCaptureStatus == 'success';

  bool get isLive => effectiveStatus == 'live';
  bool get isWaitingForSignal => effectiveStatus == 'waiting_for_publisher';
  bool get isEnded => effectiveStatus == 'ended';
  bool get isFailed => effectiveStatus == 'failed';

  // Handles two response shapes:
  //   quick-start → { live: {...}, publish_session: {...}, publish_config: { ok, config: {...} } }
  //   status      → { id, status, effective_status, can_start, can_end, viewer_count, ... }
  factory LiveSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> live =
        json['live'] is Map<String, dynamic>
            ? json['live'] as Map<String, dynamic>
            : json;

    // publish_session (new) takes priority for streamId, websocketUrl, maxStartRetry
    final Map<String, dynamic> pubSession =
        json['publish_session'] is Map<String, dynamic>
            ? json['publish_session'] as Map<String, dynamic>
            : <String, dynamic>{};

    // publish_config.config (legacy) as fallback
    final Map<String, dynamic> pubWrapper =
        json['publish_config'] is Map<String, dynamic>
            ? json['publish_config'] as Map<String, dynamic>
            : <String, dynamic>{};

    final Map<String, dynamic> config =
        pubWrapper['config'] is Map<String, dynamic>
            ? pubWrapper['config'] as Map<String, dynamic>
            : <String, dynamic>{};

    final String streamId =
        pubSession['stream_id']?.toString() ??
        config['stream_id']?.toString() ?? '';

    final String websocketUrl =
        pubSession['websocket_url']?.toString() ??
        config['websocket_url']?.toString() ?? '';

    final int maxStartRetry =
        (pubSession['max_start_retry'] as num?)?.toInt() ?? 20;

    return LiveSession(
      id: live['id']?.toString() ?? '',
      streamId: streamId,
      websocketUrl: websocketUrl,
      publishConfig: config,
      title: live['title']?.toString() ?? '',
      status: live['status']?.toString() ?? '',
      effectiveStatus: live['effective_status']?.toString() ?? '',
      streamKey: live['stream_key']?.toString() ?? '',
      playbackUrl: live['playback_url']?.toString() ?? '',
      viewerCount: (live['viewer_count'] as num?)?.toInt() ?? 0,
      // Default true so the buttons work before the first status poll
      canStart: (live['can_start'] as bool?) ?? true,
      canEnd: (live['can_end'] as bool?) ?? true,
      maxStartRetry: maxStartRetry,
      // Cover / thumbnail (may come from quick-start or status poll)
      thumbnailUrl: live['thumbnail_url']?.toString(),
      previewImageUrl: live['preview_image_url']?.toString(),
      snapshotUrl: live['snapshot_url']?.toString(),
      thumbnailCaptureStatus: live['thumbnail_capture_status']?.toString(),
      thumbnailCapturedAt: live['thumbnail_captured_at']?.toString(),
    );
  }

  LiveSession copyWith({
    String? effectiveStatus,
    String? status,
    int? viewerCount,
    bool? canStart,
    bool? canEnd,
    String? thumbnailUrl,
    String? previewImageUrl,
    String? snapshotUrl,
    String? thumbnailCaptureStatus,
    String? thumbnailCapturedAt,
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
      maxStartRetry: maxStartRetry,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      previewImageUrl: previewImageUrl ?? this.previewImageUrl,
      snapshotUrl: snapshotUrl ?? this.snapshotUrl,
      thumbnailCaptureStatus:
          thumbnailCaptureStatus ?? this.thumbnailCaptureStatus,
      thumbnailCapturedAt: thumbnailCapturedAt ?? this.thumbnailCapturedAt,
    );
  }
}
