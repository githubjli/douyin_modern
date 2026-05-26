// Domain models for GET /api/live/{id}/watch-config/
//
// Successful response shape:
// {
//   "live_id": 123, "status": "live", "effective_status": "live",
//   "viewer_count": 10,
//   "playback": { "mode": "webrtc", "stream_id": "...", "websocket_url": "wss://...",
//                 "hls_url": "https://...m3u8", "connected": true },
//   "fallback":  { "mode": "hls", "hls_url": "https://...m3u8" },
//   "thumbnail_url": "...", "preview_image_url": "...", "snapshot_url": "..."
// }
// Error codes: 409 = stream failed, 503 = no playback URL available.

class LiveWatchConfig {
  const LiveWatchConfig({
    required this.liveId,
    required this.status,
    this.effectiveStatus,
    required this.viewerCount,
    required this.playback,
    required this.fallback,
    this.thumbnailUrl,
    this.previewImageUrl,
    this.snapshotUrl,
  });

  final int liveId;
  final String status;
  final String? effectiveStatus;
  final int viewerCount;
  final LivePlaybackConfig playback;
  final LiveFallbackConfig fallback;
  final String? thumbnailUrl;
  final String? previewImageUrl;
  final String? snapshotUrl;

  /// Best available cover image: thumbnail → preview → snapshot.
  String? get coverUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (previewImageUrl != null && previewImageUrl!.isNotEmpty) {
      return previewImageUrl;
    }
    if (snapshotUrl != null && snapshotUrl!.isNotEmpty) return snapshotUrl;
    return null;
  }

  factory LiveWatchConfig.fromJson(Map<String, dynamic> json) {
    return LiveWatchConfig(
      liveId: (json['live_id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      effectiveStatus: json['effective_status']?.toString(),
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      playback: LivePlaybackConfig.fromJson(
        json['playback'] is Map<String, dynamic>
            ? json['playback'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      fallback: LiveFallbackConfig.fromJson(
        json['fallback'] is Map<String, dynamic>
            ? json['fallback'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      previewImageUrl: json['preview_image_url']?.toString(),
      snapshotUrl: json['snapshot_url']?.toString(),
    );
  }
}

class LivePlaybackConfig {
  const LivePlaybackConfig({
    required this.mode,
    this.streamId,
    this.websocketUrl,
    this.hlsUrl,
    required this.connected,
  });

  final String mode;
  final String? streamId;
  final String? websocketUrl;
  final String? hlsUrl;

  /// Whether Ant Media reports the stream as actively publishing.
  final bool connected;

  bool get isWebRtc => mode == 'webrtc';

  factory LivePlaybackConfig.fromJson(Map<String, dynamic> json) {
    return LivePlaybackConfig(
      mode: json['mode']?.toString() ?? 'hls',
      streamId: json['stream_id']?.toString(),
      websocketUrl: json['websocket_url']?.toString(),
      hlsUrl: json['hls_url']?.toString(),
      connected: json['connected'] as bool? ?? false,
    );
  }
}

class LiveFallbackConfig {
  const LiveFallbackConfig({
    required this.mode,
    this.hlsUrl,
  });

  final String mode;
  final String? hlsUrl;

  factory LiveFallbackConfig.fromJson(Map<String, dynamic> json) {
    return LiveFallbackConfig(
      mode: json['mode']?.toString() ?? 'hls',
      hlsUrl: json['hls_url']?.toString(),
    );
  }
}
