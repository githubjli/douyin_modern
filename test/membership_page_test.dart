import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/features/auth/application/auth_providers.dart';
import 'package:meow_media/features/auth/domain/auth_repository.dart';
import 'package:meow_media/features/auth/domain/auth_session.dart';
import 'package:meow_media/features/home/data/remote_home_repository.dart';
import 'package:meow_media/features/home/domain/home_models.dart';
import 'package:meow_media/features/membership/application/membership_providers.dart';
import 'package:meow_media/features/membership/application/membership_state.dart';
import 'package:meow_media/features/membership/domain/membership_order.dart';
import 'package:meow_media/features/membership/domain/membership_plan.dart';
import 'package:meow_media/features/membership/domain/membership_repository.dart';
import 'package:meow_media/features/membership/domain/membership_status.dart';
import 'package:meow_media/features/membership/membership_page.dart';
import 'package:meow_media/features/membership/membership_payment_page.dart';
import 'package:meow_media/features/video_detail/video_detail_page.dart';

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

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  Future<ProviderContainer> pumpMembershipPage(
    WidgetTester tester, {
    required MembershipRepository repository,
    MembershipRepository mockRepository = const _MembershipRepositoryFake(
      plans: mockPlans,
    ),
    bool useRemote = true,
    bool isActive = true,
    Future<List<HomeVideoItem>>? vipVideosFuture,
    AuthRepository? authRepository,
    RemoteHomeRepository? videoRepository,
    ProviderContainer? container,
    bool settle = true,
    VoidCallback? onSignInPressed,
    VoidCallback? onSubscribePressed,
  }) async {
    final ProviderContainer effectiveContainer = container ??
        ProviderContainer(
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(
              authRepository ?? _AuthRepositoryFake(isSignedIn: true),
            ),
            membershipRepositoryProvider.overrideWithValue(repository),
          ],
        );
    if (container == null) {
      addTearDown(effectiveContainer.dispose);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: effectiveContainer,
        child: MaterialApp(
          home: Scaffold(
            body: MembershipPage(
              repository: repository,
              mockRepository: mockRepository,
              useRemote: useRemote,
              isActive: isActive,
              vipVideosFuture: vipVideosFuture ??
                  (videoRepository == null
                      ? Future<List<HomeVideoItem>>.value(
                          const <HomeVideoItem>[],
                        )
                      : null),
              videoRepository: videoRepository,
              onSignInPressed: onSignInPressed,
              onSubscribePressed: onSubscribePressed,
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return effectiveContainer;
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

  Future<void> tapFirstBuyNow(WidgetTester tester) async {
    await dragUntilTextVisible(tester, 'Buy Now');
    final Finder buyNow = find.text('Buy Now').first;
    await tester.ensureVisible(buyNow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy Now').hitTestable().first);
    await tester.pumpAndSettle();
  }

  Future<void> tapPlanAction(
    WidgetTester tester, {
    required String planTitle,
    required String actionLabel,
  }) async {
    await dragUntilTextVisible(tester, planTitle);
    final Finder planCard = find
        .ancestor(
          of: find.text(planTitle),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget.runtimeType.toString() == '_PlanCard',
          ),
        )
        .first;
    final Finder action = find.descendant(
      of: planCard,
      matching: find.text(actionLabel),
    );

    expect(
      action,
      findsOneWidget,
      reason: 'Expected "$planTitle" plan card to show "$actionLabel".',
    );

    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action.hitTestable().first);
    await tester.pumpAndSettle();
  }

  Future<void> tapSheetAction(WidgetTester tester, String label) async {
    final Finder action = find.text(label).first;
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).hitTestable().first);
    await tester.pumpAndSettle();
  }

  testWidgets('auth checking does not show guest sign-in state',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
      authRepository: _NeverCompletingAuthRepository(),
      settle: false,
    );

    expect(find.text('Guest'), findsNothing);
    expect(find.text('Sign in required'), findsNothing);
    expect(find.text('Sign in to unlock VIP access'), findsNothing);
  });

  testWidgets('signed-out Sign in CTA triggers callback',
      (WidgetTester tester) async {
    bool signInPressed = false;

    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
      authRepository: _AuthRepositoryFake(isSignedIn: false),
      onSignInPressed: () {
        signInPressed = true;
      },
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(signInPressed, isTrue);
  });

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

  testWidgets('signed-out state shows Sign in CTA',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
      authRepository: _AuthRepositoryFake(isSignedIn: false),
    );

    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.text('Sign in to unlock VIP access'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Exclusive for Members'), findsOneWidget);

    await dragUntilTextVisible(tester, 'Membership Plans');

    expect(find.text('Membership Plans'), findsOneWidget);
  });

  testWidgets('signed-in no-membership state shows Subscribe CTA',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
    );

    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('Meow Plus'), findsOneWidget);
    expect(find.text('Not subscribed'), findsOneWidget);
    expect(find.text('Choose a plan to unlock VIP access'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Exclusive for Members'), findsOneWidget);

    await dragUntilTextVisible(tester, 'Membership Plans');

    expect(find.text('Membership Plans'), findsOneWidget);
  });

  testWidgets('signed-out Buy Now routes to sign-in without creating order',
      (WidgetTester tester) async {
    bool signInPressed = false;
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly',
          price: 'USD 9.99 / month',
          perks: 'Monthly perks',
        ),
      ],
    );

    await pumpMembershipPage(
      tester,
      repository: repository,
      authRepository: _AuthRepositoryFake(isSignedIn: false),
      onSignInPressed: () {
        signInPressed = true;
      },
    );
    await dragUntilTextVisible(tester, 'Membership Plans');

    await tapFirstBuyNow(tester);

    expect(signInPressed, isTrue);
    expect(repository.createOrderCalls, 0);
  });

  testWidgets('signed-in Buy Now shows confirmation without creating order',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly',
          price: 'USD 9.99 / month',
          perks: 'Monthly perks',
        ),
      ],
      order: const MembershipOrder(
        orderNo: 'order-100',
        status: 'pending',
        planCode: 'monthly',
        planTitle: 'Monthly',
        expectedAmountLbc: '12.5',
        currency: 'LBC',
        payToAddress: 'lbc-address-100',
        expiresAt: '2026-06-01T00:00:00Z',
      ),
    );

    await pumpMembershipPage(tester, repository: repository);
    await dragUntilTextVisible(tester, 'Membership Plans');

    await tapFirstBuyNow(tester);

    expect(repository.createOrderCalls, 0);
    expect(find.text('Confirm subscription'), findsOneWidget);
    expect(find.text('Monthly'), findsWidgets);
    expect(find.text('USD 9.99 / month'), findsWidgets);
    expect(find.text('Monthly perks'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm and create order'), findsOneWidget);
    expect(find.text('Complete payment'), findsNothing);
    expect(find.text('lbc-address-100'), findsNothing);
  });

  testWidgets('confirm creates order and opens payment page',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly',
          price: 'USD 9.99 / month',
          perks: 'Monthly perks',
        ),
      ],
      order: const MembershipOrder(
        orderNo: 'order-100',
        status: 'pending',
        planCode: 'monthly',
        planTitle: 'Monthly',
        expectedAmountLbc: '12.5',
        currency: 'LBC',
        payToAddress: 'lbc-address-100',
        expiresAt: '2026-06-01T00:00:00Z',
      ),
    );

    await pumpMembershipPage(tester, repository: repository);
    await dragUntilTextVisible(tester, 'Membership Plans');

    await tapFirstBuyNow(tester);
    expect(repository.createOrderCalls, 0);

    await tapSheetAction(tester, 'Confirm and create order');

    expect(repository.createOrderCalls, 1);
    expect(repository.createdPlanCodes, <String>['monthly']);
    expect(find.text('Confirm subscription'), findsNothing);
    expect(find.byType(MembershipPaymentPage), findsOneWidget);
    expect(find.text('Membership Purchase'), findsOneWidget);
    expect(find.text('Receiving Address'), findsOneWidget);
    expect(find.byTooltip('Copy address'), findsOneWidget);
    expect(find.text('lbc-address-100'), findsOneWidget);
  });

  testWidgets('quarterly selected plan opens payment page with 90 day duration',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly Membership',
          price: '30.00 THB-LTT / 30 days',
          perks: 'Monthly access',
          durationDays: 30,
          settlementTokenSymbol: 'THB-LTT',
        ),
        MembershipPlan(
          code: 'quarterly',
          title: 'Quarterly Membership',
          price: '80.00 THB-LTT / 90 days',
          perks: 'Quarterly access',
          durationDays: 90,
          settlementTokenSymbol: 'THB-LTT',
        ),
        MembershipPlan(
          code: 'yearly',
          title: 'Yearly Membership',
          price: '300.00 THB-LTT / 365 days',
          perks: 'Yearly access',
          durationDays: 365,
          settlementTokenSymbol: 'THB-LTT',
        ),
      ],
      order: const MembershipOrder(
        orderNo: 'order-quarterly',
        status: 'pending',
        planCode: 'quarterly',
        planTitle: 'Quarterly Membership',
        expectedAmountLbc: '80.00000000',
        payToAddress: 'quarterly-pay-address',
      ),
    );

    await pumpMembershipPage(tester, repository: repository);
    await tapPlanAction(
      tester,
      planTitle: 'Quarterly Membership',
      actionLabel: 'Buy Now',
    );
    await tapSheetAction(tester, 'Confirm and create order');

    expect(repository.createdPlanCodes, <String>['quarterly']);
    expect(find.byType(MembershipPaymentPage), findsOneWidget);
    expect(find.text('Quarterly Membership'), findsOneWidget);
    expect(find.text('80.00'), findsOneWidget);
    expect(find.text('THB-LTT'), findsWidgets);
    expect(find.text('Duration: 90 days'), findsOneWidget);
    expect(find.text('Duration: 30 days'), findsNothing);
    expect(find.text('Duration: 365 days'), findsNothing);
    expect(find.text('quarterly-pay-address'), findsOneWidget);
  });

  testWidgets('cancel confirmation does not create order',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly',
          price: 'USD 9.99 / month',
          perks: 'Monthly perks',
        ),
      ],
    );

    await pumpMembershipPage(tester, repository: repository);
    await dragUntilTextVisible(tester, 'Membership Plans');

    await tapFirstBuyNow(tester);
    expect(find.text('Confirm subscription'), findsOneWidget);

    await tapSheetAction(tester, 'Cancel');

    expect(repository.createOrderCalls, 0);
    expect(find.text('Confirm subscription'), findsNothing);
    expect(find.text('Complete payment'), findsNothing);
  });

  testWidgets('missing plan code shows error without creating order',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          title: 'No Code Monthly',
          price: 'USD 9.99 / month',
          perks: 'Plan without code',
        ),
      ],
    );

    await pumpMembershipPage(tester, repository: repository);
    await tapPlanAction(
      tester,
      planTitle: 'No Code Monthly',
      actionLabel: 'Buy Now',
    );

    expect(repository.createOrderCalls, 0);
    expect(
      find.text('Plan is unavailable. Please try again later.'),
      findsOneWidget,
    );
  });

  testWidgets('create order failure shows error without activating membership',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly',
          price: 'USD 9.99 / month',
          perks: 'Monthly perks',
        ),
      ],
      createOrderError: Exception('offline'),
    );

    await pumpMembershipPage(tester, repository: repository);

    expect(find.text('Not subscribed'), findsOneWidget);
    await dragUntilTextVisible(tester, 'Membership Plans');
    await tapFirstBuyNow(tester);

    expect(repository.createOrderCalls, 0);
    expect(find.text('Confirm subscription'), findsOneWidget);

    await tapSheetAction(tester, 'Confirm and create order');

    expect(repository.createOrderCalls, 1);
    expect(
      find.text('Unable to create order. Please try again later.'),
      findsOneWidget,
    );
    expect(find.text('Complete payment'), findsNothing);
    expect(find.text('Not subscribed'), findsOneWidget);
    expect(find.text('Member'), findsNothing);
  });

  testWidgets('payment page copy actions show confirmation messages',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly',
          price: 'USD 9.99 / month',
          perks: 'Monthly perks',
        ),
      ],
      order: const MembershipOrder(
        orderNo: 'order-copy',
        status: 'pending',
        expectedAmountLbc: '4.25',
        currency: 'LBC',
        payToAddress: 'copy-address',
      ),
    );

    await pumpMembershipPage(tester, repository: repository);
    await dragUntilTextVisible(tester, 'Membership Plans');
    await tapFirstBuyNow(tester);
    await tapSheetAction(tester, 'Confirm and create order');

    final Finder copyAddress = find.byTooltip('Copy address');
    await tester.ensureVisible(copyAddress);
    await tester.pumpAndSettle();
    await tester.tap(copyAddress);
    await tester.pumpAndSettle();
    expect(find.text('Address copied'), findsOneWidget);
  });

  testWidgets('paid order status does not locally activate membership',
      (WidgetTester tester) async {
    final _OrderTrackingMembershipRepository repository =
        _OrderTrackingMembershipRepository(
      plans: const <MembershipPlan>[
        MembershipPlan(
          code: 'monthly',
          title: 'Monthly',
          price: 'USD 9.99 / month',
          perks: 'Monthly perks',
        ),
      ],
      order: const MembershipOrder(
        orderNo: 'order-paid',
        status: 'overpaid',
        planCode: 'monthly',
        planTitle: 'Monthly',
        expectedAmountLbc: '5',
        currency: 'LBC',
        payToAddress: 'paid-address',
      ),
    );

    await pumpMembershipPage(tester, repository: repository);

    expect(find.text('Not subscribed'), findsOneWidget);
    await dragUntilTextVisible(tester, 'Membership Plans');
    await tapFirstBuyNow(tester);
    await tapSheetAction(tester, 'Confirm and create order');

    expect(find.byType(MembershipPaymentPage), findsOneWidget);
    expect(find.text('Membership Purchase'), findsOneWidget);

    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();

    expect(find.byType(MembershipPaymentPage), findsNothing);
    expect(find.text('Not subscribed'), findsOneWidget);
    expect(find.text('Member'), findsNothing);
  });

  testWidgets('logout resets active membership to guest state',
      (WidgetTester tester) async {
    final ProviderContainer container = await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(
        plans: backendPlans,
        status: activeStatus,
      ),
    );

    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Basic Monthly'), findsWidgets);

    await container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.text('Member'), findsNothing);
    expect(find.text('Basic Monthly'), findsNothing);
    expect(
      container.read(membershipControllerProvider).status,
      MembershipLoadStatus.unknown,
    );
  });

  testWidgets('refreshes membership state when tab becomes active',
      (WidgetTester tester) async {
    final _MutableMembershipRepository repository = _MutableMembershipRepository(
      plans: backendPlans,
    );
    final _AuthRepositoryFake authRepository = _AuthRepositoryFake(
      isSignedIn: true,
    );
    final Future<List<HomeVideoItem>> vipVideosFuture =
        Future<List<HomeVideoItem>>.value(const <HomeVideoItem>[]);

    final ProviderContainer container = await pumpMembershipPage(
      tester,
      repository: repository,
      authRepository: authRepository,
      isActive: false,
      vipVideosFuture: vipVideosFuture,
    );

    expect(find.text('Meow Plus'), findsOneWidget);
    expect(find.text('Not subscribed'), findsOneWidget);

    repository.status = activeStatus;

    await pumpMembershipPage(
      tester,
      repository: repository,
      authRepository: authRepository,
      container: container,
      vipVideosFuture: vipVideosFuture,
    );

    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Basic Monthly'), findsWidgets);
    expect(find.text('Valid until June 1, 2026'), findsWidgets);
    expect(repository.statusCalls, greaterThanOrEqualTo(2));
    expect(container.read(membershipControllerProvider).isActive, isTrue);
  });

  testWidgets(
    'preserves signed-in state when tab refresh hits transient auth error',
    (WidgetTester tester) async {
      final _MutableMembershipRepository repository =
          _MutableMembershipRepository(
        plans: backendPlans,
      );
      final _AuthRepositoryFake authRepository = _AuthRepositoryFake(
        isSignedIn: true,
      );

      final ProviderContainer container = await pumpMembershipPage(
        tester,
        repository: repository,
        authRepository: authRepository,
        isActive: false,
      );

      expect(find.text('Meow Plus'), findsOneWidget);
      expect(find.text('Not subscribed'), findsOneWidget);

      authRepository.sessionError = Exception('offline');
      await container.read(authControllerProvider.notifier).refreshSession();
      await tester.pumpAndSettle();

      await pumpMembershipPage(
        tester,
        repository: repository,
        authRepository: authRepository,
        container: container,
      );

      expect(find.text('Meow Plus'), findsOneWidget);
      expect(find.text('Not subscribed'), findsOneWidget);
      expect(find.text('Guest'), findsNothing);
      expect(find.text('Sign in required'), findsNothing);
      expect(authRepository.sessionCalls, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'preserves active membership when tab refresh hits transient status error',
    (WidgetTester tester) async {
      final _MutableMembershipRepository repository =
          _MutableMembershipRepository(
        plans: backendPlans,
      )..status = activeStatus;
      final _AuthRepositoryFake authRepository = _AuthRepositoryFake(
        isSignedIn: true,
      );

      final ProviderContainer container = await pumpMembershipPage(
        tester,
        repository: repository,
        authRepository: authRepository,
        isActive: false,
      );

      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Basic Monthly'), findsWidgets);

      repository.statusError = Exception('temporary server failure');
      await container.read(membershipControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      await pumpMembershipPage(
        tester,
        repository: repository,
        authRepository: authRepository,
        container: container,
      );

      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Basic Monthly'), findsWidgets);
      expect(find.text('Not subscribed'), findsNothing);
      expect(repository.statusCalls, greaterThanOrEqualTo(2));
    },
  );

  for (final int statusCode in <int>[401, 403]) {
    testWidgets(
      'auth denied $statusCode during tab refresh downgrades to signed-out '
      'state',
      (WidgetTester tester) async {
        final _MutableMembershipRepository repository =
            _MutableMembershipRepository(
          plans: backendPlans,
        )..status = activeStatus;
        final _AuthRepositoryFake authRepository = _AuthRepositoryFake(
          isSignedIn: true,
        );

        final ProviderContainer container = await pumpMembershipPage(
          tester,
          repository: repository,
          authRepository: authRepository,
          isActive: false,
        );

        expect(find.text('Member'), findsOneWidget);
        expect(find.text('Basic Monthly'), findsWidgets);

        authRepository.sessionError = ApiError(
          message: 'Auth denied',
          statusCode: statusCode,
        );
        repository.statusError = ApiError(
          message: 'Auth denied',
          statusCode: statusCode,
        );

        await container.read(authControllerProvider.notifier).refreshSession();
        await tester.pumpAndSettle();

        await pumpMembershipPage(
          tester,
          repository: repository,
          authRepository: authRepository,
          container: container,
        );

        expect(find.text('Guest'), findsOneWidget);
        expect(find.text('Sign in required'), findsOneWidget);
        expect(find.text('Member'), findsNothing);
        expect(
          container.read(membershipControllerProvider).status,
          MembershipLoadStatus.unknown,
        );
      },
    );
  }

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
    expect(find.text('Valid until June 1, 2026'), findsWidgets);
    expect(find.text('Manage'), findsWidgets);

    await dragUntilTextVisible(tester, 'USD 9.99 / month');

    expect(find.text('Current'), findsWidgets);
  });

  testWidgets('shows mapped membership plan token prices',
      (WidgetTester tester) async {
    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(
        plans: <MembershipPlan>[
          MembershipPlan(
            code: 'monthly',
            title: 'Monthly',
            price: '30 THB-LTT / 30 days',
            perks: 'Monthly access',
          ),
          MembershipPlan(
            code: 'quarterly',
            title: 'Quarterly',
            price: '80 THB-LTT / 90 days',
            perks: 'Quarterly access',
          ),
          MembershipPlan(
            code: 'yearly',
            title: 'Yearly',
            price: '300 THB-LTT / 365 days',
            perks: 'Yearly access',
          ),
        ],
      ),
    );

    await dragUntilTextVisible(tester, '30 THB-LTT / 30 days');

    expect(find.text('30 THB-LTT / 30 days'), findsOneWidget);
    expect(find.text('80 THB-LTT / 90 days'), findsOneWidget);
    expect(find.text('300 THB-LTT / 365 days'), findsOneWidget);
    expect(find.text('Pricing coming soon'), findsNothing);
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

  testWidgets('loads VIP videos with authenticated public video requests',
      (WidgetTester tester) async {
    final _TrackingHomeRepository videoRepository = _TrackingHomeRepository(
      pages: <HomeVideoPage>[
        const HomeVideoPage(
          items: <HomeVideoItem>[
            HomeVideoItem(
              id: 'vip-video',
              title: 'Members Only Cut',
              subtitle: 'VIP Studio • 120 views',
              ownerName: 'VIP Studio',
              viewCount: 120,
              accessType: 'membership',
              canWatch: true,
              isLocked: false,
              videoUrl: 'https://example.com/vip.mp4',
            ),
          ],
        ),
      ],
    );

    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
      vipVideosFuture: null,
      videoRepository: videoRepository,
    );

    expect(videoRepository.calls, hasLength(1));
    expect(videoRepository.calls.single.accessType, 'membership');
    expect(videoRepository.calls.single.pageSize, 4);
    expect(videoRepository.calls.single.authenticated, isTrue);
    expect(find.text('Members Only Cut'), findsOneWidget);
  });

  testWidgets('loads VIP fallback videos with authenticated requests',
      (WidgetTester tester) async {
    final _TrackingHomeRepository videoRepository = _TrackingHomeRepository(
      pages: <HomeVideoPage>[
        const HomeVideoPage(items: <HomeVideoItem>[]),
        const HomeVideoPage(
          items: <HomeVideoItem>[
            HomeVideoItem(
              id: 'vip-fallback-video',
              title: 'Fallback Members Cut',
              subtitle: 'VIP Studio • 80 views',
              accessType: 'membership',
              canWatch: true,
              isLocked: false,
              videoUrl: 'https://example.com/fallback.mp4',
            ),
          ],
        ),
      ],
    );

    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
      videoRepository: videoRepository,
    );

    expect(videoRepository.calls, hasLength(2));
    expect(videoRepository.calls.first.accessType, 'membership');
    expect(videoRepository.calls.first.authenticated, isTrue);
    expect(videoRepository.calls.last.accessType, isNull);
    expect(videoRepository.calls.last.pageSize, 12);
    expect(videoRepository.calls.last.authenticated, isTrue);
    expect(find.text('Fallback Members Cut'), findsOneWidget);
  });

  testWidgets('renders VIP videos and opens shared video detail flow',
      (WidgetTester tester) async {
    const HomeVideoItem vipVideo = HomeVideoItem(
      id: 'vip-video',
      title: 'Members Only Cut',
      subtitle: 'VIP Studio • 120 views',
      ownerName: 'VIP Studio',
      viewCount: 120,
      accessType: 'membership',
      isLocked: true,
      thumbnailUrl: '',
    );

    await pumpMembershipPage(
      tester,
      repository: const _MembershipRepositoryFake(plans: backendPlans),
      vipVideosFuture: Future<List<HomeVideoItem>>.value(
        const <HomeVideoItem>[vipVideo],
      ),
    );

    expect(find.text('Exclusive for Members'), findsOneWidget);

    const Key vipCardKey = ValueKey<String>(
      'membership-vip-video-card-vip-video',
    );
    final Finder vipCard = find.byKey(vipCardKey);

    expect(vipCard, findsOneWidget);

    await tester.ensureVisible(vipCard);
    await tester.pumpAndSettle();

    expect(find.text('Members Only Cut'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);

    await tester.tap(vipCard);
    await tester.pumpAndSettle();

    expect(find.byType(VideoDetailPage), findsOneWidget);
  });

  testWidgets('remote disabled uses mock plans without calling repository',
      (WidgetTester tester) async {
    final _TrackingMembershipRepository repository =
        _TrackingMembershipRepository();

    await pumpMembershipPage(
      tester,
      repository: repository,
      useRemote: false,
      authRepository: _AuthRepositoryFake(isSignedIn: false),
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

class _MutableMembershipRepository implements MembershipRepository {
  _MutableMembershipRepository({required this.plans});

  final List<MembershipPlan> plans;
  MembershipStatus? status;
  Object? statusError;
  int statusCalls = 0;

  @override
  Future<List<MembershipPlan>> getPlans() async => plans;

  @override
  Future<MembershipStatus?> getCurrentStatus() async {
    statusCalls += 1;
    final Object? error = statusError;
    if (error != null) throw error;
    return status;
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

class _AuthRepositoryFake implements AuthRepository {
  _AuthRepositoryFake({required this.isSignedIn});

  bool isSignedIn;
  Object? sessionError;
  int sessionCalls = 0;

  @override
  Future<AuthSession> getCurrentSession() async {
    sessionCalls += 1;
    final Object? error = sessionError;
    if (error != null) throw error;
    return AuthSession(
      isSignedIn: isSignedIn,
      userId: isSignedIn ? 'user-1' : null,
      displayName: isSignedIn ? 'Meow User' : 'Guest',
    );
  }

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> refreshSession() => getCurrentSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw UnimplementedError();
  }
}

class _TrackingHomeRepository extends RemoteHomeRepository {
  _TrackingHomeRepository({required this.pages}) : super(apiClient: ApiClient());

  final List<HomeVideoPage> pages;
  final List<_VideoPageCall> calls = <_VideoPageCall>[];
  int _nextPageIndex = 0;

  @override
  Future<HomeVideoPage> getVideoPage({
    String? pageUrl,
    String? category,
    String? accessType,
    int pageSize = RemoteHomeRepository.defaultVideoPageSize,
    bool authenticated = false,
  }) async {
    calls.add(
      _VideoPageCall(
        pageUrl: pageUrl,
        category: category,
        accessType: accessType,
        pageSize: pageSize,
        authenticated: authenticated,
      ),
    );
    if (_nextPageIndex >= pages.length) {
      return const HomeVideoPage(items: <HomeVideoItem>[]);
    }
    return pages[_nextPageIndex++];
  }
}

class _VideoPageCall {
  const _VideoPageCall({
    required this.pageUrl,
    required this.category,
    required this.accessType,
    required this.pageSize,
    required this.authenticated,
  });

  final String? pageUrl;
  final String? category;
  final String? accessType;
  final int pageSize;
  final bool authenticated;
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

class _OrderTrackingMembershipRepository implements MembershipRepository {
  _OrderTrackingMembershipRepository({
    required this.plans,
    this.order = const MembershipOrder(
      orderNo: 'order-default',
      status: 'pending',
    ),
    this.createOrderError,
  });

  final List<MembershipPlan> plans;
  final MembershipOrder order;
  final Object? createOrderError;
  int createOrderCalls = 0;
  final List<String> createdPlanCodes = <String>[];

  @override
  Future<List<MembershipPlan>> getPlans() async => plans;

  @override
  Future<MembershipStatus?> getCurrentStatus() async => null;

  @override
  Future<MembershipOrder> createOrder({required String planCode}) async {
    createOrderCalls += 1;
    createdPlanCodes.add(planCode);
    final Object? error = createOrderError;
    if (error != null) throw error;
    return order;
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

class _NeverCompletingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> getCurrentSession() => Completer<AuthSession>().future;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> refreshSession() => getCurrentSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw UnimplementedError();
  }
}
