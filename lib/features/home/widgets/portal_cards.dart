part of '../home_page.dart';

enum _CardKind { featured, video, drama, live }

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.title,
    required this.subtitle,
    required this.kind,
    this.imageUrl,
    this.badgeOverride,
    this.compactOverlay = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final _CardKind kind;
  final String? imageUrl;
  final String? badgeOverride;
  final bool compactOverlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String badge = badgeOverride ??
        switch (kind) {
          _CardKind.featured => 'Video',
          _CardKind.video => 'Video',
          _CardKind.drama => 'Drama',
          _CardKind.live => 'LIVE',
        };

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _CardCover(imageUrl: imageUrl, kind: kind),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x0D000000),
                    Color(0x55000000),
                    Color(0xB3000000),
                  ],
                  stops: <double>[0.2, 0.6, 1],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: kind == _CardKind.live
                      ? AppColors.brandGold
                      : AppColors.cardBackground.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.softBorder),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.caption.copyWith(
                    color: kind == _CardKind.live
                        ? AppColors.warmBackground
                        : AppColors.brandGold,
                  ),
                ),
              ),
            ),
            Positioned(
              left: compactOverlay ? AppSpacing.xs : AppSpacing.sm,
              right: compactOverlay ? AppSpacing.xs : AppSpacing.sm,
              bottom: compactOverlay ? AppSpacing.xs : AppSpacing.sm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: compactOverlay ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: compactOverlay ? 16 : 11,
                      height: compactOverlay ? 1.2 : 1.08,
                    ),
                  ),
                  SizedBox(height: compactOverlay ? 2 : AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: compactOverlay ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: compactOverlay ? Colors.white70 : Colors.white54,
                      fontSize: compactOverlay ? 12 : 10,
                      height: compactOverlay ? null : 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardCover extends StatelessWidget {
  const _CardCover({required this.imageUrl, required this.kind});

  final String? imageUrl;
  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    final String? trimmedUrl = imageUrl?.trim();
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return _CardCoverPlaceholder(kind: kind);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AppCachedImage(
        imageUrl: trimmedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => _CardCoverPlaceholder(kind: kind),
        errorWidget: (_, __, ___) => _CardCoverPlaceholder(kind: kind),
      ),
    );
  }
}

class _CardCoverPlaceholder extends StatelessWidget {
  const _CardCoverPlaceholder({required this.kind});

  final _CardKind kind;

  @override
  Widget build(BuildContext context) {
    final (_GradientSpec gradientSpec, IconData icon, String label, bool liveBadge) =
        switch (kind) {
      _CardKind.drama => (
          const _GradientSpec(Color(0xFF463522), Color(0xFF221A15)),
          Icons.theaters,
          'Drama',
          false
        ),
      _CardKind.live => (
          const _GradientSpec(Color(0xFF2E2419), Color(0xFF171514)),
          Icons.live_tv,
          'Live',
          true
        ),
      _ => (
          const _GradientSpec(Color(0xFF3B352A), Color(0xFF1F1E1D)),
          Icons.ondemand_video,
          'Video',
          false
        ),
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[gradientSpec.start, gradientSpec.end],
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (liveBadge)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandGold,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  'LIVE',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.warmBackground),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: AppColors.mutedOliveText, size: 30),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientSpec {
  const _GradientSpec(this.start, this.end);

  final Color start;
  final Color end;
}
