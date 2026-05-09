import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/remote_membership_repository.dart';
import '../domain/membership_repository.dart';
import 'membership_controller.dart';
import 'membership_state.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return RemoteMembershipRepository(apiClient: ref.watch(apiClientProvider));
});

final membershipControllerProvider =
    StateNotifierProvider<MembershipController, MembershipState>(
  (ref) => MembershipController(
    repository: ref.watch(membershipRepositoryProvider),
  ),
);
