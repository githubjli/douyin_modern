import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_assets.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
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
    'Home',
    'Videos',
    'Short Drama',
    'Live',
    'Shop',
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
          const _HomeTopRow(),
          const SizedBox(height: AppSpacing.md),
          _ChannelNav(channels: _channels),
          if (_notice != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_notice!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          _HeroCarousel(data: data),
          const SizedBox(height: AppSpacing.xs),
          const _HeroDots(),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Recommended for you today', hint: 'For you'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(items: data.recommended, kind: _CardKind.video),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Videos', hint: 'More'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(items: data.latestVideos, kind: _CardKind.video),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Short Drama', hint: 'More'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(items: data.shortDrama, kind: _CardKind.drama),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'Live', hint: 'More'),
          const SizedBox(height: AppSpacing.sm),
          data.liveNow.isEmpty
              ? const _LiveEmptyCard()
              : _SectionGrid(items: data.liveNow, kind: _CardKind.live),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(title: 'More', hint: 'Explore'),
          const SizedBox(height: AppSpacing.sm),
          _SectionGrid(items: data.featured, kind: _CardKind.video),
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

class _HomeTopRow extends StatelessWidget {
  const _HomeTopRow();
  @override
  Widget build(BuildContext context) {
    return Row(children: <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(AppAssets.meowLogo, width: 26, height: 26),
      ),
      const SizedBox(width: AppSpacing.sm),
      const Expanded(child: _SearchPill()),
      const SizedBox(width: AppSpacing.sm),
      const Icon(Icons.add_circle, color: AppColors.brandGold, size: 26),
    ]);
  }
}

class _ChannelNav extends StatelessWidget {
  const _ChannelNav({required this.channels});
  final List<String> channels;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, int i) => Text(
          channels[i],
          style: AppTextStyles.caption.copyWith(
              color: i == 0 ? AppColors.brandGold : AppColors.cocoaText),
        ),
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

String? _resolveImageUrl(dynamic item) {
  if (item is HomeVideoItem) {
    return item.thumbnailUrl;
  }
  if (item is HomeDramaItem) {
    return item.coverUrl ?? item.thumbnailUrl;
  }
  if (item is HomeLiveItem) {
    return item.thumbnailUrl;
  }
  return null;
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.items, required this.kind});

  final List<dynamic> items;
  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    final double ratio = switch (kind) {
      _CardKind.drama => 0.68,
      _ => 0.8,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: ratio * 0.75,
      ),
      itemBuilder: (_, int index) {
        final dynamic item = items[index];
        return _PortalCard(
          title: item.title as String,
          subtitle: item.subtitle as String,
          imageUrl: _resolveImageUrl(item),
          kind: kind,
        );
      },
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({required this.data});
  final HomePortalData data;
  @override
  Widget build(BuildContext context) {
    final List<dynamic> items = <dynamic>[...data.shortDrama.take(3), ...data.featured.take(2)];
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.isEmpty ? 1 : items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, int index) {
          final dynamic item = items.isEmpty ? null : items[index];
          final _CardKind kind = item is HomeDramaItem ? _CardKind.drama : _CardKind.video;
          return AspectRatio(
            aspectRatio: 1.6,
            child: _PortalCard(
              title: item?.title as String? ?? 'Featured Picks',
              subtitle: item?.subtitle as String? ?? 'Drama and video recommendations',
              imageUrl: _resolveImageUrl(item),
              kind: kind,
            ),
          );
        },
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        4,
        (int i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == 0 ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == 0 ? AppColors.brandGold : AppColors.softBorder,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
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
      _CardKind.featured => 'Video',
      _CardKind.video => 'Video',
      _CardKind.drama => 'Drama',
      _CardKind.live => 'LIVE',
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _CardCover(imageUrl: imageUrl, kind: kind),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x11000000),
                  Color(0x66000000),
                  Color(0xCC000000),
                ],
                stops: <double>[0.2, 0.6, 1],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: 2),
              decoration: BoxDecoration(
                color: kind == _CardKind.live
                    ? AppColors.brandGold
                    : AppColors.cardBackground.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.softBorder),
              ),
              child: Text(
                badge,
                style: AppTextStyles.caption.copyWith(
                  color: kind == _CardKind.live
                      ? AppColors.warmBackground
                      : AppColors.brandGold,
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCover extends StatelessWidget {
  const _CardCover({required this.imageUrl, required this.kind});

  final String? imageUrl;
  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    final String? trimmedUrl = imageUrl?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return _CardCoverPlaceholder(kind: kind);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Image.network(
        trimmedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _CardCoverPlaceholder(kind: kind),
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return _CardCoverPlaceholder(kind: kind);
        },
      ),
    );
  }
}

class _CardCoverPlaceholder extends StatelessWidget {
  const _CardCoverPlaceholder({required this.kind});

  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    final (_GradientSpec gradientSpec, IconData icon, String label, bool liveBadge) =
        switch (kind) {
      _CardKind.drama => (
          const _GradientSpec(Color(0xFF463522), Color(0xFF221A15)),
          Icons.theaters,
          'Drama',
          false
        ),
      _CardKind.live => (
          const _GradientSpec(Color(0xFF2E2419), Color(0xFF171514)),
          Icons.live_tv,
          'Live',
          true
        ),
      _ => (
          const _GradientSpec(Color(0xFF3B352A), Color(0xFF1F1E1D)),
          Icons.ondemand_video,
          'Video',
          false
        ),
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[gradientSpec.start, gradientSpec.end],
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (liveBadge)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandGold,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  'LIVE',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.warmBackground),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: AppColors.mutedOliveText, size: 30),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientSpec {
  const _GradientSpec(this.start, this.end);

  final Color start;
  final Color end;
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
