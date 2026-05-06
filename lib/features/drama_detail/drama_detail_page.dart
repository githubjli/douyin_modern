import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../home/domain/home_models.dart';

class DramaDetailPage extends StatefulWidget {
  const DramaDetailPage({
    super.key,
    required this.drama,
    this.repository,
  });

  final HomeDramaItem drama;
  final DramaDetailRepository? repository;

  @override
  State<DramaDetailPage> createState() => _DramaDetailPageState();
}

class _DramaDetailPageState extends State<DramaDetailPage> {
  late final DramaDetailRepository _repository;
  late Future<DramaDetailData> _future;
  int _tabIndex = 0;

  static const List<String> _tabs = <String>[
    'Episodes',
    'Free',
    'Locked',
    'Related',
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        RemoteDramaDetailRepository(apiClient: ApiClient());
    _future = _repository.getDramaDetail(widget.drama);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: const Text('Drama'),
      ),
      body: FutureBuilder<DramaDetailData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<DramaDetailData> snapshot) {
          final DramaDetailData data = snapshot.data ??
              DramaDetailData.fromHomeDrama(
                widget.drama,
                episodes: const <DramaEpisodeItem>[],
              );

          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                _DramaHero(data: data),
                const SizedBox(height: AppSpacing.md),
                _DramaTabs(
                  tabs: _tabs,
                  selectedIndex: _tabIndex,
                  onSelected: (int index) => setState(() => _tabIndex = index),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    data.episodes.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  _DramaEpisodeBody(
                    data: data,
                    tabIndex: _tabIndex,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

abstract class DramaDetailRepository {
  Future<DramaDetailData> getDramaDetail(HomeDramaItem selectedDrama);
}

class RemoteDramaDetailRepository implements DramaDetailRepository {
  RemoteDramaDetailRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<DramaDetailData> getDramaDetail(HomeDramaItem selectedDrama) async {
    final int? dramaId = int.tryParse(selectedDrama.id);
    Map<String, dynamic>? detail;
    List<dynamic> episodeRows = const <dynamic>[];

    if (dramaId != null) {
      try {
        final detailResponse =
            await _apiClient.get<dynamic>(Endpoints.dramaDetail(dramaId));
        detail = _readMap(detailResponse.data);
      } catch (_) {
        detail = null;
      }

      try {
        final episodeResponse =
            await _apiClient.get<dynamic>(Endpoints.dramaEpisodes(dramaId));
        episodeRows = _extractEpisodeRows(episodeResponse.data);
      } catch (_) {
        episodeRows = const <dynamic>[];
      }
    }

    final List<DramaEpisodeItem> episodes = episodeRows
        .whereType<Map<String, dynamic>>()
        .map(_mapEpisode)
        .toList();

    final DramaDetailData parsed = DramaDetailData.fromHomeDrama(
      selectedDrama,
      episodes: episodes.isEmpty
          ? MockDramaDetailRepository.mockEpisodes(selectedDrama)
          : episodes,
      detail: detail,
    );

    return parsed;
  }

  Map<String, dynamic>? _readMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  List<dynamic> _extractEpisodeRows(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      final dynamic episodes = data['episodes'];
      if (episodes is List<dynamic>) return episodes;
      final dynamic results = data['results'];
      if (results is List<dynamic>) return results;
    }
    return const <dynamic>[];
  }

  DramaEpisodeItem _mapEpisode(Map<String, dynamic> data) {
    final int? episodeNo = _readIntOrNull(data['episode_no']) ??
        _readIntOrNull(data['number']) ??
        _readIntOrNull(data['order']);
    return DramaEpisodeItem(
      id: _readString(data['id']) ?? 'episode-${episodeNo ?? 0}',
      episodeNo: episodeNo,
      title: _readString(data['title']) ?? 'Episode ${episodeNo ?? ''}'.trim(),
      thumbnailUrl: _readString(data['thumbnail_url']) ??
          _readString(data['cover_url']) ??
          _readString(data['preview_image_url']),
      canWatch: _readBool(data['can_watch']) ?? false,
      isFree: _readBool(data['is_free']) ?? false,
      isLocked: _readBool(data['is_locked']) ?? false,
      pointsPrice: _readIntOrNull(data['points_price']),
      playableUrl: _readString(data['playback_url']) ??
          _readString(data['video_url']) ??
          _readString(data['hls_url']) ??
          _readString(data['file_url']),
    );
  }

  String? _readString(dynamic value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  int? _readIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final String normalized = value.toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }
}

class MockDramaDetailRepository implements DramaDetailRepository {
  const MockDramaDetailRepository();

  @override
  Future<DramaDetailData> getDramaDetail(HomeDramaItem selectedDrama) async {
    return DramaDetailData.fromHomeDrama(
      selectedDrama,
      episodes: mockEpisodes(selectedDrama),
    );
  }

  static List<DramaEpisodeItem> mockEpisodes(HomeDramaItem drama) {
    return List<DramaEpisodeItem>.generate(9, (int index) {
      final int episodeNo = index + 1;
      final bool locked = episodeNo > 3;
      return DramaEpisodeItem(
        id: '${drama.id}-ep-$episodeNo',
        episodeNo: episodeNo,
        title: 'Episode $episodeNo',
        thumbnailUrl: drama.coverUrl ?? drama.thumbnailUrl,
        canWatch: !locked,
        isFree: !locked,
        isLocked: locked,
        pointsPrice: locked ? 2 : null,
        playableUrl: locked ? null : 'mock-drama-episode-$episodeNo',
      );
    });
  }
}

class DramaDetailData {
  const DramaDetailData({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.totalEpisodes,
    required this.freeEpisodes,
    required this.lockedEpisodes,
    required this.episodes,
  });

  factory DramaDetailData.fromHomeDrama(
    HomeDramaItem drama, {
    required List<DramaEpisodeItem> episodes,
    Map<String, dynamic>? detail,
  }) {
    final String? detailTitle = _readString(detail?['title']) ??
        _readString(detail?['name']);
    final String? detailDescription = _readString(detail?['description']) ??
        _readString(detail?['summary']) ??
        _readString(detail?['subtitle']);
    final String? detailCover = _readString(detail?['cover_url']) ??
        _readString(detail?['thumbnail_url']);
    final int freeCount = _readIntOrNull(detail?['free_episode_count']) ??
        episodes.where((DramaEpisodeItem e) => e.canWatch || e.isFree).length;
    final int lockedCount = _readIntOrNull(detail?['locked_episode_count']) ??
        episodes.where((DramaEpisodeItem e) => e.isLocked).length;

    return DramaDetailData(
      id: drama.id,
      title: detailTitle ?? drama.title,
      description: detailDescription ?? drama.subtitle,
      coverUrl: detailCover ?? drama.coverUrl ?? drama.thumbnailUrl,
      totalEpisodes: _readIntOrNull(detail?['total_episodes']) ??
          (episodes.isEmpty ? null : episodes.length),
      freeEpisodes: freeCount,
      lockedEpisodes: lockedCount,
      episodes: episodes,
    );
  }

  final String id;
  final String title;
  final String description;
  final String? coverUrl;
  final int? totalEpisodes;
  final int freeEpisodes;
  final int lockedEpisodes;
  final List<DramaEpisodeItem> episodes;

  static String? _readString(dynamic value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  static int? _readIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class DramaEpisodeItem {
  const DramaEpisodeItem({
    required this.id,
    required this.title,
    required this.canWatch,
    required this.isFree,
    required this.isLocked,
    this.episodeNo,
    this.thumbnailUrl,
    this.pointsPrice,
    this.playableUrl,
  });

  final String id;
  final int? episodeNo;
  final String title;
  final String? thumbnailUrl;
  final bool canWatch;
  final bool isFree;
  final bool isLocked;
  final int? pointsPrice;
  final String? playableUrl;
}

class _DramaHero extends StatelessWidget {
  const _DramaHero({required this.data});

  final DramaDetailData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _DramaCover(imageUrl: data.coverUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x16000000),
                    Color(0x66000000),
                    Color(0xD9000000),
                  ],
                  stops: <double>[0.2, 0.62, 1],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    data.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: <Widget>[
                      _MetaChip(label: '${data.totalEpisodes ?? 0} EP'),
                      _MetaChip(label: '${data.freeEpisodes} Free'),
                      _MetaChip(label: '${data.lockedEpisodes} Locked'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DramaTabs extends StatelessWidget {
  const _DramaTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, int index) {
          final bool selected = index == selectedIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(index),
            child: Center(
              child: Text(
                tabs[index],
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.brandGold : AppColors.cocoaText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DramaEpisodeBody extends StatelessWidget {
  const _DramaEpisodeBody({required this.data, required this.tabIndex});

  final DramaDetailData data;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final List<DramaEpisodeItem> episodes = switch (tabIndex) {
      1 => data.episodes
          .where((DramaEpisodeItem e) => e.canWatch || e.isFree)
          .toList(),
      2 => data.episodes.where((DramaEpisodeItem e) => e.isLocked).toList(),
      3 => const <DramaEpisodeItem>[],
      _ => data.episodes,
    };

    if (tabIndex == 3) {
      return const _DramaEmptyState(message: 'Related dramas coming soon.');
    }
    if (episodes.isEmpty) {
      return const _DramaEmptyState(message: 'No episodes available yet.');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.52,
      ),
      itemBuilder: (BuildContext context, int index) {
        return _DramaEpisodeCard(
          episode: episodes[index],
          fallbackCoverUrl: data.coverUrl,
        );
      },
    );
  }
}

class _DramaEpisodeCard extends StatelessWidget {
  const _DramaEpisodeCard({required this.episode, this.fallbackCoverUrl});

  final DramaEpisodeItem episode;
  final String? fallbackCoverUrl;

  @override
  Widget build(BuildContext context) {
    final bool playable =
        (episode.canWatch || episode.isFree) && !episode.isLocked;
    final String badge = episode.isLocked
        ? episode.pointsPrice == null
            ? 'Locked'
            : '${episode.pointsPrice} pts'
        : 'Free';

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              playable
                  ? 'Episode playback route coming soon.'
                  : 'Unlock/payment is not available yet.',
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _DramaCover(imageUrl: episode.thumbnailUrl ?? fallbackCoverUrl),
            if (episode.isLocked)
              Container(color: Colors.black.withValues(alpha: 0.35)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x05000000),
                    Color(0x55000000),
                    Color(0xC9000000),
                  ],
                  stops: <double>[0.2, 0.62, 1],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _MetaChip(label: badge, compact: true),
            ),
            if (episode.isLocked)
              const Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Icon(Icons.lock, color: Colors.white70, size: 16),
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
                    episode.episodeNo == null ? 'EP' : 'EP ${episode.episodeNo}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.brandGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DramaCover extends StatelessWidget {
  const _DramaCover({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? trimmedUrl = imageUrl?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return const _DramaCoverPlaceholder();
    }

    return Image.network(
      trimmedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => const _DramaCoverPlaceholder(),
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? loadingProgress,
      ) {
        if (loadingProgress == null) return child;
        return const _DramaCoverPlaceholder();
      },
    );
  }
}

class _DramaCoverPlaceholder extends StatelessWidget {
  const _DramaCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF463522), Color(0xFF221A15)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.theaters, color: AppColors.mutedOliveText, size: 32),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.brandGold,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DramaEmptyState extends StatelessWidget {
  const _DramaEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}
