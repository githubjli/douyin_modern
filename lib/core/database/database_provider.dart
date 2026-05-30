import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'feed_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final feedDaoProvider = Provider<FeedDao>((ref) {
  return FeedDao(ref.watch(appDatabaseProvider));
});
