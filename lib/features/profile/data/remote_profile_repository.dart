import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

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
    String? firstName,
    String? lastName,
    required String bio,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      Endpoints.accountProfile,
      authenticated: true,
      data: <String, dynamic>{
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        'bio': bio,
      },
    );
    return _profileFromMap(response.data ?? <String, dynamic>{});
  }

  @override
  Future<UserProfile> uploadAvatar(File file) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'avatar': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final response = await _apiClient.patch<Map<String, dynamic>>(
      Endpoints.accountProfile,
      authenticated: true,
      data: formData,
    );
    return _profileFromMap(response.data ?? <String, dynamic>{});
  }

  @override
  Future<UserProfile> clearAvatar() async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      Endpoints.accountProfile,
      authenticated: true,
      data: <String, dynamic>{'avatar_clear': true},
    );
    return _profileFromMap(response.data ?? <String, dynamic>{});
  }

  UserProfile _profileFromMap(Map<String, dynamic> data) {
    final String firstName =
        _read(data, const <String>['first_name']) ?? '';
    final String lastName =
        _read(data, const <String>['last_name']) ?? '';
    final String derivedName = <String>[
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ').trim();

    return UserProfile(
      userId: _read(data, const <String>['id', 'user_id', 'uid']) ?? 'unknown',
      displayName: _read(data, const <String>['display_name']) ??
          (derivedName.isNotEmpty ? derivedName : 'User'),
      bio: _read(data, const <String>['bio']) ?? '',
      avatarUrl: _read(data, const <String>['avatar_url', 'avatar']) ?? '',
      firstName: firstName.isNotEmpty ? firstName : null,
      lastName: lastName.isNotEmpty ? lastName : null,
      email: _read(data, const <String>['email']),
      isCreator: _readBool(data, const <String>['is_creator']),
      isSeller: _readBool(data, const <String>['is_seller']),
      walletAddress: _read(
          data, const <String>['primary_user_address', 'wallet_address']),
      walletLinked: _readBool(
          data, const <String>['wallet_linked']),
      followerCount: _readInt(
          data, const <String>['follower_count', 'subscriber_count']),
      likeCount: _readInt(
          data, const <String>['like_count', 'total_likes']),
      giftCount: _readInt(
          data, const <String>['gift_count', 'total_gifts']),
      videoCount: _readInt(
          data, const <String>['video_count', 'total_videos']),
    );
  }

  String? _read(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is num) return value.toString();
    }
    return null;
  }

  bool? _readBool(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is bool) return value;
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }
}
