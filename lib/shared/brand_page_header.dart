import 'package:flutter/material.dart';

import '../app/theme/app_assets.dart';
import '../app/theme/app_spacing.dart';
import '../app/theme/app_text_styles.dart';

class BrandPageHeader extends StatelessWidget {
  const BrandPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            AppAssets.meowLogo,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTextStyles.sectionTitle),
      ],
    );
  }
}
