import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/membership/domain/membership_plan.dart';
import 'package:meow_media/features/membership/domain/membership_repository.dart';
import 'package:meow_media/features/membership/domain/membership_status.dart';
import 'package:meow_media/features/membership/membership_page.dart';

void main() {
  const List<MembershipPlan> remotePlans = <MembershipPlan>[
    MembershipPlan(
      id: 'pro',
      title: 'Backend Pro',
      price: 'USD 9.99 / month',
      perks: 'Backend perks',
    ),
  ];

  const MembershipStatus activeStatus = MembershipStatus(
    planTitle: 'Basic Monthly',
    status: 'active',
    endsAt: '2026-06-01T00:00:00Z',
    isActive: true,
  );

  const List<MembershipPlan> mockPlans = <MembershipPlan>[
    MembershipPlan(
      id: 'mock',
      title: 'Mock Monthly',
      price: '¥5 / month',
      perks: 'Mock perks',
    ),
  ];

  Future<void> pumpMembershipPage(
    WidgetTester tester, {
    required MembershipRepository repository,
    bool useRemote = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipPage(
            repository: repository,
            mockRepository: _PlanRepository.value(mockPlans),
            useRemote: useRemote,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToText(WidgetTester tester, String text) async {
    final Finder finder = find.text(text);
    if (tester.any(finder)) {
      await tester.ensureVisible(finder);
    } else {
      await tester.scrollUntilVisible(
        finder,
        320,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets('renders main structure and backend plans',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository.value(remotePlans),
    );

    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('Meow Plus'), findsOneWidget);
    expect(find.text('Exclusive for Members'), findsOneWidget);
    expect(find.text('Your Benefits'), findsNothing);

    await scrollToText(tester, 'Choose your plan');

    expect(find.text('Choose your plan'), findsOneWidget);

    await scrollToText(tester, 'Backend Pro');

    expect(find.text('Backend Pro'), findsOneWidget);
    expect(find.text('USD 9.99 / month'), findsOneWidget);
    expect(find.text('Backend perks'), findsOneWidget);
    expect(find.text('Mock Monthly'), findsNothing);
  });

  testWidgets('falls back to mock plans when repository throws',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository.error(Exception('offline')),
    );

    await scrollToText(tester, 'Mock Monthly');

    expect(find.text('Mock Monthly'), findsOneWidget);
    expect(find.text('¥5 / month'), findsOneWidget);
    expect(find.text('Mock perks'), findsOneWidget);
  });

  testWidgets('shows active membership status above plan cards',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository.value(
        const <MembershipPlan>[
          MembershipPlan(
            id: 'basic',
            title: 'Basic Monthly',
            price: 'USD 9.99 / month',
            perks: 'Backend perks',
          ),
        ],
        status: activeStatus,
      ),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Basic Monthly'), findsOneWidget);
    expect(find.text('Valid until June 1, 2026'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);

    await scrollToText(tester, 'Current plan');

    expect(find.text('Current plan'), findsWidgets);
  });

  testWidgets('shows softer copy when a plan has no price',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository.value(
        const <MembershipPlan>[
          MembershipPlan(
            title: 'Preview Plan',
            price: 'Price unavailable',
            perks: 'Coming soon perks',
          ),
        ],
      ),
    );

    await scrollToText(tester, 'Pricing coming soon');

    expect(find.text('Pricing coming soon'), findsOneWidget);
    expect(find.text('Price unavailable'), findsNothing);
  });

  testWidgets('status failure does not block plan cards',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository(
        plans: remotePlans,
        statusError: Exception('unauthorized'),
      ),
    );

    expect(find.text('Sign in required'), findsOneWidget);

    await scrollToText(tester, 'Backend Pro');

    expect(find.text('Backend Pro'), findsOneWidget);
  });

  testWidgets('falls back to mock plans when repository returns empty',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository.value(const <MembershipPlan>[]),
    );

    await scrollToText(tester, 'Mock Monthly');

    expect(find.text('Mock Monthly'), findsOneWidget);
    expect(find.text('¥5 / month'), findsOneWidget);
    expect(find.text('Mock perks'), findsOneWidget);
  });

  testWidgets(
      'uses mock plans without calling repository when remote is disabled',
      (WidgetTester tester) async {
    final _TrackingPlanRepository repository = _TrackingPlanRepository();

    await pumpMembershipPage(
      tester,
      repository: repository,
      useRemote: false,
    );

    expect(repository.called, isFalse);

    await scrollToText(tester, 'Mock Monthly');

    expect(find.text('Mock Monthly'), findsOneWidget);
  });
}

class _PlanRepository implements MembershipRepository {
  const _PlanRepository({
    this.plans = const <MembershipPlan>[],
    this.status,
    this.plansError,
    this.statusError,
  });

  factory _PlanRepository.value(
    List<MembershipPlan> plans, {
    MembershipStatus? status,
  }) {
    return _PlanRepository(plans: plans, status: status);
  }

  factory _PlanRepository.error(Object error) {
    return _PlanRepository(plansError: error);
  }

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

class _TrackingPlanRepository implements MembershipRepository {
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
