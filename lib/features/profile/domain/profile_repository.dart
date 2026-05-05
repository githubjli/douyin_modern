import 'user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getCurrentProfile();

  Future<UserProfile> updateProfile({
    required String displayName,
    required String bio,
    String? avatarUrl,
  });
}
