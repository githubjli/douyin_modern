/// Shared cache configuration used by all DAOs and cache managers.
abstract final class CacheConfig {
  /// How long a cached snapshot is considered fresh before a background
  /// network refresh is triggered.
  static const Duration ttl = Duration(hours: 2);

  /// Maximum rows kept in feed_progress_table. When exceeded, the oldest
  /// entries (by savedAt) are deleted to stay within this limit.
  static const int maxProgressRows = 500;

  /// How long image cache entries are retained on disk.
  static const Duration imageCacheStalePeriod = Duration(days: 7);

  /// Maximum number of image objects in the disk cache.
  static const int imageCacheMaxObjects = 300;
}
