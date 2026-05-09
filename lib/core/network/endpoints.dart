class Endpoints {
  const Endpoints._();

  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authRefresh = '/api/auth/refresh';
  static const String authMe = '/api/auth/me';

  static const String accountProfile = '/api/account/profile';

  static const String publicVideos = '/api/public/videos/';

  static String publicVideoDetail(int id) => '/api/public/videos/$id/';

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
}
