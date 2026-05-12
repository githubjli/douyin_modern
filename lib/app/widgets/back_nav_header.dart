import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// BackNavHeader — sub-page navigation header
//
// Use this on every page that can be popped (has a back / close button).
// Matches the style of ManualPaymentPage and all Meow Credit pages:
//   • 32×32 circular button — semi-transparent bg, gold border, gold icon
//   • Title: sectionTitle, fontSize 18, height 1.1
//
// Do NOT confuse with BrandPageHeader (lib/shared/) which shows the Meow
// logo and is reserved for top-level tab pages (Profile, Membership, etc.).
//
// Usage:
//   const BackNavHeader(title: 'My Page')
//   BackNavHeader(title: 'My Page', onBack: () => Navigator.of(context).pop())
//   BackNavHeader(title: 'Done', icon: Icons.close_rounded,
//                 onBack: () => Navigator.of(context).popUntil(...))
//   BackNavHeader(title: 'History', trailing: IconButton(...))
// ---------------------------------------------------------------------------

class BackNavHeader extends StatelessWidget {
  const BackNavHeader({
    super.key,
    required this.title,
    this.onBack,
    this.icon = Icons.arrow_back_rounded,
    this.trailing,
  });

  /// Page title shown next to the back button.
  final String title;

  /// Tap handler. Defaults to `Navigator.of(context).maybePop()`.
  final VoidCallback? onBack;

  /// Icon inside the circular button.
  /// Use [Icons.close_rounded] for dismiss-style pages (e.g. status screens).
  final IconData icon;

  /// Optional widget pinned to the trailing edge (refresh button, etc.).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // ── Back / close button ──────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.54),
                border: Border.all(color: AppColors.softBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: AppColors.brandGold,
                size: icon == Icons.close_rounded ? 16 : 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // ── Title ────────────────────────────────────────────────────────
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 18,
              height: 1.1,
            ),
          ),
        ),

        // ── Optional trailing widget ─────────────────────────────────────
        if (trailing != null) trailing!,
      ],
    );
  }
}
