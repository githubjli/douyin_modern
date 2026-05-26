part of '../shop_page.dart';

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<ShopProduct> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (_, int index) => _ProductCard(
        product: products[index],
        onTap: () => _showProductComingSoon(context),
      ),
    );
  }
}

void _showProductComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Product detail page coming soon.')),
  );
}
