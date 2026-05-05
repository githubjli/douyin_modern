class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String bio;
  final String avatarUrl;
}
