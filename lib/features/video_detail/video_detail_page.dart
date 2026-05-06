import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../home/domain/home_models.dart';

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.video,
    this.recommendations = const <HomeVideoItem>[],
    this.apiClient,
    this.loadRemoteDetail = true,
  });

  final HomeVideoItem video;
  final List<HomeVideoItem> recommendations;
  final ApiClient? apiClient;
  final bool loadRemoteDetail;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late final ApiClient _apiClient;
  late HomeVideoItem _video;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _video = widget.video;
    if (widget.loadRemoteDetail) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loadingDetail = true;
    });

    try {
      final response = await _apiClient.get<dynamic>(_detailPath(widget.video.id));
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
            _VideoMediaHeader(video: _video),
            const SizedBox(height: AppSpacing.md),
            _VideoInfoSection(video: _video, loading: _loadingDetail),
            const SizedBox(height: AppSpacing.md),
            _VideoActionRow(onAction: _showActionPlaceholder),
            if (_video.description?.trim().isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _VideoDescription(description: _video.description!.trim()),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Text('Recommendations', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            if (recommendations.isEmpty)
              const _VideoDetailEmptyCard(message: 'No video recommendations yet.')
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
    subtitle: owner.isEmpty ? fallback.subtitle : '$owner · ${views ?? 0} views',
    thumbnailUrl: _str(data['thumbnail_url']) ?? fallback.thumbnailUrl,
    videoUrl: _str(data['video_url']) ??
        _str(data['playback_url']) ??
        _str(data['file_url']) ??
        fallback.videoUrl,
    description: _str(data['description']) ?? _str(data['summary']) ?? fallback.description,
    ownerName: owner.isEmpty ? fallback.ownerName : owner,
    viewCount: views,
    category: _str(data['category']) ?? fallback.category,
    categoryName: _str(data['category_name']) ?? fallback.categoryName,
    createdAt: _str(data['created_at']) ?? fallback.createdAt,
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

String _categoryLabel(HomeVideoItem video) {
  final String? label = video.categoryName?.trim().isNotEmpty == true
      ? video.categoryName!.trim()
      : video.category?.trim();
  return label == null || label.isEmpty ? 'Video' : label;
}

String _ownerLabel(HomeVideoItem video) {
  final String? owner = video.ownerName?.trim();
  return owner == null || owner.isEmpty ? 'Creator' : owner;
}

String _viewsLabel(HomeVideoItem video) {
  return '${video.viewCount ?? 0} views';
}

String _dateLabel(HomeVideoItem video) {
  final String? createdAt = video.createdAt?.trim();
  if (createdAt == null || createdAt.isEmpty) return 'Date unavailable';
  final DateTime? parsed = DateTime.tryParse(createdAt);
  if (parsed == null) return createdAt;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
}

class _VideoMediaHeader extends StatelessWidget {
  const _VideoMediaHeader({required this.video});

  final HomeVideoItem video;

  @override
  Widget build(BuildContext context) {
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
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.brandGold.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.warmBackground,
                  size: 38,
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Text(
                video.videoUrl?.trim().isNotEmpty == true
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
      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
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
        Row(
          children: <Widget>[
            _InfoBadge(label: _categoryLabel(video)),
            if (loading) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              const Text('Loading details...', style: AppTextStyles.caption),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(video.title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_ownerLabel(video)} · ${_viewsLabel(video)} · ${_dateLabel(video)}',
          style: AppTextStyles.caption,
        ),
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

class _VideoActionRow extends StatelessWidget {
  const _VideoActionRow({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _ActionButton(icon: Icons.favorite_border, label: 'Like', onTap: onAction),
        _ActionButton(icon: Icons.chat_bubble_outline, label: 'Comment', onTap: onAction),
        _ActionButton(icon: Icons.card_giftcard, label: 'Gift', onTap: onAction),
        _ActionButton(icon: Icons.ios_share, label: 'Share', onTap: onAction),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(label),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.softBorder),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: AppColors.brandGold, size: 18),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _VideoDescription extends StatelessWidget {
  const _VideoDescription({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(description, style: AppTextStyles.body),
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
