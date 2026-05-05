import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository();

  @override
  Future<UserProfile> getCurrentProfile() async {
    return const UserProfile(
      userId: 'guest',
      displayName: 'Guest',
      bio: 'Welcome to Meow Media',
      avatarUrl: '',
    );
  }
}
