import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// App-wide pull-to-refresh wrapper.
///
/// Enforces the brand gold color and 2.5 stroke width so every refreshable
/// list looks consistent. Use this instead of [RefreshIndicator] directly.
///
/// The child must be a scrollable that produces overscroll notifications
/// (ListView, GridView, CustomScrollView, etc.).
///
/// Shorts/Feed (PageView with vertical scroll) is explicitly exempt — the
/// drag-down gesture conflicts with page navigation.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.brandGold,
      strokeWidth: 2.5,
      child: child,
    );
  }
}
