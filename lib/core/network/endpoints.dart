class Endpoints {
  const Endpoints._();

  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authRefresh = '/api/auth/refresh';
  static const String authMe = '/api/auth/me';

  static const String accountProfile = '/api/account/profile';
  static const String accountChangePassword = '/api/account/change-password/';

  static const String meowPointsWallet = '/api/meow-points/wallet/';
  static const String meowPointsDailyReward =
      '/api/meow-points/daily-login-reward/';

  // Meow Credit
  static const String meowCreditWallet = '/api/meow-credits/wallet/';
  static const String meowCreditPackages = '/api/meow-credits/packages/';
  static const String meowCreditRecharges = '/api/meow-credits/recharges/';
  static const String meowCreditLedger = '/api/meow-credits/ledger/';
  static const String meowCreditRedeems = '/api/meow-credits/redeems/';

  static String meowCreditRechargeInfo(String packageCode) =>
      '/api/meow-credits/recharge-info/?package_code=${Uri.encodeComponent(packageCode)}';

  static const String meowCreditSubmitTxid =
      '/api/meow-credits/recharges/submit-txid/';

  static String meowCreditRechargeDetail(String orderNo) =>
      '/api/meow-credits/recharges/${Uri.encodeComponent(orderNo)}/';

  static String meowCreditVerifyNow(String orderNo) =>
      '/api/meow-credits/recharges/${Uri.encodeComponent(orderNo)}/verify-now/';

  static const String publicVideos = '/api/public/videos/';

  static String publicVideoDetail(int id) => '/api/public/videos/$id/';

  static String videoComments(int id) => '/api/public/videos/$id/comments/';

  static String videoPostComment(int id) => '/api/videos/$id/comments/';

  static String videoLike(int id) => '/api/videos/$id/like/';

  static String creatorFollow(int creatorId) =>
      '/api/creators/$creatorId/follow/';

  static const String dramas = '/api/dramas/';

  static String dramaDetail(int id) => '/api/dramas/$id/';

  static String dramaEpisodes(int dramaId) => '/api/dramas/$dramaId/episodes/';

  static String dramaEpisodeDetail(int dramaId, int episodeNo) =>
      '/api/dramas/$dramaId/episodes/$episodeNo/';

  static String dramaEpisodeUnlock(int episodeId) =>
      '/api/dramas/episodes/$episodeId/unlock/';

  static String dramaProgress(int dramaId) => '/api/dramas/$dramaId/progress/';

  static const String membershipPlans = '/api/membership/plans/';
  static const String membershipOrders = '/api/membership/orders/';
  static const String membershipMe = '/api/membership/me/';

  static String membershipOrderDetail(String orderNo) =>
      '/api/membership/orders/${Uri.encodeComponent(orderNo)}/';

  static String membershipOrderTxHint(String orderNo) =>
      '/api/membership/orders/${Uri.encodeComponent(orderNo)}/tx-hint/';

  static String membershipOrderVerifyNow(String orderNo) =>
      '/api/membership/orders/${Uri.encodeComponent(orderNo)}/verify-now/';

  // Live streaming endpoints
  static const String liveQuickStart = '/api/live/quick-start/';

  static String liveDetail(String id) => '/api/live/$id/';

  static String liveStatus(String id) => '/api/live/$id/status/';

  static String liveStart(String id) => '/api/live/$id/start/';

  static String liveEnd(String id) => '/api/live/$id/end/';

  static String liveChatMessages(String id) => '/api/live/$id/chat/messages/';

  // Manual (staff-reviewed) payment endpoints
  static String manualPaymentInfo(String planCode) =>
      '/api/membership/manual/payment-info/?plan_code=${Uri.encodeComponent(planCode)}';

  static const String manualTxHints = '/api/membership/manual/tx-hints/';

  static String manualTxHintVerifyNow(int id) =>
      '/api/membership/manual/tx-hints/$id/verify-now/';
}
