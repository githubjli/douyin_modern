import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/brand_page_header.dart';

class MembershipPage extends StatelessWidget {
  const MembershipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const BrandPageHeader(title: 'Membership'),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.brandGold, AppColors.deepGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Meow Plus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.inkDark)),
                SizedBox(height: AppSpacing.xs),
                Text('Unlock premium badges, perks, and exclusive rooms.', style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _PlanCard(title: 'Monthly', price: '¥5 / month', perks: 'Creator boosts, profile badge'),
          const SizedBox(height: AppSpacing.sm),
          const _PlanCard(title: 'Yearly', price: '¥50 / year', perks: 'Best value + seasonal gifts'),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.price, required this.perks});

  final String title;
  final String price;
  final String perks;

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(price, style: AppTextStyles.body.copyWith(color: AppColors.deepGold, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text(perks, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
