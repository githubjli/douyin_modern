import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/endpoints.dart';
import '../domain/creator_drama.dart';
import 'create_drama_page.dart';

class MyDramaPage extends StatefulWidget {
  const MyDramaPage({super.key});

  @override
  State<MyDramaPage> createState() => _MyDramaPageState();
}

class _MyDramaPageState extends State<MyDramaPage> {
  final ApiClient _apiClient = ApiClient();
  final List<CreatorDrama> _items = <CreatorDrama>[];
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _nextUrl;

  @override
  void initState() {
    super.initState();
    _load(Endpoints.creatorDramas);
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
      final response =
          await _apiClient.get<dynamic>(url, authenticated: true);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final results = data['results'];
        if (results is List) {
          _items.clear();
          _items.addAll(results
              .whereType<Map<String, dynamic>>()
              .map(CreatorDrama.fromJson));
        }
        _nextUrl = data['next'] as String?;
      }
    } on ApiError catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load dramas.';
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
                .map(CreatorDrama.fromJson));
          });
        }
        _nextUrl = data['next'] as String?;
      }
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() => _load(Endpoints.creatorDramas);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: const Text(
          'My Drama',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Create Drama',
            onPressed: () => Navigator.of(context)
                .push<bool?>(MaterialPageRoute<bool?>(
                  builder: (_) => const CreateDramaPage(),
                ))
                .then((created) {
              if (created == true) _refresh();
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
                  ? _EmptyView(onCreate: () {
                      Navigator.of(context)
                          .push<bool?>(MaterialPageRoute<bool?>(
                            builder: (_) => const CreateDramaPage(),
                          ))
                          .then((created) {
                        if (created == true) _refresh();
                      });
                    })
                  : RefreshIndicator(
                      color: AppColors.brandGold,
                      onRefresh: _refresh,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount:
                            _items.length + (_loadingMore ? 1 : 0),
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
                          return _DramaCard(drama: _items[index]);
                        },
                      ),
                    ),
    );
  }
}

class _DramaCard extends StatelessWidget {
  const _DramaCard({required this.drama});
  final CreatorDrama drama;

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, String statusLabel) =
        _statusStyle(drama.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Cover
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusMd),
              bottomLeft: Radius.circular(AppSpacing.radiusMd),
            ),
            child: SizedBox(
              width: 76,
              height: 100,
              child: drama.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: drama.coverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const _CoverPlaceholder(),
                    )
                  : const _CoverPlaceholder(),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          drama.title,
                          style: AppTextStyles.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _StatusBadge(label: statusLabel, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  if (drama.categoryName != null)
                    Text(drama.categoryName!, style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.video_library_outlined,
                          size: 12, color: AppColors.mutedOliveText),
                      const SizedBox(width: 3),
                      Text('${drama.totalEpisodes} eps',
                          style: AppTextStyles.caption),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.remove_red_eye_outlined,
                          size: 12, color: AppColors.mutedOliveText),
                      const SizedBox(width: 3),
                      Text(_fmt(drama.viewCount),
                          style: AppTextStyles.caption),
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

  static (Color, String) _statusStyle(String status) {
    return switch (status) {
      'published' => (Colors.green, 'Published'),
      'draft' => (Colors.orange, 'Draft'),
      _ => (AppColors.mutedOliveText, status),
    };
  }

  static String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.softBorder,
      child: const Center(
        child: Icon(Icons.menu_book_outlined,
            color: AppColors.mutedOliveText, size: 28),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
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
  const _EmptyView({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.menu_book_outlined,
                size: 48, color: AppColors.mutedOliveText),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No dramas yet',
              style: AppTextStyles.cardTitle
                  .copyWith(color: AppColors.mutedOliveText),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Create your first drama series to get started.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Create Drama'),
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
                style: AppTextStyles.body
                    .copyWith(color: AppColors.mutedOliveText),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
