class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    this.firstName,
    this.lastName,
    this.email,
    this.isCreator,
    this.isSeller,
    this.walletAddress,
    this.walletLinked,
  });

  final String userId;
  final String displayName;
  final String bio;
  final String avatarUrl;
  final String? firstName;
  final String? lastName;
  final String? email;
  final bool? isCreator;
  final bool? isSeller;
  final String? walletAddress;
  final bool? walletLinked;

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? firstName,
    String? lastName,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      isCreator: isCreator,
      isSeller: isSeller,
      walletAddress: walletAddress,
      walletLinked: walletLinked,
    );
  }
}
