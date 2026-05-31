import 'package:meow_media/app/widgets/app_cached_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../data/seller_repository.dart';
import '../domain/seller_models.dart';
import 'product_form_page.dart';

class MyProductsPage extends StatefulWidget {
  const MyProductsPage({super.key});

  @override
  State<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends State<MyProductsPage> {
  late final SellerRepository _repo;
  List<SellerProduct> _products = const <SellerProduct>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = SellerRepository(ApiClient());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SellerProduct> items = await _repo.getProducts();
      if (!mounted) return;
      setState(() {
        _products = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _goAdd() async {
    final bool? added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProductFormPage(repo: _repo),
      ),
    );
    if (added == true) _load();
  }

  Future<void> _goEdit(SellerProduct product) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProductFormPage(repo: _repo, product: product),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _confirmDelete(SellerProduct product) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Delete Product', style: AppTextStyles.cardTitle),
        content: Text(
          'Remove "${product.name}"? This cannot be undone.',
          style: AppTextStyles.caption,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteProduct(product.id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: Text('My Products', style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _goAdd,
            tooltip: 'Add product',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandGold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.storefront_outlined, size: 64, color: AppColors.mutedOliveText),
            const SizedBox(height: AppSpacing.md),
            Text('No products yet', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _goAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brandGold,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, int i) => _ProductTile(
          product: _products[i],
          onEdit: () => _goEdit(_products[i]),
          onDelete: () => _confirmDelete(_products[i]),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final SellerProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: product.thumbnailUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppCachedImage(
                  imageUrl: product.thumbnailUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.warmBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image_outlined, color: AppColors.mutedOliveText),
              ),
        title: Text(
          product.name,
          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 2),
            Text(
              product.displayPrice,
              style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
            ),
            Text(
              'Stock: ${product.stock}  •  Sold: ${product.soldCount}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!product.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inactive',
                  style: TextStyle(color: Colors.orange, fontSize: 10),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              color: AppColors.mutedOliveText,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              color: Colors.red.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
