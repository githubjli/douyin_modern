import 'dart:io';

import 'user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getCurrentProfile();

  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    required String bio,
  });

  Future<UserProfile> uploadAvatar(File file);

  Future<UserProfile> clearAvatar();
}
