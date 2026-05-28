import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'membership_repository_provider.dart';

import '../../auth/application/auth_providers.dart';
import '../../home/data/remote_home_repository.dart';
import '../../home/domain/home_models.dart';
import '../data/remote_manual_membership_repository.dart';
import '../domain/manual_membership_repository.dart';
import '../domain/manual_tx_hint.dart';
import '../domain/membership_order.dart';
import '../domain/membership_plan.dart';
import '../domain/membership_repository.dart';
import '../domain/membership_status.dart';
import 'membership_controller.dart';
import 'membership_repository_provider.dart';
import 'membership_state.dart';

final membershipStatusProvider =
    FutureProvider.autoDispose<MembershipStatus?>((ref) async {
  final repo = ref.watch(membershipRepositoryProvider);
  return repo.getCurrentStatus();
});

final membershipControllerProvider =
    NotifierProvider<MembershipController, MembershipState>(
  MembershipController.new,
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

/// GET /api/membership/orders/ — all membership orders for the current user,
/// newest first. Includes platform-asset orders (meow_points, meow_credit)
/// that are NOT captured by txHintsProvider.
final membershipOrdersListProvider =
    FutureProvider.autoDispose<List<MembershipOrder>>((ref) async {
  return ref.watch(membershipRepositoryProvider).listOrders();
});

// ── MembershipPage page-scoped providers ─────────────────────────────────────

final membershipPageRepoProvider = Provider<MembershipRepository>(
  (ref) => ref.watch(membershipRepositoryProvider),
);

final membershipPageMockRepoProvider = Provider<MembershipRepository>(
  (ref) => ref.watch(membershipRepositoryProvider),
);

final membershipPageManualRepoProvider = Provider<ManualMembershipRepository>(
  (ref) => RemoteManualMembershipRepository(
    apiClient: ref.watch(apiClientProvider),
  ),
);

final membershipPageVideoRepoProvider = Provider<RemoteHomeRepository>(
  (ref) => RemoteHomeRepository(apiClient: ref.watch(apiClientProvider)),
);

final membershipPageUseRemoteProvider = Provider<bool>((ref) => true);

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
  dependencies: [
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
        pageSize: 12,
        authenticated: true,
      );
      final List<HomeVideoItem> filtered = _membershipVideos(page.items);
      if (filtered.isNotEmpty) return filtered.take(12).toList();
    } catch (_) {
      // Fall through to unfiltered fetch.
    }
    try {
      final HomeVideoPage page = await videoRepo.getVideoPage(
        pageSize: 24,
        authenticated: true,
      );
      return _membershipVideos(page.items).take(12).toList();
    } catch (_) {
      return const <HomeVideoItem>[];
    }
  },
  dependencies: [
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
  dependencies: [membershipPageManualRepoProvider],
);

/// Which plan's payment info is currently being fetched.
class _LoadingPlanCodeNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? code) => state = code;
}

final membershipLoadingPlanCodeProvider =
    NotifierProvider.autoDispose<_LoadingPlanCodeNotifier, String?>(
  _LoadingPlanCodeNotifier.new,
);

List<HomeVideoItem> _membershipVideos(List<HomeVideoItem> videos) {
  return videos.where((HomeVideoItem v) => v.isMembershipVideo).toList();
}
