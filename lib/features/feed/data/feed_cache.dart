import '../../../core/database/app_database.dart';
import '../../../core/database/feed_dao.dart';
import '../domain/feed_item.dart';

/// Facade that delegates all persistence to [FeedDao] (Drift / SQLite).
///
/// Public API is identical to the previous SharedPreferences implementation
/// so [FeedPage] requires no changes.
///
/// Cache-first strategy:
///   1. loadFeed()  → returns rows within TTL (2 h), null if expired.
///   2. saveFeed()  → overwrites all rows and resets the TTL clock.
///   3. loadStale() → ignores TTL; used when offline so users always see
///                    content rather than an empty screen.
class FeedCache {
  FeedCache({AppDatabase? db}) : _dao = FeedDao(db ?? AppDatabase());

  final FeedDao _dao;

  // ------------------------------------------------------------------
  // Feed list
  // ------------------------------------------------------------------

  Future<void> saveFeed(List<FeedItem> items) => _dao.saveFeed(items);

  Future<List<FeedItem>?> loadFeed() => _dao.loadFeed();

  Future<List<FeedItem>?> loadStale() => _dao.loadStale();

  Future<void> clearFeed() => _dao.clearFeed();

  // ------------------------------------------------------------------
  // Last viewed index
  // ------------------------------------------------------------------

  Future<void> saveLastIndex(int index) => _dao.saveLastIndex(index);

  Future<int> loadLastIndex() => _dao.loadLastIndex();

  // ------------------------------------------------------------------
  // Per-episode playback progress
  // ------------------------------------------------------------------

  Future<void> saveProgress(int episodeId, int positionSeconds) =>
      _dao.saveProgress(episodeId, positionSeconds);

  Future<int?> loadProgress(int episodeId) => _dao.loadProgress(episodeId);

  Future<void> clearProgress(int episodeId) => _dao.clearProgress(episodeId);
}
