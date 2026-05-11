import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/application/auth_providers.dart';
import '../drama_detail_page.dart';

final dramaDetailRepositoryProvider = Provider<DramaDetailRepository>((ref) {
  return RemoteDramaDetailRepository(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Tab selection state per drama (keyed by drama ID).
final dramaTabIndexProvider =
    StateProvider.autoDispose.family<int, String>((ref, dramaId) => 0);
