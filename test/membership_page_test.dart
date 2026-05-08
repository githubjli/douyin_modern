import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/membership/domain/membership_plan.dart';
import 'package:meow_media/features/membership/domain/membership_repository.dart';
import 'package:meow_media/features/membership/domain/membership_status.dart';
import 'package:meow_media/features/membership/membership_page.dart';

void main() {
  const List<MembershipPlan> backendPlans = <MembershipPlan>[
    MembershipPlan(
      id: 'backend-pro',
      title: 'Backend Pro',
      price: 'USD 9.99 / month',
      perks: 'Backend perks',
    ),
  ];

  const List<MembershipPlan> mockPlans = <MembershipPlan>[
    MembershipPlan(
      id: 'mock-monthly',
      title: 'Mock Monthly',
      price: '¥5 / month',
      perks: 'Mock perks',
    ),
  ];

  const MembershipStatus activeStatus = MembershipStatus(
    planTitle: 'Basic Monthly',
    status: 'active',
    endsAt: '2026-06-01T00:00:00Z',
    isActive: true,
  );

  Future<void> pumpMembershipPage(
    WidgetTester tester, {
    required MembershipRepository repository,
    MembershipRepository mockRepository = const _MembershipRepositoryFake(
      plans: mockPlans,
    ),
    bool useRemote = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipPage(
            repository: repository,
            mockRepository: mockRepository,
            useRemote: useRemote,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dragUntilTextVisible(
    WidgetTester tester,
    String text, {
    int maxDrags = 12,
  }) async {
    final Finder textFinder = find.text(text);
    final Finder scrollable = find.byType(Scrollable).first;

    for (int i = 0; i < maxDrags && textFinder.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    expect(
      textFinder,
      findsWidgets,
      reason: 'Expected to find "$text" after scrolling the Membership page.',
    );
  }

  testWidgets('renders main Membership structure', (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
    );

    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('Meow Plus'), findsOneWidget);
    expect(find.text('Exclusive for Members'), findsOneWidget);
    expect(find.text('Your Benefits'), findsNothing);

    await dragUntilTextVisible(tester, 'Membership Plans');

    expect(find.text('Membership Plans'), findsOneWidget);
    expect(find.text('Backend Pro'), findsOneWidget);
    expect(find.text('Quarterly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
  });

  testWidgets('shows backend membership plans when repository returns plans',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
    );

    await dragUntilTextVisible(tester, 'Backend Pro');

    expect(find.text('Backend Pro'), findsOneWidget);
    expect(find.text('USD 9.99 / month'), findsOneWidget);
    expect(find.text('Backend perks'), findsOneWidget);
    expect(find.text('Mock Monthly'), findsNothing);
    expect(find.text('Quarterly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
  });

  testWidgets('falls back to mock plans when repository throws',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _MembershipRepositoryFake(plansError: Exception('offline')),
    );

    await dragUntilTextVisible(tester, 'Mock Monthly');

    expect(find.text('Mock Monthly'), findsOneWidget);
    expect(find.text('¥5 / month'), findsOneWidget);
    expect(find.text('Mock perks'), findsOneWidget);
  });

  testWidgets('shows active membership status and current plan state',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(
        plans: <MembershipPlan>[
          MembershipPlan(
            id: 'basic-monthly',
            title: 'Basic Monthly',
            price: 'USD 9.99 / month',
            perks: 'Backend perks',
          ),
        ],
        status: activeStatus,
      ),
    );

    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Basic Monthly'), findsWidgets);
    expect(find.text('Valid until June 1, 2026'), findsOneWidget);
    expect(find.text('Manage'), findsWidgets);

    await dragUntilTextVisible(tester, 'USD 9.99 / month');

    expect(find.text('Current'), findsWidgets);
  });

  testWidgets('shows soft price fallback when plan price is unavailable',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(
        plans: <MembershipPlan>[
          MembershipPlan(
            title: 'Preview Plan',
            price: 'Price unavailable',
            perks: 'Coming soon perks',
          ),
        ],
      ),
    );

    await dragUntilTextVisible(tester, 'Pricing coming soon');

    expect(find.text('Pricing coming soon'), findsOneWidget);
    expect(find.text('Price unavailable'), findsNothing);
  });

  testWidgets('status failure does not block plan cards',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _MembershipRepositoryFake(
        plans: backendPlans,
        statusError: Exception('unauthorized'),
      ),
    );

    expect(find.text('Not subscribed'), findsOneWidget);
    expect(find.text('Choose a plan to unlock VIP access'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);

    await dragUntilTextVisible(tester, 'Backend Pro');

    expect(find.text('Backend Pro'), findsOneWidget);
  });

  testWidgets('falls back to mock plans when repository returns empty',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: <MembershipPlan>[]),
    );

    await dragUntilTextVisible(tester, 'Mock Monthly');

    expect(find.text('Mock Monthly'), findsOneWidget);
    expect(find.text('¥5 / month'), findsOneWidget);
    expect(find.text('Mock perks'), findsOneWidget);
  });

  testWidgets('remote disabled uses mock plans without calling repository',
      (WidgetTester tester) async {
    final _TrackingMembershipRepository repository =
        _TrackingMembershipRepository();

    await pumpMembershipPage(
      tester,
      repository: repository,
      useRemote: false,
    );

    expect(repository.called, isFalse);

    await dragUntilTextVisible(tester, 'Mock Monthly');

    expect(find.text('Mock Monthly'), findsOneWidget);
  });
}

class _MembershipRepositoryFake implements MembershipRepository {
  const _MembershipRepositoryFake({
    this.plans = const <MembershipPlan>[],
    this.status,
    this.plansError,
    this.statusError,
  });

  final List<MembershipPlan> plans;
  final MembershipStatus? status;
  final Object? plansError;
  final Object? statusError;

  @override
  Future<List<MembershipPlan>> getPlans() async {
    final Object? error = plansError;
    if (error != null) throw error;
    return plans;
  }

  @override
  Future<MembershipStatus?> getCurrentStatus() async {
    final Object? error = statusError;
    if (error != null) throw error;
    return status;
  }
}

class _TrackingMembershipRepository implements MembershipRepository {
  bool called = false;

  @override
  Future<List<MembershipPlan>> getPlans() async {
    called = true;
    return const <MembershipPlan>[];
  }

  @override
  Future<MembershipStatus?> getCurrentStatus() async {
    called = true;
    return null;
  }
}
