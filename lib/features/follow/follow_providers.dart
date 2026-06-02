import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/endpoints.dart';
import '../auth/application/auth_providers.dart';

/// Shared follow state for a given user. One [FollowNotifier] exists per
/// userId via [followStateProvider], so all pages (video detail, creator
/// profile, drama player, feed shorts) see the same value and react to
/// changes from any other page.
class FollowState {
  const FollowState({
    required this.isFollowing,
    required this.followerCount,
    this.isUpdating = false,
    this.isSelfDisallowed = false,
  });

  final bool isFollowing;
  final int followerCount;
  final bool isUpdating;

  /// Set when the backend returns 400 (you can't follow yourself).
  /// UI should hide the Follow button permanently once true.
  final bool isSelfDisallowed;

  static const FollowState unknown = FollowState(
    isFollowing: false,
    followerCount: 0,
  );

  FollowState copyWith({
    bool? isFollowing,
    int? followerCount,
    bool? isUpdating,
    bool? isSelfDisallowed,
  }) {
    return FollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      followerCount: followerCount ?? this.followerCount,
      isUpdating: isUpdating ?? this.isUpdating,
      isSelfDisallowed: isSelfDisallowed ?? this.isSelfDisallowed,
    );
  }
}

/// Thin wrapper over the canonical follow endpoint. All call sites should
/// go through this — do NOT call /api/creators/{id}/follow/ or
/// /api/channels/{id}/subscribe/ directly from feature code.
class FollowRepository {
  const FollowRepository(this._client);
  final ApiClient _client;

  /// POST /api/public/users/{id}/follow/
  Future<FollowState> follow(int userId) async {
    final response = await _client.post<dynamic>(
      Endpoints.userFollow(userId),
      authenticated: true,
    );
    return parseFollowState(
      response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{},
      fallbackIsFollowing: true,
    );
  }

  /// DELETE /api/public/users/{id}/follow/
  Future<FollowState> unfollow(int userId) async {
    final response = await _client.delete<dynamic>(
      Endpoints.userFollow(userId),
      authenticated: true,
    );
    return parseFollowState(
      response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{},
      fallbackIsFollowing: false,
    );
  }

  /// Parses follow-state-bearing JSON using the backend P1 priority.
  ///
  ///   isFollowing:   is_following_owner > viewer_is_following >
  ///                  is_subscribed > viewer_is_subscribed
  ///                  > nested.is_following
  ///   followerCount: owner_follower_count > follower_count >
  ///                  subscriber_count > owner_subscriber_count
  ///                  > nested.follower_count > nested.subscriber_count
  ///
  /// [nested] is an optional sub-object (e.g. the `creator` map in a video
  /// detail response) consulted last for both fields.
  ///
  /// [fallbackIsFollowing] is returned when the JSON has none of the keys
  /// (e.g. some endpoints return 204 / empty body on success).
  static FollowState parseFollowState(
    Map<String, dynamic> json, {
    required bool fallbackIsFollowing,
    int fallbackFollowerCount = 0,
    Map<String, dynamic>? nested,
  }) {
    final bool isFollowing = (json['is_following_owner'] as bool?) ??
        (json['viewer_is_following'] as bool?) ??
        (json['is_subscribed'] as bool?) ??
        (json['viewer_is_subscribed'] as bool?) ??
        (nested?['is_following'] as bool?) ??
        fallbackIsFollowing;
    final int followerCount = (json['owner_follower_count'] as num?)?.toInt() ??
        (json['follower_count'] as num?)?.toInt() ??
        (json['subscriber_count'] as num?)?.toInt() ??
        (json['owner_subscriber_count'] as num?)?.toInt() ??
        (nested?['follower_count'] as num?)?.toInt() ??
        (nested?['subscriber_count'] as num?)?.toInt() ??
        fallbackFollowerCount;
    return FollowState(
      isFollowing: isFollowing,
      followerCount: followerCount,
    );
  }
}

class FollowNotifier extends Notifier<FollowState> {
  FollowNotifier(this.userId);

  final int userId;

  @override
  FollowState build() => FollowState.unknown;

  /// Set the known state from a fresh API response. Overwrites previous
  /// values (the server is the source of truth). Preserves [isSelfDisallowed]
  /// so a 400 once observed stays sticky for the session.
  void hydrate({required bool isFollowing, required int followerCount}) {
    state = state.copyWith(
      isFollowing: isFollowing,
      followerCount: followerCount,
      isUpdating: false,
    );
  }

  Future<void> toggle() async {
    if (state.isUpdating || state.isSelfDisallowed) return;
    final bool wasFollowing = state.isFollowing;
    final int prevCount = state.followerCount;

    // Optimistic update.
    state = state.copyWith(
      isFollowing: !wasFollowing,
      followerCount:
          (prevCount + (wasFollowing ? -1 : 1)).clamp(0, 1 << 31).toInt(),
      isUpdating: true,
    );

    final FollowRepository repo = ref.read(followRepositoryProvider);
    try {
      final FollowState result =
          wasFollowing ? await repo.unfollow(userId) : await repo.follow(userId);
      state = FollowState(
        isFollowing: result.isFollowing,
        // Server may return 0 if it omits the count — keep the optimistic
        // value as a fallback instead of jumping to zero.
        followerCount: result.followerCount > 0
            ? result.followerCount
            : state.followerCount,
      );
    } on ApiError catch (e) {
      // 400 = "you can't follow yourself" — mark sticky, revert optimistic
      // update so the UI can hide the button.
      if (e.statusCode == 400) {
        state = FollowState(
          isFollowing: wasFollowing,
          followerCount: prevCount,
          isSelfDisallowed: true,
        );
        return;
      }
      // Other errors → revert.
      state = FollowState(
        isFollowing: wasFollowing,
        followerCount: prevCount,
      );
      rethrow;
    } catch (_) {
      state = FollowState(
        isFollowing: wasFollowing,
        followerCount: prevCount,
      );
    }
  }
}

final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => FollowRepository(ref.watch(apiClientProvider)),
);

/// Shared follow state keyed by userId. Watch from anywhere to react to
/// follow changes made on another page.
final followStateProvider =
    NotifierProvider.family<FollowNotifier, FollowState, int>(
  FollowNotifier.new,
);
