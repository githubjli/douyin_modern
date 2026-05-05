import 'user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getCurrentProfile();
}
