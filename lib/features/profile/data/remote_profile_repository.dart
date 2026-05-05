import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserProfile> getCurrentProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      Endpoints.accountProfile,
      authenticated: true,
    );
    return _profileFromMap(response.data ?? <String, dynamic>{});
  }

  @override
  Future<UserProfile> updateProfile({
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      Endpoints.accountProfile,
      authenticated: true,
      data: <String, dynamic>{
        'display_name': displayName,
        'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      },
    );
    return _profileFromMap(response.data ?? <String, dynamic>{});
  }

  UserProfile _profileFromMap(Map<String, dynamic> data) {
    return UserProfile(
      userId: _read(data, const <String>['user_id', 'id', 'uid']) ?? 'unknown',
      displayName: _read(data, const <String>['display_name', 'username', 'name']) ?? 'User',
      bio: _read(data, const <String>['bio', 'description']) ?? '',
      avatarUrl: _read(data, const <String>['avatar_url', 'avatar', 'avatarUrl']) ?? '',
    );
  }

  String? _read(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is String) return value;
      if (value is num) return value.toString();
    }
    return null;
  }
}
