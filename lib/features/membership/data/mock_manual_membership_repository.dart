import '../domain/manual_membership_repository.dart';
import '../domain/manual_payment_info.dart';
import '../domain/manual_tx_hint.dart';
import '../domain/membership_status.dart';

class MockManualMembershipRepository implements ManualMembershipRepository {
  MockManualMembershipRepository({
    this.paymentInfoByPlan = const <String, ManualPaymentInfo>{},
    this.txHints = const <ManualTxHint>[],
    this.submitError,
    this.submitDisabled = false,
    this.membershipStatus,
  });

  final Map<String, ManualPaymentInfo> paymentInfoByPlan;
  final List<ManualTxHint> txHints;
  final Object? submitError;
  final bool submitDisabled;
  final MembershipStatus? membershipStatus;

  // Track calls for tests
  int getPaymentInfoCalls = 0;
  int getTxHintsCalls = 0;
  int submitTxHintCalls = 0;
  String? lastSubmittedPlanCode;
  String? lastSubmittedTxid;

  static const ManualPaymentInfo _defaultPaymentInfo = ManualPaymentInfo(
    planCode: 'monthly',
    planName: 'Basic Monthly',
    expectedAmountLbc: '30.00000000',
    currency: 'THB-LTT',
    payToAddress: 'mock-lbc-address-bPrWVMvpgqjeViHJPKUQcK',
    requiredConfirmations: 0,
    notice:
        'Send the exact THB-LTT amount to the platform address, then wait for staff verification.',
  );

  @override
  Future<ManualPaymentInfo> getPaymentInfo({required String planCode}) async {
    getPaymentInfoCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return paymentInfoByPlan[planCode] ??
        ManualPaymentInfo(
          planCode: planCode,
          planName: _planName(planCode),
          expectedAmountLbc: _planAmount(planCode),
          currency: 'THB-LTT',
          payToAddress: _defaultPaymentInfo.payToAddress,
          requiredConfirmations: 0,
          notice: _defaultPaymentInfo.notice,
        );
  }

  @override
  Future<List<ManualTxHint>> getTxHints() async {
    getTxHintsCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<ManualTxHint>.from(txHints);
  }

  @override
  Future<ManualTxHint> submitTxHint({
    required String planCode,
    required String txid,
  }) async {
    submitTxHintCalls++;
    lastSubmittedPlanCode = planCode;
    lastSubmittedTxid = txid;
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (submitDisabled) {
      throw const ManualTxSubmitDisabledException(
        'This endpoint does not accept txid submission.',
      );
    }
    final Object? error = submitError;
    if (error != null) throw error;

    return ManualTxHint(
      id: DateTime.now().millisecondsSinceEpoch,
      planCode: planCode,
      planName: _planName(planCode),
      txid: txid,
      status: ManualTxHintStatus.pending,
      confirmations: 0,
      expectedAmountLbc: _planAmount(planCode),
      payToAddress: _defaultPaymentInfo.payToAddress,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<ManualTxHintVerifyResult> verifyNow(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const ManualTxHintVerifyResult(
      verified: false,
      status: 'pending_confirmation',
      reason: 'pending_confirmation',
      confirmations: 0,
      requiredConfirmations: 1,
    );
  }

  @override
  Future<MembershipStatus?> getMembershipStatus() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return membershipStatus;
  }

  static String _planName(String planCode) => switch (planCode) {
        'monthly' => 'Basic Monthly',
        'quarterly' => 'Basic Quarterly',
        'yearly' => 'Basic Yearly',
        _ => 'Membership',
      };

  static String _planAmount(String planCode) => switch (planCode) {
        'monthly' => '30.00000000',
        'quarterly' => '80.00000000',
        'yearly' => '300.00000000',
        _ => '30.00000000',
      };
}
