import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/features/membership/application/membership_providers.dart';
import 'package:meow_media/features/membership/application/membership_state.dart';
import 'package:meow_media/features/membership/domain/membership_order.dart';
import 'package:meow_media/features/membership/domain/membership_plan.dart';
import 'package:meow_media/features/membership/domain/membership_repository.dart';
import 'package:meow_media/features/membership/domain/membership_status.dart';

void main() {
  const MembershipStatus activeStatus = MembershipStatus(
    planTitle: 'Meow Plus',
    status: 'active',
    isActive: true,
    startsAt: '2026-01-01T00:00:00Z',
    endsAt: '2026-06-01T00:00:00Z',
  );

  const MembershipStatus inactiveStatus = MembershipStatus(
    planTitle: 'Meow Plus',
    status: 'inactive',
    isActive: false,
  );

  ProviderContainer createContainer(_FakeMembershipRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        membershipRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('refresh active stores active membership', () async {
    final _FakeMembershipRepository repository = _FakeMembershipRepository(
      status: activeStatus,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(membershipControllerProvider.notifier).refresh();

    final MembershipState state = container.read(membershipControllerProvider);
    expect(state.status, MembershipLoadStatus.active);
    expect(state.isActive, isTrue);
    expect(state.membership?.planTitle, 'Meow Plus');
  });

  test('refresh null status becomes inactive', () async {
    final _FakeMembershipRepository repository = _FakeMembershipRepository();
    final ProviderContainer container = createContainer(repository);

    await container.read(membershipControllerProvider.notifier).refresh();

    final MembershipState state = container.read(membershipControllerProvider);
    expect(state.status, MembershipLoadStatus.inactive);
    expect(state.isInactive, isTrue);
    expect(state.membership, isNull);
  });

  test('refresh inactive status becomes inactive', () async {
    final _FakeMembershipRepository repository = _FakeMembershipRepository(
      status: inactiveStatus,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(membershipControllerProvider.notifier).refresh();

    final MembershipState state = container.read(membershipControllerProvider);
    expect(state.status, MembershipLoadStatus.inactive);
    expect(state.isInactive, isTrue);
    expect(state.membership, isNull);
  });

  test('refresh transient error without previous becomes error', () async {
    final _FakeMembershipRepository repository = _FakeMembershipRepository(
      statusError: Exception('offline'),
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(membershipControllerProvider.notifier).refresh();

    final MembershipState state = container.read(membershipControllerProvider);
    expect(state.status, MembershipLoadStatus.error);
    expect(state.hasActiveMembership, isFalse);
    expect(state.message, contains('offline'));
  });

  test('refresh transient error preserves previous active membership', () async {
    final _FakeMembershipRepository repository = _FakeMembershipRepository(
      status: activeStatus,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(membershipControllerProvider.notifier).refresh();
    repository
      ..status = null
      ..statusError = const ApiError(
        message: 'Server unavailable',
        statusCode: 500,
      );
    await container.read(membershipControllerProvider.notifier).refresh();

    final MembershipState state = container.read(membershipControllerProvider);
    expect(state.status, MembershipLoadStatus.error);
    expect(state.membership, activeStatus);
    expect(state.hasActiveMembership, isTrue);
    expect(state.isInactive, isFalse);
    expect(state.message, 'Server unavailable');
  });

  for (final int statusCode in <int>[401, 403]) {
    test('refresh auth denied $statusCode becomes inactive', () async {
      final _FakeMembershipRepository repository = _FakeMembershipRepository(
        statusError: ApiError(
          message: 'Auth denied',
          statusCode: statusCode,
        ),
      );
      final ProviderContainer container = createContainer(repository);

      await container.read(membershipControllerProvider.notifier).refresh();

      final MembershipState state = container.read(membershipControllerProvider);
      expect(state.status, MembershipLoadStatus.inactive);
      expect(state.isInactive, isTrue);
      expect(repository.logoutCalled, isFalse);
    });
  }

  test('reset returns state to unknown', () async {
    final _FakeMembershipRepository repository = _FakeMembershipRepository(
      status: activeStatus,
    );
    final ProviderContainer container = createContainer(repository);

    await container.read(membershipControllerProvider.notifier).refresh();
    container.read(membershipControllerProvider.notifier).reset();

    final MembershipState state = container.read(membershipControllerProvider);
    expect(state.status, MembershipLoadStatus.unknown);
    expect(state.membership, isNull);
  });
}

class _FakeMembershipRepository implements MembershipRepository {
  _FakeMembershipRepository({
    this.status,
    this.statusError,
  });

  MembershipStatus? status;
  Object? statusError;
  bool logoutCalled = false;

  @override
  Future<MembershipStatus?> getCurrentStatus() async {
    final Object? error = statusError;
    if (error != null) throw error;
    return status;
  }

  @override
  Future<List<MembershipPlan>> getPlans() async {
    return const <MembershipPlan>[];
  }

  @override
  Future<MembershipOrder> createOrder({required String planCode}) {
    throw UnimplementedError();
  }

  @override
  Future<MembershipOrder> getOrder(String orderNo) {
    throw UnimplementedError();
  }

  @override
  Future<MembershipOrder> submitTxHint({
    required String orderNo,
    required String txid,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MembershipOrder> verifyNow(String orderNo) {
    throw UnimplementedError();
  }
}
