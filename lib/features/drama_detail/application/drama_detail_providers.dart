import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/application/auth_providers.dart';
import '../drama_detail_page.dart';

final dramaDetailRepositoryProvider = Provider<DramaDetailRepository>((ref) {
  return RemoteDramaDetailRepository(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Tab selection state per drama (keyed by drama ID).
class _DramaTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int index) => state = index;
}

final dramaTabIndexProvider =
    NotifierProvider.autoDispose.family<_DramaTabNotifier, int, String>(
  (_) => _DramaTabNotifier(),
);
