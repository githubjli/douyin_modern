part of '../shop_page.dart';

class _ShopEmptyCard extends StatelessWidget {
  const _ShopEmptyCard({required this.message});

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

class _ShopLoadMoreButton extends StatelessWidget {
  const _ShopLoadMoreButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandGold,
          side: const BorderSide(color: AppColors.softBorder),
          textStyle: AppTextStyles.caption,
        ),
        child: Text(loading ? 'Loading...' : 'Load more'),
      ),
    );
  }
}
