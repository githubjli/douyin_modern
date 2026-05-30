import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../database/cache_config.dart';

/// App-wide image cache manager with controlled size limits.
///
/// Used by every [CachedNetworkImage] widget so that all image caching
/// respects a single set of constraints defined in [CacheConfig].
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  AppImageCacheManager._()
      : super(
          Config(
            _key,
            maxNrOfCacheObjects: CacheConfig.imageCacheMaxObjects,
            stalePeriod: CacheConfig.imageCacheStalePeriod,
          ),
        );

  static const String _key = 'meow_media_image_cache';

  static final AppImageCacheManager instance = AppImageCacheManager._();
}
