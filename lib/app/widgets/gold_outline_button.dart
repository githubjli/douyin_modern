import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// GoldOutlineButton — gold-border secondary button with a leading icon
//
// Usage:
//   GoldOutlineButton(icon: Icons.share_outlined, label: 'Share QR', onTap: _share)
//   GoldOutlineButton(icon: Icons.download_rounded, label: 'Save', onTap: null)
// ---------------------------------------------------------------------------

class GoldOutlineButton extends StatelessWidget {
  const GoldOutlineButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.46 : 1.0,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warmBackground,
            border: Border.all(
                color: AppColors.brandGold.withValues(alpha: 0.46)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.brandGold),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.brandGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
