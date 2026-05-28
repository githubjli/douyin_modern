import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_dependency_providers.dart';
import '../data/remote_membership_repository.dart';
import '../domain/membership_repository.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return RemoteMembershipRepository(apiClient: ref.watch(apiClientProvider));
});
