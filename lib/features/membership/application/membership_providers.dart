import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../home/data/remote_home_repository.dart';
import '../../home/domain/home_models.dart';
import '../data/remote_manual_membership_repository.dart';
import '../data/remote_membership_repository.dart';
import '../domain/manual_membership_repository.dart';
import '../domain/manual_tx_hint.dart';
import '../domain/membership_plan.dart';
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

final manualMembershipRepositoryProvider =
    Provider<ManualMembershipRepository>((ref) {
  return RemoteManualMembershipRepository(
    apiClient: ref.watch(apiClientProvider),
  );
});

final txHintsProvider =
    FutureProvider.autoDispose<List<ManualTxHint>>((ref) async {
  return ref.watch(manualMembershipRepositoryProvider).getTxHints();
});

// ── MembershipPage page-scoped providers ─────────────────────────────────────
// Always overridden via ProviderScope inside MembershipPage.

final membershipPageRepoProvider = Provider<MembershipRepository>(
  (ref) => throw UnimplementedError('membershipPageRepoProvider must be overridden'),
);

final membershipPageMockRepoProvider = Provider<MembershipRepository>(
  (ref) => throw UnimplementedError('membershipPageMockRepoProvider must be overridden'),
);

final membershipPageManualRepoProvider = Provider<ManualMembershipRepository>(
  (ref) => throw UnimplementedError('membershipPageManualRepoProvider must be overridden'),
);

final membershipPageVideoRepoProvider = Provider<RemoteHomeRepository>(
  (ref) => throw UnimplementedError('membershipPageVideoRepoProvider must be overridden'),
);

final membershipPageUseRemoteProvider = Provider<bool>(
  (ref) => throw UnimplementedError('membershipPageUseRemoteProvider must be overridden'),
);

/// Optional pre-built future — when provided, `membershipVipVideosProvider` returns
/// it directly without hitting the network.
final membershipPageVipFutureProvider =
    Provider<Future<List<HomeVideoItem>>?>((ref) => null);

// ── MembershipPage data providers ────────────────────────────────────────────

final membershipPlansProvider =
    FutureProvider.autoDispose<List<MembershipPlan>>(
  (ref) async {
    final MembershipRepository repo = ref.watch(membershipPageRepoProvider);
    final MembershipRepository mockRepo =
        ref.watch(membershipPageMockRepoProvider);
    try {
      final List<MembershipPlan> plans = await repo.getPlans();
      if (plans.isNotEmpty) return plans;
    } catch (_) {
      // Fall through to bundled mock plans.
    }
    return mockRepo.getPlans();
  },
  dependencies: <ProviderOrFamily>[
    membershipPageRepoProvider,
    membershipPageMockRepoProvider,
  ],
);

final membershipVipVideosProvider =
    FutureProvider.autoDispose<List<HomeVideoItem>>(
  (ref) async {
    final Future<List<HomeVideoItem>>? override =
        ref.watch(membershipPageVipFutureProvider);
    if (override != null) return override;

    final bool useRemote = ref.watch(membershipPageUseRemoteProvider);
    if (!useRemote) return const <HomeVideoItem>[];

    final RemoteHomeRepository videoRepo =
        ref.watch(membershipPageVideoRepoProvider);
    try {
      final HomeVideoPage page = await videoRepo.getVideoPage(
        accessType: 'membership',
        pageSize: 4,
        authenticated: true,
      );
      final List<HomeVideoItem> filtered = _membershipVideos(page.items);
      if (filtered.isNotEmpty) return filtered.take(4).toList();
    } catch (_) {
      // Fall through to unfiltered fetch.
    }
    try {
      final HomeVideoPage page = await videoRepo.getVideoPage(
        pageSize: 12,
        authenticated: true,
      );
      return _membershipVideos(page.items).take(4).toList();
    } catch (_) {
      return const <HomeVideoItem>[];
    }
  },
  dependencies: <ProviderOrFamily>[
    membershipPageVipFutureProvider,
    membershipPageUseRemoteProvider,
    membershipPageVideoRepoProvider,
  ],
);

final membershipPendingCodesProvider =
    FutureProvider.autoDispose<Set<String>>(
  (ref) async {
    final ManualMembershipRepository manualRepo =
        ref.watch(membershipPageManualRepoProvider);
    try {
      final List<ManualTxHint> hints = await manualRepo.getTxHints();
      return hints
          .where(
            (ManualTxHint h) =>
                h.status != ManualTxHintStatus.verified &&
                h.status != ManualTxHintStatus.rejected &&
                h.status != ManualTxHintStatus.unknown,
          )
          .map((ManualTxHint h) => h.planCode)
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  },
  dependencies: <ProviderOrFamily>[membershipPageManualRepoProvider],
);

/// Which plan's payment info is currently being fetched.
final membershipLoadingPlanCodeProvider =
    StateProvider.autoDispose<String?>((ref) => null);

List<HomeVideoItem> _membershipVideos(List<HomeVideoItem> videos) {
  return videos.where((HomeVideoItem v) => v.isMembershipVideo).toList();
}
