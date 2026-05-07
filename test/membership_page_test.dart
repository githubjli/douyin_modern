import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/membership/domain/membership_plan.dart';
import 'package:meow_media/features/membership/domain/membership_repository.dart';
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
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipPage(
            repository: repository,
            mockRepository: _PlanRepository.value(mockPlans),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows backend membership plans when repository returns plans',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository.value(remotePlans),
    );

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

    expect(find.text('Mock Monthly'), findsOneWidget);
    expect(find.text('¥5 / month'), findsOneWidget);
    expect(find.text('Mock perks'), findsOneWidget);
  });

  testWidgets('falls back to mock plans when repository returns empty',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: _PlanRepository.value(const <MembershipPlan>[]),
    );

    expect(find.text('Mock Monthly'), findsOneWidget);
    expect(find.text('¥5 / month'), findsOneWidget);
    expect(find.text('Mock perks'), findsOneWidget);
  });
}

class _PlanRepository implements MembershipRepository {
  const _PlanRepository._(this._load);

  factory _PlanRepository.value(List<MembershipPlan> plans) {
    return _PlanRepository._(() async => plans);
  }

  factory _PlanRepository.error(Object error) {
    return _PlanRepository._(() => Future<List<MembershipPlan>>.error(error));
  }

  final Future<List<MembershipPlan>> Function() _load;

  @override
  Future<List<MembershipPlan>> getPlans() => _load();
}

