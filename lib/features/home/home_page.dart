import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../shared/brand_page_header.dart';
import 'data/mock_home_repository.dart';
import 'data/remote_home_repository.dart';
import 'domain/home_models.dart';
import 'domain/home_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.useRemote = true,
    this.remoteRepository,
    this.mockRepository = const MockHomeRepository(),
  });

  final bool useRemote;
  final HomeRepository? remoteRepository;
  final HomeRepository mockRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeRepository _remoteRepo;
  HomePortalData? _data;
  bool _loading = true;
  String? _notice;

  static const List<String> _channels = <String>[
    'Videos',
    'Short Drama',
    'Live',
    'Trending',
  ];

  @override
  void initState() {
    super.initState();
    _remoteRepo =
        widget.remoteRepository ?? RemoteHomeRepository(apiClient: ApiClient());
    _load();
  }

  Future<void> _load() async {
    HomePortalData? portal;
    if (widget.useRemote) {
      try {
        portal = await _remoteRepo.getHomePortalData();
        if (_isEmpty(portal)) {
          _notice = 'Showing local content.';
        }
      } catch (_) {
        _notice = 'Network unavailable. Showing local content.';
      }
    }

    portal ??= await widget.mockRepository.getHomePortalData();
    if (!mounted) return;
    setState(() {
      _data = portal;
      _loading = false;
    });
  }

  bool _isEmpty(HomePortalData p) =>
      p.latestVideos.isEmpty && p.shortDrama.isEmpty && p.liveNow.isEmpty;

  @override
  Widget build(BuildContext context) {
    final HomePortalData? data = _data;
    if (_loading || data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const BrandPageHeader(title: 'Home'),
          const SizedBox(height: AppSpacing.xs),
          const Text('Your mixed portal: videos, drama, live, and trends',
              style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          const _SearchPill(),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _channels.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (BuildContext context, int index) {
                final bool selected = index == 0;
                return _CategoryChip(label: _channels[index], selected: selected);
              },
            ),
          ),
          if (_notice != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_notice!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Featured', hint: 'Curated today'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: data.featured, kind: _CardKind.featured),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Latest Videos', hint: 'View all'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: data.latestVideos, kind: _CardKind.video),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Short Drama', hint: 'View all'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: data.shortDrama, kind: _CardKind.drama),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Live Now', hint: 'Live updates'),
          const SizedBox(height: AppSpacing.sm),
          data.liveNow.isEmpty
              ? const _LiveEmptyCard()
              : _HorizontalCards(items: data.liveNow, kind: _CardKind.live),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Recommended', hint: 'For you'),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.recommended.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.16,
            ),
            itemBuilder: (_, int index) {
              final HomeVideoItem recommendedItem = data.recommended[index];
              return _PortalCard(
                title: recommendedItem.title,
                subtitle: recommendedItem.subtitle,
                kind: _CardKind.video,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.search, color: AppColors.mutedOliveText),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Search videos, dramas, live topics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandGold : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Text(
        label,
        style: selected
            ? AppTextStyles.body.copyWith(color: AppColors.warmBackground)
            : AppTextStyles.caption,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
        Text(hint, style: AppTextStyles.caption),
      ],
    );
  }
}

enum _CardKind { featured, video, drama, live }

class _HorizontalCards extends StatelessWidget {
  const _HorizontalCards({required this.items, required this.kind});

  final List<dynamic> items;
  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, int index) {
          final dynamic item = items[index];
          return SizedBox(
            width: 230,
            child: _PortalCard(
              title: item.title as String,
              subtitle: item.subtitle as String,
              imageUrl: _resolveImageUrl(item),
              kind: kind,
            ),
          );
        },
      ),
    );
  }

  String? _resolveImageUrl(dynamic item) {
    if (item is HomeVideoItem) {
      return item.thumbnailUrl;
    }
    if (item is HomeDramaItem) {
      return item.coverUrl;
    }
    if (item is HomeLiveItem) {
      return item.thumbnailUrl;
    }
    return null;
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.title,
    required this.subtitle,
    required this.kind,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final _CardKind kind;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String badge = switch (kind) {
      _CardKind.featured => 'Featured',
      _CardKind.video => 'Video',
      _CardKind.drama => 'Drama',
      _CardKind.live => 'Live',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _CardCover(imageUrl: imageUrl)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badge,
            style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _CardCover extends StatelessWidget {
  const _CardCover({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? trimmedUrl = imageUrl?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return const _CardCoverPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Image.network(
        trimmedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const _CardCoverPlaceholder(),
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return const _CardCoverPlaceholder();
        },
      ),
    );
  }
}

class _CardCoverPlaceholder extends StatelessWidget {
  const _CardCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3B352A), Color(0xFF1F1E1D)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.ondemand_video, color: AppColors.mutedOliveText, size: 28),
      ),
    );
  }
}

class _LiveEmptyCard extends StatelessWidget {
  const _LiveEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: const Text('No live streams right now.', style: AppTextStyles.caption),
    );
  }
}
