part of '../home_page.dart';

class _LiveEmptyCard extends StatelessWidget {
  const _LiveEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const _ChannelEmptyCard(message: 'No live streams right now.');
  }
}

class _ChannelMoreButton extends StatelessWidget {
  const _ChannelMoreButton({
    this.label = 'More',
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton(
        onPressed: enabled
            ? onPressed ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('More loading coming soon.')),
                  );
                }
            : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandGold,
          side: const BorderSide(color: AppColors.softBorder),
          textStyle: AppTextStyles.caption,
        ),
        child: Text(label),
      ),
    );
  }
}

class _ChannelLoadingCard extends StatelessWidget {
  const _ChannelLoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(message, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ChannelEmptyCard extends StatelessWidget {
  const _ChannelEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}
