import '../../app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../drama_player/drama_player_page.dart';
import '../video_detail/video_detail_page.dart';
import '../home/domain/home_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// My Library page  — History / Liked / Purchased / Gifted / Received
// ─────────────────────────────────────────────────────────────────────────────

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  static const List<_LibTab> _tabs = <_LibTab>[
    _LibTab(label: 'History',   endpoint: Endpoints.libraryHistory),
    _LibTab(label: 'Liked',     endpoint: Endpoints.libraryLiked),
    _LibTab(label: 'Purchased', endpoint: Endpoints.libraryPurchased),
    _LibTab(label: 'Gifted',    endpoint: Endpoints.libraryGiftsSent),
    _LibTab(label: 'Received',  endpoint: Endpoints.libraryGiftsReceived),
  ];

  late final TabController _tabController;
  late final ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _apiClient = ApiClient();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          'Activity',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.brandGold,
          unselectedLabelColor: AppColors.cocoaText,
          indicatorColor: AppColors.brandGold,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          tabs: _tabs
              .map((t) => Tab(text: t.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((t) => _LibraryTabView(
                  tab: t,
                  apiClient: _apiClient,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab definition
// ─────────────────────────────────────────────────────────────────────────────

class _LibTab {
  const _LibTab({required this.label, required this.endpoint});
  final String label;
  final String endpoint;
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-tab scrollable list with infinite pagination
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryTabView extends StatefulWidget {
  const _LibraryTabView({required this.tab, required this.apiClient});
  final _LibTab tab;
  final ApiClient apiClient;

  @override
  State<_LibraryTabView> createState() => _LibraryTabViewState();
}

class _LibraryTabViewState extends State<_LibraryTabView>
    with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextUrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(widget.tab.endpoint);
  }

  Future<void> _load(String url) async {
    try {
      final response = await widget.apiClient
          .get<dynamic>(url, authenticated: true);
      final dynamic data = response.data;
      if (!mounted) return;
      final List<Map<String, dynamic>> rows = _parseRows(data);
      setState(() {
        _items.addAll(rows);
        _nextUrl = _parseNext(data);
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _loadMore() async {
    final String? next = _nextUrl;
    if (next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    await _load(next);
  }

  List<Map<String, dynamic>> _parseRows(dynamic data) {
    List<dynamic> rows = const <dynamic>[];
    if (data is List) {
      rows = data;
    } else if (data is Map<String, dynamic>) {
      final dynamic r = data['results'];
      if (r is List) rows = r;
    }
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  String? _parseNext(dynamic data) {
    if (data is Map<String, dynamic>) {
      final dynamic n = data['next'];
      if (n is String && n.isNotEmpty) return n;
    }
    return null;
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _nextUrl = null;
      _loading = true;
    });
    await _load(widget.tab.endpoint);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandGold),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'Nothing here yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.brandGold,
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length + (_nextUrl != null ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index == _items.length) {
            _loadMore();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.brandGold, strokeWidth: 2),
              ),
            );
          }
          final Map<String, dynamic> item = _items[index];
          return _buildCard(context, item);
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> item) {
    final String type = (item['type'] as String? ?? '').toLowerCase();

    switch (type) {
      case 'drama':
        return _DramaHistoryCard(item: item);
      case 'video':
        return _VideoCard(item: item, apiClient: widget.apiClient);
      case 'drama_episode':
        return _EpisodeCard(item: item);
      case 'order':
        return _OrderCard(item: item);
      case 'membership':
        return _MembershipCard(item: item);
      default:
        // Gift transactions (sent / received) or unknown
        if (item.containsKey('gift_name')) {
          return _GiftCard(item: item);
        }
        return _GenericCard(item: item);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DramaHistoryCard extends StatelessWidget {
  const _DramaHistoryCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final int? dramaId = _int(item['series_id']) ?? _int(item['id']);
    final int? episodeNo = _int(item['episode_no']);
    final String title = item['title'] as String? ?? 'Drama';
    final String? cover = item['cover_url'] as String?;
    final int progress = _int(item['progress_seconds']) ?? 0;
    final int duration = _int(item['duration_seconds']) ?? 0;
    final double pct = duration > 0 ? (progress / duration).clamp(0.0, 1.0) : 0;

    return _LibCard(
      imageUrl: cover,
      title: title,
      subtitle: episodeNo != null ? 'EP $episodeNo' : null,
      trailing: duration > 0
          ? Text(
              '${_fmtTime(progress)} / ${_fmtTime(duration)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            )
          : null,
      progressValue: pct,
      onTap: dramaId == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DramaPlayerPage(
                  dramaId: dramaId,
                  seriesTitle: title,
                  startEpisodeNo: episodeNo ?? 1,
                ),
              )),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.item, required this.apiClient});
  final Map<String, dynamic> item;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    final String title = item['title'] as String? ?? 'Video';
    final String? thumb = item['thumbnail_url'] as String?;
    final String? likedAt = item['liked_at'] as String?;
    final String? updatedAt = item['updated_at'] as String?;
    final String? date = likedAt ?? updatedAt;

    return _LibCard(
      imageUrl: thumb,
      title: title,
      subtitle: date != null ? _fmtDate(date) : null,
      icon: Icons.play_circle_outline,
      onTap: () {
        // Build a minimal HomeVideoItem to pass to VideoDetailPage
        final int? vid = _int(item['id']);
        if (vid == null) return;
        final HomeVideoItem video = HomeVideoItem(
          id: vid.toString(),
          title: title,
          subtitle: '',
          thumbnailUrl: thumb,
        );
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => VideoDetailPage(video: video, recommendations: const <HomeVideoItem>[]),
        ));
      },
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final int? dramaId = _int(item['series_id']);
    final String title = item['title'] as String? ?? 'Episode';
    final String? cover = item['cover_url'] as String?;
    final String method = _friendlyMethod(item['payment_method'] as String?);
    final String? date = item['purchased_at'] as String?;

    return _LibCard(
      imageUrl: cover,
      title: title,
      subtitle: method,
      trailing: date != null
          ? Text(_fmtDate(date),
              style: const TextStyle(color: Colors.white38, fontSize: 11))
          : null,
      icon: Icons.lock_open_rounded,
      onTap: dramaId == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DramaPlayerPage(
                  dramaId: dramaId,
                  seriesTitle: title,
                ),
              )),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final String title = item['title'] as String? ?? 'Order';
    final String amount = item['amount']?.toString() ?? '';
    final String currency = item['currency'] as String? ?? '';
    final String status = item['status'] as String? ?? '';
    final String? date = item['purchased_at'] as String?;

    return _LibCard(
      title: title,
      subtitle: status.isNotEmpty ? _capitalize(status) : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$amount $currency',
            style: const TextStyle(
                color: AppColors.brandGold,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          if (date != null)
            Text(_fmtDate(date),
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
      icon: Icons.receipt_outlined,
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final String title = item['title'] as String? ?? 'Membership';
    final String status = item['status'] as String? ?? '';
    final String? endsAt = item['ends_at'] as String?;

    return _LibCard(
      title: title,
      subtitle: status.isNotEmpty ? _capitalize(status) : null,
      trailing: endsAt != null
          ? Text(
              'Expires ${_fmtDate(endsAt)}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            )
          : null,
      icon: Icons.workspace_premium_outlined,
      iconColor: AppColors.brandGold,
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final String giftName = item['gift_name'] as String? ?? 'Gift';
    final double amount = _parseDecimal(item['amount']) ?? 0;
    final String? date = item['created_at'] as String?;

    // Sent: receiver, Received: sender
    final dynamic other = item['receiver'] ?? item['sender'];
    final String otherName = other is Map<String, dynamic>
        ? (other['name'] as String? ?? 'User')
        : 'User';
    final bool isSent = item['direction'] == 'sent';

    // Content context
    final dynamic content = item['content'];
    String? contentLabel;
    if (content is Map<String, dynamic>) {
      contentLabel = content['title'] as String?;
    }

    return _LibCard(
      title: '$giftName × ${amount == amount.truncateToDouble() ? amount.toInt() : amount.toStringAsFixed(2)}',
      subtitle: isSent ? 'To $otherName' : 'From $otherName',
      trailing: date != null
          ? Text(_fmtDate(date),
              style: const TextStyle(color: Colors.white38, fontSize: 11))
          : null,
      badge: contentLabel,
      icon: Icons.card_giftcard_outlined,
      iconColor: AppColors.brandGold,
    );
  }
}

class _GenericCard extends StatelessWidget {
  const _GenericCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final String title = (item['title'] ?? item['name'] ?? 'Item').toString();
    return _LibCard(title: title, icon: Icons.inventory_2_outlined);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card shell
// ─────────────────────────────────────────────────────────────────────────────

class _LibCard extends StatelessWidget {
  const _LibCard({
    required this.title,
    this.imageUrl,
    this.subtitle,
    this.trailing,
    this.badge,
    this.progressValue,
    this.icon,
    this.iconColor = Colors.white54,
    this.onTap,
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final Widget? trailing;
  final String? badge;
  final double? progressValue;
  final IconData? icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    // Thumbnail or icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: _thumb(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                          if (badge != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: AppColors.brandGold.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: AppColors.brandGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Trailing
                    if (trailing != null) ...<Widget>[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                    if (onTap != null) ...<Widget>[
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: Colors.white24, size: 18),
                    ],
                  ],
                ),
              ),
              // Progress bar
              if (progressValue != null && progressValue! > 0)
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandGold),
                  minHeight: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb() {
    final String? url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return AppCachedImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _iconBox(),
      );
    }
    return _iconBox();
  }

  Widget _iconBox() {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          icon ?? Icons.image_not_supported_outlined,
          color: iconColor,
          size: 28,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

double? _parseDecimal(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
  return null;
}

String _fmtTime(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _fmtDate(String iso) {
  try {
    final DateTime dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso.length > 10 ? iso.substring(0, 10) : iso;
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _friendlyMethod(String? method) {
  return switch (method) {
    'meow_points'  => 'Meow Points',
    'meow_credit'  => 'Meow Credits',
    'subscription' => 'Subscription',
    _              => method ?? 'Purchase',
  };
}
