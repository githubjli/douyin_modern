import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/endpoints.dart';
import '../domain/creator_live_stream.dart';

class MyLiveStreamsPage extends StatefulWidget {
  const MyLiveStreamsPage({super.key});

  @override
  State<MyLiveStreamsPage> createState() => _MyLiveStreamsPageState();
}

class _MyLiveStreamsPageState extends State<MyLiveStreamsPage> {
  final ApiClient _apiClient = ApiClient();
  final List<CreatorLiveStream> _items = <CreatorLiveStream>[];
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _nextUrl;

  @override
  void initState() {
    super.initState();
    _load(Endpoints.creatorLiveStreams);
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
              .map(CreatorLiveStream.fromJson));
        }
        _nextUrl = data['next'] as String?;
      }
    } on ApiError catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load live streams.';
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
                .map(CreatorLiveStream.fromJson));
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

  Future<void> _refresh() => _load(Endpoints.creatorLiveStreams);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: const Text(
          'My Live Streams',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandGold))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _refresh)
              : _items.isEmpty
                  ? const _EmptyView()
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
                          return _LiveStreamCard(stream: _items[index]);
                        },
                      ),
                    ),
    );
  }
}

class _LiveStreamCard extends StatelessWidget {
  const _LiveStreamCard({required this.stream});
  final CreatorLiveStream stream;

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, String statusLabel) =
        _statusStyle(stream.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  stream.title,
                  style: AppTextStyles.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              const Icon(Icons.remove_red_eye_outlined,
                  size: 13, color: AppColors.mutedOliveText),
              const SizedBox(width: 4),
              Text(
                '${stream.viewerCount} viewers',
                style: AppTextStyles.caption,
              ),
              if (stream.categoryName != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.category_outlined,
                    size: 13, color: AppColors.mutedOliveText),
                const SizedBox(width: 4),
                Text(stream.categoryName!, style: AppTextStyles.caption),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _formatDate(stream.startedAt ?? stream.createdAt),
            style: AppTextStyles.caption
                .copyWith(color: AppColors.mutedOliveText),
          ),
        ],
      ),
    );
  }

  static (Color, String) _statusStyle(String status) {
    return switch (status) {
      'live' => (Colors.redAccent, 'LIVE'),
      'ended' => (AppColors.mutedOliveText, 'Ended'),
      _ => (Colors.orange, 'Idle'),
    };
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.live_tv_outlined,
                size: 48, color: AppColors.mutedOliveText),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No live streams yet',
              style: AppTextStyles.cardTitle
                  .copyWith(color: AppColors.mutedOliveText),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your past live streams will appear here.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
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
