import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../domain/public_creator_profile.dart';

class CreatorProfileRepository {
  const CreatorProfileRepository(this._client);
  final ApiClient _client;

  Future<PublicCreatorProfile> getProfile(int creatorId) async {
    final response = await _client.get<dynamic>(
      Endpoints.publicCreatorProfile(creatorId),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid creator profile response');
    }
    return PublicCreatorProfile.fromJson(data);
  }

  Future<List<PublicCreatorVideo>> getVideos(int creatorId) async {
    final response = await _client.get<dynamic>(
      Endpoints.publicCreatorVideos(creatorId),
    );
    return _parsePagedList(response.data, PublicCreatorVideo.fromJson);
  }

  Future<List<PublicCreatorDrama>> getDramas(int creatorId) async {
    final response = await _client.get<dynamic>(
      Endpoints.publicCreatorDramas(creatorId),
    );
    return _parsePagedList(response.data, PublicCreatorDrama.fromJson);
  }

  Future<List<PublicCreatorLive>> getLives(int creatorId) async {
    final response = await _client.get<dynamic>(
      Endpoints.publicCreatorLives(creatorId),
    );
    return _parsePagedList(response.data, PublicCreatorLive.fromJson);
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

  static List<T> _parsePagedList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    List<dynamic> items = const <dynamic>[];
    if (data is Map<String, dynamic>) {
      items = data['results'] as List<dynamic>? ?? <dynamic>[];
    } else if (data is List) {
      items = data;
    }
    return items.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }
}

final creatorProfileRepositoryProvider = Provider<CreatorProfileRepository>(
  (ref) => CreatorProfileRepository(ref.watch(apiClientProvider)),
);
