class MembershipStatus {
  const MembershipStatus({
    required this.planTitle,
    required this.status,
    required this.isActive,
    this.startsAt,
    this.endsAt,
  });

  final String planTitle;
  final String status;
  final bool isActive;
  final String? startsAt;
  final String? endsAt;
}
