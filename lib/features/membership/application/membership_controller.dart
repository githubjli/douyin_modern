import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/api_error_classifier.dart';
import '../../auth/application/auth_state.dart';
import '../domain/membership_repository.dart';
import '../domain/membership_status.dart';
import 'membership_state.dart';

class MembershipController extends StateNotifier<MembershipState> {
  MembershipController({required MembershipRepository repository})
      : _repository = repository,
        super(const MembershipState.unknown());

  final MembershipRepository _repository;

  Future<void> refresh() async {
    final MembershipStatus? previous = _activeMembership;
    state = MembershipState.loading(previous: previous);
    try {
      final MembershipStatus? status = await _repository.getCurrentStatus();
      if (status?.isActive == true) {
        state = MembershipState.active(status!);
      } else {
        state = const MembershipState.inactive();
      }
    } catch (error) {
      if (isAuthDeniedError(error)) {
        state = const MembershipState.inactive();
        return;
      }
      if (isTransientError(error)) {
        state = MembershipState.error(_messageFor(error), previous: previous);
        return;
      }
      state = MembershipState.error(_messageFor(error), previous: previous);
    }
  }

  void reset() {
    state = const MembershipState.unknown();
  }

  Future<void> maybeRefreshForAuth(AuthState authState) async {
    if (authState.status == AuthStatus.signedOut) {
      state = const MembershipState.inactive();
      return;
    }
    if (authState.isSignedIn) {
      await refresh();
    }
  }

  MembershipStatus? get _activeMembership {
    final MembershipStatus? membership = state.membership;
    return membership?.isActive == true ? membership : null;
  }

  String _messageFor(Object error) {
    if (error is ApiError) return error.message;
    return error.toString();
  }
}
