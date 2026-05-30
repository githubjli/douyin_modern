import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/endpoints.dart';
import '../domain/creator_video.dart';
import 'edit_video_page.dart';
import 'upload_video_page.dart';

class MyVideosPage extends StatefulWidget {
  const MyVideosPage({super.key});

  @override
  State<MyVideosPage> createState() => _MyVideosPageState();
}

class _MyVideosPageState extends State<MyVideosPage> {
  final ApiClient _apiClient = ApiClient();
  final List<CreatorVideo> _items = <CreatorVideo>[];
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _nextUrl;

  @override
  void initState() {
    super.initState();
    _load(Endpoints.creatorVideos);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _nextUrl != null) {
      _loadMore();
    }
  }

  Future<void> _load(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get<dynamic>(
        url,
        authenticated: true,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final results = data['results'];
        if (results is List) {
          _items.clear();
          _items.addAll(results
              .whereType<Map<String, dynamic>>()
              .map(CreatorVideo.fromJson));
        }
        _nextUrl = data['next'] as String?;
      }
    } on ApiError catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load videos.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final url = _nextUrl;
    if (url == null) return;
    setState(() => _loadingMore = true);
    try {
      final response = await _apiClient.get<dynamic>(url, authenticated: true);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final results = data['results'];
        if (results is List) {
          setState(() {
            _items.addAll(results
                .whereType<Map<String, dynamic>>()
                .map(CreatorVideo.fromJson));
          });
        }
        _nextUrl = data['next'] as String?;
      }
    } catch (_) {
      // silent — user can scroll up and retry
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() => _load(Endpoints.creatorVideos);

  Future<void> _openEdit(CreatorVideo video) async {
    final bool? saved = await Navigator.of(context)
        .push<bool?>(MaterialPageRoute<bool?>(
          builder: (_) => EditVideoPage(video: video),
        ));
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: const Text(
          'My Videos',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            tooltip: 'Upload Video',
            onPressed: () => Navigator.of(context)
                .push<bool?>(MaterialPageRoute<bool?>(
                  builder: (_) => const UploadVideoPage(),
                ))
                .then((uploaded) {
              if (uploaded == true) _refresh();
            }),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandGold))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _refresh)
              : _items.isEmpty
                  ? _EmptyView(onUpload: () {
                      Navigator.of(context)
                          .push<bool?>(MaterialPageRoute<bool?>(
                            builder: (_) => const UploadVideoPage(),
                          ))
                          .then((uploaded) {
                        if (uploaded == true) _refresh();
                      });
                    })
                  : RefreshIndicator(
                      color: AppColors.brandGold,
                      onRefresh: _refresh,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.md),
                                child: CircularProgressIndicator(
                                    color: AppColors.brandGold),
                              ),
                            );
                          }
                          return _VideoCard(
                            video: _items[index],
                            onEdit: () => _openEdit(_items[index]),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onEdit});
  final CreatorVideo video;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusMd),
              bottomLeft: Radius.circular(AppSpacing.radiusMd),
            ),
            child: SizedBox(
              width: 100,
              height: 72,
              child: video.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _ThumbnailPlaceholder(),
                    )
                  : const _ThumbnailPlaceholder(),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          video.title,
                          style: AppTextStyles.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onEdit,
                        child: const Padding(
                          padding: EdgeInsets.only(left: AppSpacing.xs),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.mutedOliveText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: <Widget>[
                      _Badge(
                        label: _visibilityLabel(video.visibility),
                        color: video.visibility == 'public'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      if (video.accessType != null)
                        _Badge(
                          label: _accessLabel(video.accessType!),
                          color: AppColors.brandGold,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 2,
                    children: <Widget>[
                      _StatItem(icon: Icons.remove_red_eye_outlined,
                          value: _fmt(video.viewCount)),
                      _StatItem(icon: Icons.favorite_border_rounded,
                          value: _fmt(video.likeCount)),
                      _StatItem(icon: Icons.chat_bubble_outline,
                          value: _fmt(video.commentCount)),
                      _StatItem(icon: Icons.card_giftcard_outlined,
                          value: _fmt(video.giftCount)),
                      _StatItem(icon: Icons.ios_share,
                          value: _fmt(video.shareCount)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  static String _visibilityLabel(String v) {
    switch (v.toLowerCase()) {
      case 'public':   return 'Public';
      case 'private':  return 'Private';
      case 'unlisted': return 'Unlisted';
      default:         return v;
    }
  }

  static String _accessLabel(String v) {
    switch (v.toLowerCase()) {
      case 'membership': return 'VIP';
      case 'free':       return 'Free';
      default:           return v;
    }
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.softBorder,
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: AppColors.mutedOliveText, size: 28),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: AppColors.mutedOliveText),
        const SizedBox(width: 3),
        Text(value, style: AppTextStyles.caption),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onUpload});
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.videocam_off_outlined,
                size: 48, color: AppColors.mutedOliveText),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No videos yet',
              style: AppTextStyles.cardTitle
                  .copyWith(color: AppColors.mutedOliveText),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Upload your first video to get started.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: const Text('Upload Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message,
                style: AppTextStyles.body.copyWith(color: AppColors.mutedOliveText),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
