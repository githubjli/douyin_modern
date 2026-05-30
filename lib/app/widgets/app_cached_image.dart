import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/network/image_cache_manager.dart';

/// Drop-in replacement for [CachedNetworkImage] that enforces the app-wide
/// cache policy (size limit, staleness period) via [AppImageCacheManager].
///
/// All image loading in this app should go through this widget so that
/// cache constraints defined in [CacheConfig] are always respected.
class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: AppImageCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
