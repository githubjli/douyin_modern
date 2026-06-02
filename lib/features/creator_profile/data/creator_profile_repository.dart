import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../domain/public_creator_profile.dart';

class CreatorProfileRepository {
  const CreatorProfileRepository(this._client);
  final ApiClient _client;

  /// Fetches a public user/creator profile including aggregated stats.
  ///
  /// Dramas and shorts pass a creator/channel ID, not a user ID. The creators
  /// endpoint accepts both creator and channel IDs, so we try it first for
  /// full stats. If that 404s (plain user account), fall back to the universal
  /// users endpoint.
  Future<PublicCreatorProfile> getProfile(int creatorId) async {
    // Try the creator endpoint first — it accepts channel/creator IDs and
    // returns full aggregated stats (video_count, total_views, etc.).
    try {
      final response = await _client.get<dynamic>(
        Endpoints.publicCreatorProfile(creatorId),
        authenticated: true,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return PublicCreatorProfile.fromJson(data);
      }
    } catch (_) {
      // 404 or any error → fall through to universal user endpoint.
    }

    // Fallback: universal endpoint (works for plain user accounts).
    final response = await _client.get<dynamic>(
      Endpoints.publicUserProfile(creatorId),
      authenticated: true,
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

  // Follow / unfollow live in FollowRepository — see features/follow/.

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
