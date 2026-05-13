import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../drama_detail/drama_detail_page.dart';

// ────────────────────────────────────────────────────────────────────────────
// Public entry-point widget
// ────────────────────────────────────────────────────────────────────────────

class DramaPlayerPage extends StatefulWidget {
  const DramaPlayerPage({
    super.key,
    required this.dramaId,
    required this.seriesTitle,
    this.startEpisodeNo = 1,
    this.totalEpisodes,
  });

  final int dramaId;
  final String seriesTitle;
  final int startEpisodeNo;
  final int? totalEpisodes;

  @override
  State<DramaPlayerPage> createState() => _DramaPlayerPageState();
}

class _DramaPlayerPageState extends State<DramaPlayerPage> {
  late final ApiClient _apiClient;
  PageController? _pageController;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};

  List<DramaEpisodeItem> _episodes = const <DramaEpisodeItem>[];
  bool _loading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    try {
      final response = await _apiClient
          .get<dynamic>(Endpoints.dramaEpisodes(widget.dramaId));
      final List<DramaEpisodeItem> episodes = _parseEpisodes(response.data);

      // Record a play view (24h dedup on backend)
      unawaited(_apiClient.post<dynamic>(
        Endpoints.dramaView(widget.dramaId),
        authenticated: true,
      ));

      int startIndex = 0;
      for (int i = 0; i < episodes.length; i++) {
        if (episodes[i].episodeNo == widget.startEpisodeNo) {
          startIndex = i;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _currentIndex = startIndex;
        _pageController = PageController(initialPage: startIndex);
        _loading = false;
      });

      if (episodes.isNotEmpty) {
        unawaited(_activateIndex(startIndex));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DramaEpisodeItem> _parseEpisodes(dynamic data) {
    List<dynamic> rows = const <dynamic>[];
    if (data is List) {
      rows = data;
    } else if (data is Map<String, dynamic>) {
      final dynamic r = data['results'] ?? data['episodes'];
      if (r is List) rows = r;
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_mapEpisode)
        .toList();
  }

  DramaEpisodeItem _mapEpisode(Map<String, dynamic> data) {
    final int? epNo = _parseInt(data['episode_no']) ??
        _parseInt(data['number']) ??
        _parseInt(data['order']);
    return DramaEpisodeItem(
      id: data['id']?.toString() ?? 'ep-${epNo ?? 0}',
      episodeNo: epNo,
      title: data['title'] as String? ?? 'Episode ${epNo ?? ''}',
      thumbnailUrl: data['thumbnail_url'] as String? ??
          data['cover_url'] as String?,
      canWatch: data['can_watch'] as bool? ?? false,
      isFree: data['is_free'] as bool? ?? false,
      isLocked: data['is_locked'] as bool? ?? false,
      pointsPrice: _parseInt(data['points_price']),
      creditsPrice: _parseInt(data['credits_price']),
      playableUrl: data['playback_url'] as String? ??
          data['video_url'] as String? ??
          data['hls_url'] as String? ??
          data['file_url'] as String?,
    );
  }

  int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _activateIndex(int index) async {
    _currentIndex = index;
    final DramaEpisodeItem ep = _episodes[index];
    final String? url = ep.playableUrl;

    if (ep.isLocked || url == null || url.isEmpty) {
      if (mounted) {
        setState(() {});
        if (ep.isLocked) _showUnlockSheet(index);
      }
      return;
    }

    if (!_controllers.containsKey(index)) {
      final VideoPlayerController c =
          VideoPlayerController.networkUrl(Uri.parse(url));
      _controllers[index] = c;
      await c.initialize();
      await c.setLooping(true);
    }
    await _controllers[index]?.play();
    await _disposeNonVisible(index);
    if (mounted) setState(() {});
  }

  Future<void> _disposeNonVisible(int visible) async {
    final List<int> stale =
        _controllers.keys.where((int k) => k != visible).toList();
    for (final int k in stale) {
      final VideoPlayerController? c = _controllers.remove(k);
      await c?.pause();
      await c?.dispose();
    }
  }

  Future<void> _togglePlayPause() async {
    final VideoPlayerController? c = _controllers[_currentIndex];
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  // After a successful unlock the API response has no playback_url.
  // Re-fetch the episode detail to get the real URL, then activate.
  Future<void> _reloadEpisodeAfterUnlock(int index) async {
    final DramaEpisodeItem ep = _episodes[index];
    final int? epNo = ep.episodeNo;
    if (epNo == null) return;
    try {
      final response = await _apiClient.get<dynamic>(
        Endpoints.dramaEpisodeDetail(widget.dramaId, epNo),
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is! Map<String, dynamic>) return;
      final String? url = data['playback_url'] as String? ??
          data['video_url'] as String? ??
          data['hls_url'] as String? ??
          data['file_url'] as String?;
      if (!mounted) return;
      setState(() {
        _episodes = List<DramaEpisodeItem>.from(_episodes)
          ..[index] = ep.copyWith(
            isLocked: false,
            canWatch: true,
            playableUrl: url,
          );
      });
    } catch (_) {
      // Best-effort: mark unlocked even without a fresh URL;
      // user can retry by re-entering the page.
      if (mounted) {
        setState(() {
          _episodes = List<DramaEpisodeItem>.from(_episodes)
            ..[index] = ep.copyWith(isLocked: false, canWatch: true);
        });
      }
    }
    _pageController?.jumpToPage(index);
    unawaited(_activateIndex(index));
  }

  void _showUnlockSheet(int index) {
    final DramaEpisodeItem ep = _episodes[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnlockSheet(
        episode: ep,
        dramaId: widget.dramaId,
        apiClient: _apiClient,
        onUnlocked: (_) => unawaited(_reloadEpisodeAfterUnlock(index)),
      ),
    );
  }

  void _jumpToEpisode(int index) {
    Navigator.of(context).pop();
    _pageController?.jumpToPage(index);
  }

  void _showEpisodeSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EpisodeSelectorSheet(
        episodes: _episodes,
        currentIndex: _currentIndex,
        seriesTitle: widget.seriesTitle,
        onSelect: _jumpToEpisode,
        onLockTap: (int index) {
          Navigator.of(context).pop();
          _showUnlockSheet(index);
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final VideoPlayerController c in _controllers.values) {
      c.pause();
      c.dispose();
    }
    _controllers.clear();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_episodes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Center(
                  child: Text('No episodes available.',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final DramaEpisodeItem current = _episodes[_currentIndex];
    final int epNo = current.episodeNo ?? widget.startEpisodeNo;
    final int total =
        widget.totalEpisodes ?? _episodes.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // ── Full-screen vertical episode PageView ──────────────────────
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _episodes.length,
            onPageChanged: (int i) => unawaited(_activateIndex(i)),
            itemBuilder: (BuildContext context, int i) {
              final DramaEpisodeItem ep = _episodes[i];

              if (ep.isLocked) {
                return _LockedEpisodeOverlay(
                  episode: ep,
                  onUnlock: () => _showUnlockSheet(i),
                );
              }

              final VideoPlayerController? c = _controllers[i];
              if (c == null || !c.value.isInitialized) {
                return const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Colors.white54, strokeWidth: 1.5),
                  ),
                );
              }
              return GestureDetector(
                onTap: _togglePlayPause,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              );
            },
          ),

          // ── Top overlay: back + episode label ─────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xAA000000), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'EP $epNo · ${widget.seriesTitle}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: <Shadow>[
                              Shadow(blurRadius: 6),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom bar: episodes selector trigger ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomEpisodeBar(
              currentEpNo: epNo,
              totalEpisodes: total,
              onTap: _showEpisodeSelector,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom episode bar (locked to bottom, tap → modal sheet)
// ---------------------------------------------------------------------------

class _BottomEpisodeBar extends StatelessWidget {
  const _BottomEpisodeBar({
    required this.currentEpNo,
    required this.totalEpisodes,
    required this.onTap,
  });

  final int currentEpNo;
  final int totalEpisodes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.grid_view_rounded,
                color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              'Episodes  ·  All $totalEpisodes  ·  Free to Watch',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modal bottom sheet with episode grid
// ---------------------------------------------------------------------------

class _EpisodeSelectorSheet extends StatefulWidget {
  const _EpisodeSelectorSheet({
    required this.episodes,
    required this.currentIndex,
    required this.seriesTitle,
    required this.onSelect,
    this.onLockTap,
  });

  final List<DramaEpisodeItem> episodes;
  final int currentIndex;
  final String seriesTitle;
  final void Function(int index) onSelect;
  final void Function(int index)? onLockTap;

  @override
  State<_EpisodeSelectorSheet> createState() =>
      _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends State<_EpisodeSelectorSheet> {
  // Pagination: show episodes in groups of 30
  static const int _pageSize = 30;
  late int _groupIndex;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.currentIndex ~/ _pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final int groupCount =
        (widget.episodes.length / _pageSize).ceil();
    final int start = _groupIndex * _pageSize;
    final int end =
        (start + _pageSize).clamp(0, widget.episodes.length);
    final List<DramaEpisodeItem> pageEpisodes =
        widget.episodes.sublist(start, end);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, ScrollController scroll) {
        return ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.warmBackground.withValues(alpha: 0.88),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
            children: <Widget>[
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header: title + episode count
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.seriesTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${widget.episodes.length} EP',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Group tabs (1–30 / 31–60 / …)
              if (groupCount > 1)
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: groupCount,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, int gi) {
                      final int s = gi * _pageSize + 1;
                      final int e = ((gi + 1) * _pageSize)
                          .clamp(0, widget.episodes.length);
                      final bool selected = gi == _groupIndex;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _groupIndex = gi),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white12,
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$s–$e',
                            style: TextStyle(
                              color: selected
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),

              // Episode grid
              Expanded(
                child: GridView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: pageEpisodes.length,
                  itemBuilder: (_, int i) {
                    final int globalIndex = start + i;
                    final DramaEpisodeItem ep = pageEpisodes[i];
                    final bool isCurrent =
                        globalIndex == widget.currentIndex;
                    final bool locked = ep.isLocked;

                    return GestureDetector(
                      onTap: locked
                          ? () => widget.onLockTap?.call(globalIndex)
                          : () => widget.onSelect(globalIndex),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.white
                              : locked
                                  ? Colors.white10
                                  : Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: locked
                            ? const Icon(Icons.lock_outline,
                                color: Colors.white54, size: 14)
                            : Text(
                                '${ep.episodeNo ?? (globalIndex + 1)}',
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Locked episode overlay (shown in PageView when episode is locked)
// ────────────────────────────────────────────────────────────────────────────

class _LockedEpisodeOverlay extends StatelessWidget {
  const _LockedEpisodeOverlay({
    required this.episode,
    required this.onUnlock,
  });

  final DramaEpisodeItem episode;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final int? points = episode.pointsPrice;
    final int? credits = episode.creditsPrice;
    final String priceLabel = credits != null && credits > 0
        ? '$credits Credits'
        : points != null && points > 0
            ? '$points Points'
            : 'Unlock';

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_rounded, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            Text(
              episode.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This episode requires unlocking',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text('Unlock · $priceLabel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: AppColors.warmBackground,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Unlock bottom sheet
// ────────────────────────────────────────────────────────────────────────────

class _UnlockSheet extends StatefulWidget {
  const _UnlockSheet({
    required this.episode,
    required this.dramaId,
    required this.apiClient,
    required this.onUnlocked,
  });

  final DramaEpisodeItem episode;
  final int dramaId;
  final ApiClient apiClient;
  final ValueChanged<Map<String, dynamic>> onUnlocked;

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  String _paymentMethod = 'meow_points';
  bool _unlocking = false;

  Future<void> _unlock() async {
    final int? episodeId = widget.episode.numericId;
    if (episodeId == null || _unlocking) return;
    setState(() => _unlocking = true);
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.dramaEpisodeUnlock(episodeId),
        data: <String, String>{'payment_method': _paymentMethod},
        authenticated: true,
      );
      final dynamic data = response.data;
      if (!mounted) return;
      Navigator.of(context).pop();
      if (data is Map<String, dynamic>) {
        widget.onUnlocked(data);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DramaEpisodeItem ep = widget.episode;
    final int? points = ep.pointsPrice;
    final int? credits = ep.creditsPrice;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.warmBackground.withValues(alpha: 0.82),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.lock_rounded, color: Colors.white54, size: 36),
          const SizedBox(height: 12),
          Text(
            ep.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose payment method to unlock',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              if (points != null && points > 0)
                Expanded(
                  child: _UnlockOption(
                    label: 'Meow Points',
                    price: '$points pts',
                    selected: _paymentMethod == 'meow_points',
                    onTap: () =>
                        setState(() => _paymentMethod = 'meow_points'),
                  ),
                ),
              if (points != null && points > 0 &&
                  credits != null && credits > 0)
                const SizedBox(width: 10),
              if (credits != null && credits > 0)
                Expanded(
                  child: _UnlockOption(
                    label: 'Meow Credits',
                    price: '$credits cr',
                    selected: _paymentMethod == 'meow_credit',
                    onTap: () =>
                        setState(() => _paymentMethod = 'meow_credit'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _unlocking ? null : _unlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: AppColors.warmBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _unlocking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Unlock Episode',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _UnlockOption extends StatelessWidget {
  const _UnlockOption({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGold
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.brandGold : Colors.white24,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.warmBackground : Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                color: selected
                    ? AppColors.warmBackground.withValues(alpha: 0.7)
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
