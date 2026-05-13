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
    this.followerCount,
    this.likeCount,
    this.giftCount,
    this.videoCount,
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
  final int? followerCount;
  final int? likeCount;
  final int? giftCount;
  final int? videoCount;

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
      followerCount: followerCount,
      likeCount: likeCount,
      giftCount: giftCount,
      videoCount: videoCount,
    );
  }
}
