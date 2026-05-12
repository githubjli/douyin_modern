import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// InfoRow — label left / value right data row
//
// Used inside summary cards, order detail cards, and breakdown sections.
//
// Usage:
//   InfoRow(label: 'Order #', value: 'MC-001')
//   InfoRow(label: 'Status', value: 'Credited ✓', valueColor: Colors.greenAccent)
//   InfoRow(label: 'Credits', value: '105', valueColor: AppColors.brandGold)
// ---------------------------------------------------------------------------

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;

  /// Defaults to [Colors.white].
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
        ),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}
