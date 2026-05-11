import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_classifier.dart';
import '../../../core/network/endpoints.dart';
import '../../home/domain/home_models.dart';

// ---------------------------------------------------------------------------
// Interaction state
// ---------------------------------------------------------------------------

class VideoInteractionState {
  const VideoInteractionState({
    this.likeCount = 0,
    this.isLiked = false,
    this.commentCount = 0,
    this.creatorId,
    this.subscriberCount,
    this.isFollowing = false,
  });

  final int likeCount;
  final bool isLiked;
  final int commentCount;
  final int? creatorId;
  final int? subscriberCount;
  final bool isFollowing;

  VideoInteractionState copyWith({
    int? likeCount,
    bool? isLiked,
    int? commentCount,
    int? creatorId,
    int? subscriberCount,
    bool? isFollowing,
  }) {
    return VideoInteractionState(
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      commentCount: commentCount ?? this.commentCount,
      creatorId: creatorId ?? this.creatorId,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

// ---------------------------------------------------------------------------
// Page state
// ---------------------------------------------------------------------------

class VideoDetailState {
  const VideoDetailState({
    required this.video,
    this.interaction = const VideoInteractionState(),
    this.loadingDetail = false,
  });

  final HomeVideoItem video;
  final VideoInteractionState interaction;
  final bool loadingDetail;

  VideoDetailState copyWith({
    HomeVideoItem? video,
    VideoInteractionState? interaction,
    bool? loadingDetail,
  }) {
    return VideoDetailState(
      video: video ?? this.video,
      interaction: interaction ?? this.interaction,
      loadingDetail: loadingDetail ?? this.loadingDetail,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class VideoDetailNotifier extends StateNotifier<VideoDetailState> {
  VideoDetailNotifier({
    required HomeVideoItem initialVideo,
    required ApiClient apiClient,
  })  : _apiClient = apiClient,
        super(VideoDetailState(video: initialVideo));

  ApiClient _apiClient;

  void setApiClient(ApiClient client) {
    _apiClient = client;
  }

  // ── Detail loading ─────────────────────────────────────────────────────────

  Future<void> loadDetail() async {
    state = state.copyWith(loadingDetail: true);
    try {
      final response = await _apiClient.get<dynamic>(
        _detailPath(state.video.id),
        authenticated: true,
      );
      final Map<String, dynamic>? data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;
      final HomeVideoItem detail = _mapDetail(response.data, state.video);
      final VideoInteractionState interaction =
          data != null ? _mapInteraction(data, state.interaction) : state.interaction;
      state = state.copyWith(
        video: detail,
        interaction: interaction,
        loadingDetail: false,
      );
    } catch (error) {
      if (isAuthDeniedError(error)) {
        state = state.copyWith(
          video: _lockedForAuthDenied(state.video),
          loadingDetail: false,
        );
        return;
      }
      if (isTransientError(error)) {
        state = state.copyWith(loadingDetail: false);
      }
    }
  }

  // ── Like ──────────────────────────────────────────────────────────────────

  Future<void> toggleLike() async {
    final int? videoId = int.tryParse(state.video.id);
    if (videoId == null) return;

    final bool wasLiked = state.interaction.isLiked;
    state = state.copyWith(
      interaction: state.interaction.copyWith(
        isLiked: !wasLiked,
        likeCount: state.interaction.likeCount + (wasLiked ? -1 : 1),
      ),
    );

    try {
      final response = await _apiClient.post<dynamic>(
        Endpoints.videoLike(videoId),
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        state = state.copyWith(
          interaction: state.interaction.copyWith(
            isLiked: _bool(data['is_liked']) ?? !wasLiked,
            likeCount: _int(data['like_count']) ?? state.interaction.likeCount,
          ),
        );
      }
    } catch (_) {
      state = state.copyWith(
        interaction: state.interaction.copyWith(
          isLiked: wasLiked,
          likeCount: state.interaction.likeCount + (wasLiked ? 1 : -1),
        ),
      );
    }
  }

  // ── Follow ────────────────────────────────────────────────────────────────

  Future<void> toggleFollow() async {
    final int? creatorId = state.interaction.creatorId;
    if (creatorId == null) return;

    final bool wasFollowing = state.interaction.isFollowing;
    state = state.copyWith(
      interaction: state.interaction.copyWith(
        isFollowing: !wasFollowing,
        subscriberCount:
            (state.interaction.subscriberCount ?? 0) + (wasFollowing ? -1 : 1),
      ),
    );

    try {
      final dynamic data;
      if (wasFollowing) {
        await _apiClient.delete<dynamic>(
          Endpoints.creatorFollow(creatorId),
          authenticated: true,
        );
        data = null;
      } else {
        final response = await _apiClient.post<dynamic>(
          Endpoints.creatorFollow(creatorId),
          authenticated: true,
        );
        data = response.data;
      }
      if (data is Map<String, dynamic>) {
        state = state.copyWith(
          interaction: state.interaction.copyWith(
            isFollowing: _bool(data['is_following']) ??
                _bool(data['viewer_is_following']) ??
                !wasFollowing,
            subscriberCount: _int(data['subscriber_count']) ??
                _int(data['follower_count']) ??
                state.interaction.subscriberCount,
          ),
        );
      }
    } catch (_) {
      state = state.copyWith(
        interaction: state.interaction.copyWith(
          isFollowing: wasFollowing,
          subscriberCount: (state.interaction.subscriberCount ?? 1) +
              (wasFollowing ? 1 : -1),
        ),
      );
    }
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  void incrementCommentCount() {
    state = state.copyWith(
      interaction: state.interaction.copyWith(
        commentCount: state.interaction.commentCount + 1,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder provider — always overridden via ProviderScope in VideoDetailPage
// ---------------------------------------------------------------------------

final videoDetailProvider = StateNotifierProvider.autoDispose<
    VideoDetailNotifier, VideoDetailState>(
  (ref) => throw UnimplementedError('videoDetailProvider must be overridden'),
);

// ---------------------------------------------------------------------------
// Helpers (package-private)
// ---------------------------------------------------------------------------

String _detailPath(String id) {
  final int? numericId = int.tryParse(id);
  if (numericId != null) return Endpoints.publicVideoDetail(numericId);
  return '${Endpoints.publicVideos}${Uri.encodeComponent(id)}/';
}

HomeVideoItem _lockedForAuthDenied(HomeVideoItem video) {
  final String? accessType = video.accessType;
  final bool isMembershipVideo =
      accessType?.trim().toLowerCase() == 'membership';
  if (!isMembershipVideo) return video;
  return HomeVideoItem(
    id: video.id,
    title: video.title,
    subtitle: video.subtitle,
    thumbnailUrl: video.thumbnailUrl,
    videoUrl: video.videoUrl,
    description: video.description,
    ownerName: video.ownerName,
    viewCount: video.viewCount,
    category: video.category,
    categoryName: video.categoryName,
    createdAt: video.createdAt,
    accessType: accessType,
    previewSeconds: video.previewSeconds,
    canWatch: false,
    isLocked: true,
    lockReason: video.lockReason ?? 'auth_required',
  );
}

HomeVideoItem _mapDetail(dynamic data, HomeVideoItem fallback) {
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Invalid video detail response');
  }
  final String title = _str(data['title']) ?? fallback.title;
  final String owner = _videoOwnerName(data) ?? fallback.ownerName ?? '';
  final int? views = _int(data['view_count']) ?? fallback.viewCount;
  return HomeVideoItem(
    id: _str(data['id']) ?? fallback.id,
    title: title,
    subtitle: owner.isEmpty
        ? fallback.subtitle
        : '$owner · ${views ?? 0} views',
    thumbnailUrl: _str(data['thumbnail_url']) ?? fallback.thumbnailUrl,
    videoUrl: _str(data['video_url']) ??
        _str(data['playback_url']) ??
        _str(data['file_url']) ??
        fallback.videoUrl,
    description: _str(data['description']) ??
        _str(data['summary']) ??
        fallback.description,
    ownerName: owner.isEmpty ? fallback.ownerName : owner,
    viewCount: views,
    category: _str(data['category']) ?? fallback.category,
    categoryName: _str(data['category_name']) ?? fallback.categoryName,
    createdAt: _str(data['created_at']) ?? fallback.createdAt,
    accessType: _str(data['access_type']) ?? fallback.accessType,
    previewSeconds: _int(data['preview_seconds']) ?? fallback.previewSeconds,
    canWatch: _bool(data['can_watch']) ?? fallback.canWatch,
    isLocked: _bool(data['is_locked']) ?? fallback.isLocked,
    lockReason: _str(data['lock_reason']) ?? fallback.lockReason,
  );
}

VideoInteractionState _mapInteraction(
  Map<String, dynamic> data,
  VideoInteractionState current,
) {
  final dynamic creator = data['creator'];
  final int? creatorId = creator is Map<String, dynamic>
      ? _int(creator['id'])
      : current.creatorId;
  final int? subscriberCount = creator is Map<String, dynamic>
      ? (_int(creator['subscriber_count']) ?? _int(data['owner_subscriber_count']))
      : _int(data['owner_subscriber_count']) ?? current.subscriberCount;
  final bool isFollowing = creator is Map<String, dynamic>
      ? (_bool(creator['is_following']) ??
          _bool(data['is_following_owner']) ??
          current.isFollowing)
      : (_bool(data['is_following_owner']) ?? current.isFollowing);

  return VideoInteractionState(
    likeCount: _int(data['like_count']) ?? current.likeCount,
    isLiked: _bool(data['is_liked']) ?? current.isLiked,
    commentCount: _int(data['comment_count']) ?? current.commentCount,
    creatorId: creatorId ?? current.creatorId,
    subscriberCount: subscriberCount,
    isFollowing: isFollowing,
  );
}

String? _videoOwnerName(Map<String, dynamic> data) {
  return _str(data['owner_name']) ??
      _nestedStr(data['owner'], 'username') ??
      _nestedStr(data['owner'], 'email') ??
      _nestedStr(data['creator'], 'name');
}

String? _nestedStr(dynamic value, String key) {
  if (value is Map<String, dynamic>) return _str(value[key]);
  return null;
}

String? _str(dynamic value) {
  if (value is String) return value;
  if (value is num) return value.toString();
  return null;
}

bool? _bool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final String normalized = value.toLowerCase().trim();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
