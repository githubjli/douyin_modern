class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
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
  final String? email;
  final bool? isCreator;
  final bool? isSeller;
  final String? walletAddress;
  final bool? walletLinked;
}
