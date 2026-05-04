import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/brand_page_header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<String> _channels = <String>[
    'For You',
    'Cats',
    'Lifestyle',
    'News',
    'Creators'
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const BrandPageHeader(title: 'Home'),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.softBorder),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.search, color: AppColors.mutedOliveText),
                SizedBox(width: AppSpacing.sm),
                Text('Search creators, shows, topics',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _channels.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (BuildContext context, int index) {
                final bool selected = index == 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandGold
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: Text(
                    _channels[index],
                    style: selected
                        ? AppTextStyles.body.copyWith(color: AppColors.inkDark)
                        : AppTextStyles.caption,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.softBorder),
            ),
            child: const Center(
              child: Text('Home Hero / Banner', style: AppTextStyles.cardTitle),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Recommended', style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (_, int index) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.softBorder),
                ),
                child: Center(
                  child: Text('Card ${index + 1}', style: AppTextStyles.body),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
