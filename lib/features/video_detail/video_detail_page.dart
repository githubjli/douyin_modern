import 'package:flutter/material.dart';

import '../../app/theme/app_assets.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../home/domain/home_models.dart';

const TextStyle _videoDetailSectionHeadingStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.cocoaText,
);

const TextStyle _videoDetailMainTitleStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  height: 1.25,
  color: AppColors.cocoaText,
);

const TextStyle _videoDetailCreatorNameStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.cocoaText,
);

const TextStyle _videoDetailCreatorMetaStyle = TextStyle(
  fontSize: 11,
  color: AppColors.mutedOliveText,
);

const TextStyle _videoDetailCompactChipStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w500,
  color: AppColors.mutedOliveText,
);

const TextStyle _videoDetailFollowStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: AppColors.brandGold,
);

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.video,
    this.recommendations = const <HomeVideoItem>[],
    this.apiClient,
    this.loadRemoteDetail = true,
    this.signedInFuture,
  });

  final HomeVideoItem video;
  final List<HomeVideoItem> recommendations;
  final ApiClient? apiClient;
  final bool loadRemoteDetail;
  final Future<bool>? signedInFuture;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late final ApiClient _apiClient;
  late HomeVideoItem _video;
  bool _loadingDetail = false;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _video = widget.video;
    _loadSignedInState();
    if (widget.loadRemoteDetail) {
      _loadDetail();
    }
  }

  Future<void> _loadSignedInState() async {
    try {
      final bool isSignedIn = widget.signedInFuture != null
          ? await widget.signedInFuture!
          : await _hasAccessToken();
      if (!mounted) return;
      setState(() {
        _isSignedIn = isSignedIn;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSignedIn = false;
      });
    }
  }

  Future<bool> _hasAccessToken() async {
    final String? token = await TokenStorage().readAccessToken();
    return token?.trim().isNotEmpty == true;
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loadingDetail = true;
    });

    try {
      final response = await _apiClient.get<dynamic>(
        _detailPath(widget.video.id),
        authenticated: true,
      );
      final HomeVideoItem? detail = _mapDetail(response.data, widget.video);
      if (!mounted) return;
      setState(() {
        _video = detail ?? widget.video;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _video = widget.video;
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<HomeVideoItem> recommendations = _recommendations(
      current: _video,
      candidates: widget.recommendations,
    );

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            _VideoMediaHeader(video: _video, isSignedIn: _isSignedIn),
            const SizedBox(height: AppSpacing.sm),
            _VideoInfoSection(video: _video, loading: _loadingDetail),
            const SizedBox(height: AppSpacing.xs),
            _AuthorFollowRow(video: _video, onFollow: _showActionPlaceholder),
            const SizedBox(height: AppSpacing.xs),
            _VideoActionRow(onAction: _showActionPlaceholder),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Recommendations',
              style: _videoDetailSectionHeadingStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (recommendations.isEmpty)
              const _VideoDetailEmptyCard(
                message: 'No video recommendations yet.',
              )
            else
              _VideoRecommendationGrid(items: recommendations),
          ],
        ),
      ),
    );
  }

  void _showActionPlaceholder(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action coming soon.')),
    );
  }
}

String _detailPath(String id) {
  final int? numericId = int.tryParse(id);
  if (numericId != null) return Endpoints.publicVideoDetail(numericId);
  return '${Endpoints.publicVideos}${Uri.encodeComponent(id)}/';
}

HomeVideoItem? _mapDetail(dynamic data, HomeVideoItem fallback) {
  if (data is! Map<String, dynamic>) return null;
  final String title = _str(data['title']) ?? fallback.title;
  final String owner = _videoOwnerName(data) ?? fallback.ownerName ?? '';
  final int? views = _int(data['view_count']) ?? fallback.viewCount;
  return HomeVideoItem(
    id: _str(data['id']) ?? fallback.id,
    title: title,
    subtitle: owner.isEmpty
        ? fallback.subtitle
        : '$owner · ${views ?? 0} views',
    thumbnailUrl: _str(data['thumbnail_url']) ?? fallback.thumbnailUrl,
    videoUrl: _str(data['video_url']) ??
        _str(data['playback_url']) ??
        _str(data['file_url']) ??
        fallback.videoUrl,
    description: _str(data['description']) ??
        _str(data['summary']) ??
        fallback.description,
    ownerName: owner.isEmpty ? fallback.ownerName : owner,
    viewCount: views,
    category: _str(data['category']) ?? fallback.category,
    categoryName: _str(data['category_name']) ?? fallback.categoryName,
    createdAt: _str(data['created_at']) ?? fallback.createdAt,
    accessType: _str(data['access_type']) ?? fallback.accessType,
    previewSeconds: _int(data['preview_seconds']) ?? fallback.previewSeconds,
    canWatch: _bool(data['can_watch']) ?? fallback.canWatch,
    isLocked: _bool(data['is_locked']) ?? fallback.isLocked,
    lockReason: _str(data['lock_reason']) ?? fallback.lockReason,
  );
}

String? _videoOwnerName(Map<String, dynamic> data) {
  return _str(data['owner_name']) ??
      _nestedStr(data['owner'], 'username') ??
      _nestedStr(data['owner'], 'email') ??
      _nestedStr(data['creator'], 'name');
}

String? _nestedStr(dynamic value, String key) {
  if (value is Map<String, dynamic>) return _str(value[key]);
  return null;
}

String? _str(dynamic value) {
  if (value is String) return value;
  if (value is num) return value.toString();
  return null;
}

bool? _bool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final String normalized = value.toLowerCase().trim();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

List<HomeVideoItem> _recommendations({
  required HomeVideoItem current,
  required List<HomeVideoItem> candidates,
}) {
  final String? currentCategory = _categoryKey(current);
  final List<HomeVideoItem> sameCategory = candidates
      .where((HomeVideoItem item) => item.id != current.id)
      .where((HomeVideoItem item) => _categoryKey(item) == currentCategory)
      .toList();
  final List<HomeVideoItem> otherVideos = candidates
      .where((HomeVideoItem item) => item.id != current.id)
      .where((HomeVideoItem item) => !sameCategory.any(
            (HomeVideoItem same) => same.id == item.id,
          ))
      .toList();
  return <HomeVideoItem>[...sameCategory, ...otherVideos].take(12).toList();
}

String? _categoryKey(HomeVideoItem video) {
  final String? category = video.categoryName ?? video.category;
  final String? trimmed = category?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.toLowerCase();
}

String _ownerLabel(HomeVideoItem video) {
  final String? owner = video.ownerName?.trim();
  return owner == null || owner.isEmpty ? 'Creator' : owner;
}

String _viewsLabel(HomeVideoItem video) {
  return '${video.viewCount ?? 0} views';
}

class _VideoMediaHeader extends StatelessWidget {
  const _VideoMediaHeader({required this.video, required this.isSignedIn});

  final HomeVideoItem video;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    final bool lockedVip = _isLockedVip(video);
    final bool canPreviewPlayback = _canPreviewPlayback(video);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _VideoDetailCover(imageUrl: video.thumbnailUrl),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x66000000), Color(0x22000000)],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: _CircleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            if (lockedVip)
              _LockedVipOverlay(
                ctaLabel: isSignedIn ? 'Subscribe' : 'Sign in',
                onCta: () => _showLockedVipPlaceholder(context, isSignedIn),
              )
            else
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: canPreviewPlayback
                        ? AppColors.brandGold.withValues(alpha: 0.92)
                        : AppColors.cardBackground.withValues(alpha: 0.84),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    canPreviewPlayback
                        ? Icons.play_arrow_rounded
                        : Icons.image_outlined,
                    color: canPreviewPlayback
                        ? AppColors.warmBackground
                        : AppColors.brandGold,
                    size: canPreviewPlayback ? 38 : 30,
                  ),
                ),
              ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Text(
                lockedVip
                    ? 'VIP locked'
                    : canPreviewPlayback
                        ? 'Playback preview'
                        : 'Thumbnail preview',
                style: AppTextStyles.caption.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isLockedVip(HomeVideoItem video) {
  return video.isMembershipVideo &&
      (video.canWatch == false || video.isLocked == true);
}

bool _canPreviewPlayback(HomeVideoItem video) {
  final bool hasVideoUrl = video.videoUrl?.trim().isNotEmpty == true;
  if (!hasVideoUrl || video.canWatch == false || video.isLocked == true) {
    return false;
  }
  if (video.isMembershipVideo) return video.canWatch == true;
  return true;
}

void _showLockedVipPlaceholder(BuildContext context, bool isSignedIn) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isSignedIn
            ? 'Subscribe to unlock this VIP video.'
            : 'Sign in to watch VIP videos.',
      ),
    ),
  );
}

class _LockedVipOverlay extends StatelessWidget {
  const _LockedVipOverlay({required this.ctaLabel, required this.onCta});

  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          border: Border.all(
            color: AppColors.brandGold.withValues(alpha: 0.55),
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_outline,
              color: AppColors.brandGold,
              size: 30,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'VIP video locked',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Colors.white,
                fontSize: 15,
                height: 1.15,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Unlock this member-only video to keep watching.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: AppColors.warmBackground,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoDetailCover extends StatelessWidget {
  const _VideoDetailCover({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return const _VideoPlaceholder();
    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _VideoPlaceholder(),
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) return child;
        return const _VideoPlaceholder();
      },
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3B352A), Color(0xFF1F1E1D)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.ondemand_video,
          color: AppColors.mutedOliveText,
          size: 42,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Icon(icon, color: AppColors.cocoaText, size: 20),
      ),
    );
  }
}

class _VideoInfoSection extends StatelessWidget {
  const _VideoInfoSection({required this.video, required this.loading});

  final HomeVideoItem video;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _videoDetailMainTitleStyle,
        ),
        if (loading) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          const Text('Loading details...', style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
      ),
    );
  }
}

class _AuthorFollowRow extends StatelessWidget {
  const _AuthorFollowRow({required this.video, required this.onFollow});

  final HomeVideoItem video;
  final ValueChanged<String> onFollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Image.asset(
            AppAssets.meowLogo,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _ownerLabel(video),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _videoDetailCreatorNameStyle,
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                'Creator · Public video',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _videoDetailCreatorMetaStyle,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _FollowButton(onTap: () => onFollow('Follow')),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brandGold,
        side: const BorderSide(color: AppColors.brandGold),
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        visualDensity: VisualDensity.compact,
        textStyle: _videoDetailFollowStyle,
      ),
      child: const Text('Follow'),
    );
  }
}

class _VideoActionRow extends StatelessWidget {
  const _VideoActionRow({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        _ActionButton(
          icon: Icons.favorite_border,
          label: '25k',
          action: 'Like',
          onTap: onAction,
        ),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: '2.1k',
          action: 'Comment',
          onTap: onAction,
        ),
        _ActionButton(
          icon: Icons.card_giftcard,
          label: '73',
          action: 'Gift',
          onTap: onAction,
        ),
        _ActionButton(
          icon: Icons.ios_share,
          label: 'Share',
          action: 'Share',
          onTap: onAction,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String action;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onTap(action),
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mutedOliveText,
        side: const BorderSide(color: AppColors.softBorder),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        visualDensity: VisualDensity.compact,
        textStyle: _videoDetailCompactChipStyle,
      ),
    );
  }
}

class _VideoRecommendationGrid extends StatelessWidget {
  const _VideoRecommendationGrid({required this.items});

  final List<HomeVideoItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.6,
      ),
      itemBuilder: (_, int index) {
        final HomeVideoItem item = items[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => VideoDetailPage(
                  video: item,
                  recommendations: items,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _VideoDetailCover(imageUrl: item.thumbnailUrl),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x0D000000),
                        Color(0x55000000),
                        Color(0xB3000000),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: AppSpacing.xs,
                  left: AppSpacing.xs,
                  child: _InfoBadge(label: 'Video'),
                ),
                Positioned(
                  left: AppSpacing.xs,
                  right: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${_ownerLabel(item)} · ${_viewsLabel(item)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoDetailEmptyCard extends StatelessWidget {
  const _VideoDetailEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}
