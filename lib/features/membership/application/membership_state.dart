import '../domain/membership_status.dart';

enum MembershipLoadStatus {
  unknown,
  loading,
  active,
  inactive,
  error,
}

class MembershipState {
  const MembershipState._({
    required this.status,
    this.membership,
    this.message,
  });

  const MembershipState.unknown()
      : this._(status: MembershipLoadStatus.unknown);

  const MembershipState.loading({MembershipStatus? previous})
      : this._(
          status: MembershipLoadStatus.loading,
          membership: previous,
        );

  const MembershipState.active(MembershipStatus membership)
      : this._(
          status: MembershipLoadStatus.active,
          membership: membership,
        );

  const MembershipState.inactive()
      : this._(status: MembershipLoadStatus.inactive);

  const MembershipState.error(String message, {MembershipStatus? previous})
      : this._(
          status: MembershipLoadStatus.error,
          membership: previous,
          message: message,
        );

  final MembershipLoadStatus status;
  final MembershipStatus? membership;
  final String? message;

  bool get isActive => membership?.isActive == true;

  bool get isInactive => status == MembershipLoadStatus.inactive;

  bool get isLoading => status == MembershipLoadStatus.loading;

  bool get hasKnownMembership => membership != null;

  bool get hasActiveMembership => membership?.isActive == true;
}
