import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/brand_page_header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<String> _channels = <String>[
    'Videos',
    'Short Drama',
    'Live',
    'Trending',
  ];

  static const List<_PortalCardData> _featured = <_PortalCardData>[
    _PortalCardData(title: 'Midnight Casebook', subtitle: 'Top drama this week'),
    _PortalCardData(title: 'City Live Report', subtitle: 'Breaking scenes now'),
  ];

  static const List<_PortalCardData> _latestVideos = <_PortalCardData>[
    _PortalCardData(title: 'Street Food Guide', subtitle: '12m • 48K views'),
    _PortalCardData(title: 'Morning Fitness', subtitle: '9m • 21K views'),
  ];

  static const List<_PortalCardData> _shortDrama = <_PortalCardData>[
    _PortalCardData(title: 'EP 12 • Crimson Oath', subtitle: 'Free • 3m'),
    _PortalCardData(title: 'EP 8 • Silent Signal', subtitle: '2 Points • 2m'),
  ];

  static const List<_PortalCardData> _liveNow = <_PortalCardData>[
    _PortalCardData(title: 'Finance Live Desk', subtitle: '1.2K watching'),
    _PortalCardData(title: 'Travel Street Cam', subtitle: '890 watching'),
  ];

  static const List<_PortalCardData> _recommended = <_PortalCardData>[
    _PortalCardData(title: 'Creator Spotlight', subtitle: 'Weekly editorial pick'),
    _PortalCardData(title: 'Weekend Watchlist', subtitle: 'Drama + video mix'),
    _PortalCardData(title: 'Local Trend Radar', subtitle: 'Top rising topics'),
    _PortalCardData(title: 'New Voices', subtitle: 'Fresh creators to follow'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const BrandPageHeader(title: 'Home'),
          // Home is a mixed-content portal (videos, shorts/drama, live, lists).
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
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Featured'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: _featured),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Latest Videos'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: _latestVideos),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Short Drama'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: _shortDrama),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Live Now'),
          const SizedBox(height: AppSpacing.sm),
          _HorizontalCards(items: _liveNow),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(title: 'Recommended'),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recommended.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (_, int index) {
              final _PortalCardData item = _recommended[index];
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
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
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
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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

  final List<_PortalCardData> items;

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
            child: _ContentCard(item: items[index]),
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
              maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(item.subtitle,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _PortalCardData {
  const _PortalCardData({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}
