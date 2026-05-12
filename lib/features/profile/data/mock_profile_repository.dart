import 'dart:io';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository();

  static const UserProfile _base = UserProfile(
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

  @override
  Future<UserProfile> getCurrentProfile() async => _base;

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    required String bio,
  }) async {
    final String name = <String>[
      if (firstName != null && firstName.isNotEmpty) firstName,
      if (lastName != null && lastName.isNotEmpty) lastName,
    ].join(' ').trim();
    return _base.copyWith(
      displayName: name.isNotEmpty ? name : _base.displayName,
      firstName: firstName,
      lastName: lastName,
      bio: bio,
    );
  }

  @override
  Future<UserProfile> uploadAvatar(File file) async =>
      _base.copyWith(avatarUrl: file.path);

  @override
  Future<UserProfile> clearAvatar() async => _base.copyWith(avatarUrl: '');
}
