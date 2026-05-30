/// Shared cache configuration used by all DAOs.
abstract final class CacheConfig {
  /// How long a cached snapshot is considered fresh before a background
  /// network refresh is triggered.
  static const Duration ttl = Duration(hours: 2);
}
