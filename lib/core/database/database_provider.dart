import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'feed_dao.dart';
import 'home_dao.dart';
import 'membership_videos_dao.dart';
import 'shop_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final feedDaoProvider = Provider<FeedDao>((ref) {
  return FeedDao(ref.watch(appDatabaseProvider));
});

final homeDaoProvider = Provider<HomeDao>((ref) {
  return HomeDao(ref.watch(appDatabaseProvider));
});

final shopDaoProvider = Provider<ShopDao>((ref) {
  return ShopDao(ref.watch(appDatabaseProvider));
});

final membershipVideosDaoProvider = Provider<MembershipVideosDao>((ref) {
  return MembershipVideosDao(ref.watch(appDatabaseProvider));
});
