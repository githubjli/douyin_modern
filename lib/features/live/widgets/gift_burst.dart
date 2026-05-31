import '../../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';

class PendingGift {
  PendingGift({
    required this.id,
    required this.emoji,
    required this.senderName,
    required this.label,
    this.iconUrl,
    this.animationUrl,
    this.animationType,
  });
  final int id;
  final String emoji;
  final String senderName;
  final String label;
  final String? iconUrl;
  final String? animationUrl;
  final String? animationType;

  bool get hasLottie {
    final url = animationUrl;
    if (url == null || url.isEmpty) return false;
    // Accept explicit animation_type or detect by .json extension.
    return animationType == 'lottie' || url.toLowerCase().endsWith('.json');
  }
}

/// Resolves a relative gift asset URL to an absolute URL using the API base.
String? resolveGiftUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final String base = ApiClient.defaultBaseUrl.endsWith('/')
      ? ApiClient.defaultBaseUrl
            .substring(0, ApiClient.defaultBaseUrl.length - 1)
      : ApiClient.defaultBaseUrl;
  return '$base${raw.startsWith('/') ? raw : '/$raw'}';
}

/// Shared gift catalog entry — used by both GoLivePage and LiveWatchPage.
class LiveGiftCatalogEntry {
  const LiveGiftCatalogEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.emoji,
    required this.coinCost,
    required this.isActive,
    required this.sortOrder,
    this.iconUrl,
    this.animationUrl,
    this.animationType,
  });

  final int id;
  final String code;
  final String name;
  final String emoji;
  final int coinCost;
  final bool isActive;
  final int sortOrder;
  final String? iconUrl;
  final String? animationUrl;
  final String? animationType;

  bool get hasLottie {
    final url = animationUrl;
    if (url == null || url.isEmpty) return false;
    return animationType == 'lottie' || url.toLowerCase().endsWith('.json');
  }

  factory LiveGiftCatalogEntry.fromJson(Map<String, dynamic> json) {
    return LiveGiftCatalogEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: (json['display_name'] ?? json['name'])?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🎁',
      coinCost: (json['coin_cost'] as num?)?.toInt() ??
          (json['price'] as num?)?.toInt() ??
          (json['points_price'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      iconUrl: resolveGiftUrl(json['icon_url']?.toString()),
      animationUrl: resolveGiftUrl(json['animation_url']?.toString()),
      animationType: json['animation_type']?.toString(),
    );
  }
}

/// Returns the emoji for a gift based on the chat message payload or name.
String giftEmojiFromPayload(Map<String, dynamic> payload) {
  final name = (payload['gift_name'] ?? payload['name'] ?? '').toString().toLowerCase();
  return switch (name) {
    'rose'    => '🌹',
    'star'    => '⭐',
    'crown'   => '👑',
    'diamond' => '💎',
    _         => '🎁',
  };
}

/// Floating gift animation card. Self-contained — manages its own controller.
/// Parent just adds/removes [PendingGift] from a list; [onDone] signals removal.
class GiftBurst extends StatefulWidget {
  const GiftBurst({
    super.key,
    required this.emoji,
    required this.senderName,
    required this.label,
    required this.onDone,
    this.iconUrl,
    this.animationUrl,
    this.animationType,
  });

  final String emoji;
  final String senderName;
  final String label;
  final VoidCallback onDone;
  final String? iconUrl;
  final String? animationUrl;
  final String? animationType;

  bool get hasLottie {
    final url = animationUrl;
    if (url == null || url.isEmpty) return false;
    // Accept explicit animation_type or detect by .json extension.
    return animationType == 'lottie' || url.toLowerCase().endsWith('.json');
  }

  @override
  State<GiftBurst> createState() => _GiftBurstState();
}

class _GiftBurstState extends State<GiftBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 56),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 32),
    ]).animate(_ctrl);

    _translateY = Tween<double>(begin: 0, end: -110).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildIcon() {
    // Lottie animation (highest priority)
    if (widget.hasLottie) {
      return Lottie.network(
        widget.animationUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (_, err, __) {
          assert(() {
            // ignore: avoid_print
            print('[GiftBurst] Lottie error for ${widget.animationUrl}: $err');
            return true;
          }());
          return _buildIconFallback();
        },
        onWarning: (msg) {
          assert(() {
            // ignore: avoid_print
            print('[GiftBurst] Lottie warning: $msg');
            return true;
          }());
        },
      );
    }
    // Static icon image
    if (widget.iconUrl != null && widget.iconUrl!.isNotEmpty) {
      return AppCachedImage(
        imageUrl: widget.iconUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _buildIconFallback(),
      );
    }
    return _buildIconFallback();
  }

  Widget _buildIconFallback() {
    return Text(widget.emoji, style: const TextStyle(fontSize: 32));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _translateY.value),
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xDD000000), Color(0x99000000)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.brandGold.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.senderName,
                      style: const TextStyle(
                        color: AppColors.brandGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
