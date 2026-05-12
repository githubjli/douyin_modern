import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/remote_kyc_repository.dart';
import '../domain/kyc_profile.dart';
import '../domain/kyc_repository.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return RemoteKycRepository(ref.watch(apiClientProvider));
});

final kycProfileProvider = FutureProvider<KycProfile>((ref) async {
  return ref.watch(kycRepositoryProvider).getProfile();
});
