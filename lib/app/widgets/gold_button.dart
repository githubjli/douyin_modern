import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// GoldButton — solid gold primary action button
//
// Usage:
//   GoldButton(label: 'Submit', onTap: _submit)
//   GoldButton(label: 'Submitting...', onTap: null, loading: true)
// ---------------------------------------------------------------------------

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.46,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.brandGold,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black54,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.warmBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
