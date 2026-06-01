import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../domain/public_creator_profile.dart';

class CreatorProfileRepository {
  const CreatorProfileRepository(this._client);
  final ApiClient _client;

  /// Fetches a public creator profile with aggregated stats.
  ///
  /// Strategy: try the creator endpoint first (`/api/public/creators/{id}/`)
  /// which returns full stats (video_count, total_views, total_likes).
  /// If that returns a 404 (user is not a creator) fall back to the universal
  /// user endpoint (`/api/public/users/{id}/`).
  ///
  /// TODO(backend): once GET /api/public/users/{id}/ returns the same
  /// aggregated stat fields as the creator endpoint, remove the fallback
  /// and always use publicUserProfile so a single call suffices.
  Future<PublicCreatorProfile> getProfile(int creatorId) async {
    // Attempt creator endpoint first (has video_count / total_views / total_likes).
    try {
      final response = await _client.get<dynamic>(
        Endpoints.publicCreatorProfile(creatorId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return PublicCreatorProfile.fromJson(data);
      }
    } catch (_) {
      // 404 or any error → fall through to universal user endpoint.
    }

    // Fallback: universal endpoint (works for non-creator users).
    final response = await _client.get<dynamic>(
      Endpoints.publicUserProfile(creatorId),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid user profile response');
    }
    return PublicCreatorProfile.fromJson(data);
  }

  /// [url] is the full `next` URL from a previous page; omit for first page.
  Future<PagedResult<PublicCreatorVideo>> getVideos(
    int creatorId, {
    String? url,
  }) async {
    final response = await _client.get<dynamic>(
      url ?? Endpoints.publicCreatorVideos(creatorId),
    );
    return _parsePagedResult(response.data, PublicCreatorVideo.fromJson);
  }

  /// [url] is the full `next` URL from a previous page; omit for first page.
  Future<PagedResult<PublicCreatorDrama>> getDramas(
    int creatorId, {
    String? url,
  }) async {
    final response = await _client.get<dynamic>(
      url ?? Endpoints.publicCreatorDramas(creatorId),
    );
    return _parsePagedResult(response.data, PublicCreatorDrama.fromJson);
  }

  /// [url] is the full `next` URL from a previous page; omit for first page.
  Future<PagedResult<PublicCreatorLive>> getLives(
    int creatorId, {
    String? url,
  }) async {
    final response = await _client.get<dynamic>(
      url ?? Endpoints.publicCreatorLives(creatorId),
    );
    return _parsePagedResult(response.data, PublicCreatorLive.fromJson);
  }

  /// POST /api/creators/{id}/follow/
  Future<FollowResult> follow(int creatorId) async {
    final response = await _client.post<dynamic>(
      Endpoints.creatorFollow(creatorId),
      authenticated: true,
    );
    final data = response.data;
    return FollowResult.fromJson(
      data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
  }

  /// DELETE /api/creators/{id}/follow/
  Future<FollowResult> unfollow(int creatorId) async {
    final response = await _client.delete<dynamic>(
      Endpoints.creatorUnfollow(creatorId),
      authenticated: true,
    );
    final data = response.data;
    return FollowResult.fromJson(
      data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static PagedResult<T> _parsePagedResult<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    List<dynamic> items = const <dynamic>[];
    String? nextUrl;

    if (data is Map<String, dynamic>) {
      items = data['results'] as List<dynamic>? ?? <dynamic>[];
      final dynamic n = data['next'];
      if (n is String && n.isNotEmpty) nextUrl = n;
    } else if (data is List) {
      items = data;
    }

    return PagedResult<T>(
      items: items.whereType<Map<String, dynamic>>().map(fromJson).toList(),
      nextUrl: nextUrl,
    );
  }
}

final creatorProfileRepositoryProvider = Provider<CreatorProfileRepository>(
  (ref) => CreatorProfileRepository(ref.watch(apiClientProvider)),
);
