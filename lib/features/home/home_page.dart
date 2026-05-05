import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/brand_page_header.dart';
import 'data/mock_home_repository.dart';
import 'data/remote_home_repository.dart';
import 'domain/home_models.dart';
import 'domain/home_repository.dart';
import '../../core/network/api_client.dart';

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
    _remoteRepo = widget.remoteRepository ?? RemoteHomeRepository(apiClient: ApiClient());
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
          const _SectionTitle(title: 'Featured'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: data.featured),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Latest Videos'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: data.latestVideos),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Short Drama'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: data.shortDrama),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Live Now'),
          const SizedBox(height: AppSpacing.sm),
          data.liveNow.isEmpty
              ? const _EmptyCard(label: 'No live streams right now')
              : _HorizontalCards(items: data.liveNow),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Recommended'),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.recommended.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (_, int index) {
              final _PortalCardData item = _PortalCardData(
                title: data.recommended[index].title,
                subtitle: data.recommended[index].subtitle,
              );
              return _ContentCard(item: item);
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.cardTitle);
  }
}

class _HorizontalCards extends StatelessWidget {
  const _HorizontalCards({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, int index) {
          return SizedBox(
            width: 210,
            child: _ContentCard(
              item: _PortalCardData(
                title: items[index].title as String,
                subtitle: items[index].subtitle as String,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item});

  final _PortalCardData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(item: _PortalCardData(title: 'Live Now', subtitle: label));
  }
}

class _PortalCardData {
  const _PortalCardData({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}
