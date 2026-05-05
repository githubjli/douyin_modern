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
      email: null,
      isCreator: false,
      isSeller: false,
      walletAddress: null,
      walletLinked: false,
    );
  }

  @override
  Future<UserProfile> updateProfile({
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) async {
    return UserProfile(
      userId: 'guest',
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl ?? '',
      email: null,
      isCreator: false,
      isSeller: false,
      walletAddress: null,
      walletLinked: false,
    );
  }
}
