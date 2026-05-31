import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../data/seller_repository.dart';
import '../domain/seller_models.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({
    super.key,
    required this.repo,
    this.product,
  });

  final SellerRepository repo;
  final SellerProduct? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController();
  final TextEditingController _mpPriceCtrl = TextEditingController();
  final TextEditingController _mcPriceCtrl = TextEditingController();
  final TextEditingController _thumbnailCtrl = TextEditingController();

  bool _saving = false;

  // Category
  List<_Category> _categories = const <_Category>[];
  _Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final SellerProduct? p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description ?? '';
      _stockCtrl.text = p.stock.toString();
      _mpPriceCtrl.text = p.meowPointsPrice ?? '';
      _mcPriceCtrl.text = p.meowCreditPrice ?? '';
      _thumbnailCtrl.text = p.thumbnailUrl ?? '';
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiClient().get<dynamic>(Endpoints.shopCategories);
      final dynamic raw = response.data;
      if (raw is! List) return;
      final List<_Category> cats = raw
          .whereType<Map<String, dynamic>>()
          .where((Map<String, dynamic> m) => (m['slug'] as String?) != 'all')
          .map((Map<String, dynamic> m) => _Category(
                id: m['id'] as int? ?? 0,
                name: m['name'] as String? ?? '',
                slug: m['slug'] as String? ?? '',
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        // Pre-select if editing
        if (widget.product?.categorySlug != null) {
          _selectedCategory = cats.cast<_Category?>().firstWhere(
                (_Category? c) => c!.slug == widget.product!.categorySlug,
                orElse: () => null,
              );
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _stockCtrl.dispose();
    _mpPriceCtrl.dispose();
    _mcPriceCtrl.dispose();
    _thumbnailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final Map<String, dynamic> body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'stock': int.parse(_stockCtrl.text.trim()),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      if (_mpPriceCtrl.text.trim().isNotEmpty) 'meow_points_price': _mpPriceCtrl.text.trim(),
      if (_mcPriceCtrl.text.trim().isNotEmpty) 'meow_credit_price': _mcPriceCtrl.text.trim(),
      if (_thumbnailCtrl.text.trim().isNotEmpty) 'thumbnail_url': _thumbnailCtrl.text.trim(),
      if (_selectedCategory != null) 'category_id': _selectedCategory!.id,
    };

    try {
      if (widget.isEditing) {
        await widget.repo.updateProduct(widget.product!.id, body);
      } else {
        await widget.repo.createProduct(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
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
        title: Text(
          widget.isEditing ? 'Edit Product' : 'Add Product',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
        ),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandGold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save', style: TextStyle(color: AppColors.brandGold, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            _FormCard(
              children: <Widget>[
                _field(
                  controller: _nameCtrl,
                  label: 'Product Name *',
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _field(
                  controller: _descCtrl,
                  label: 'Description',
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _FormCard(
              children: <Widget>[
                _field(
                  controller: _stockCtrl,
                  label: 'Stock *',
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v.trim()) == null) return 'Must be a number';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_categories.isNotEmpty)
              _FormCard(
                label: 'Category',
                children: <Widget>[
                  DropdownButtonFormField<_Category>(
                    initialValue: _selectedCategory,
                    hint: Text('Select category', style: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText)),
                    dropdownColor: AppColors.cardBackground,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.softBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.softBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.brandGold)),
                      filled: true,
                      fillColor: AppColors.warmBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _categories.map((_Category c) => DropdownMenuItem<_Category>(
                      value: c,
                      child: Text(c.name, style: AppTextStyles.caption.copyWith(color: AppColors.cocoaText)),
                    )).toList(),
                    onChanged: (_Category? v) => setState(() => _selectedCategory = v),
                  ),
                ],
              ),
            if (_categories.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            _FormCard(
              label: 'Pricing (at least one required)',
              children: <Widget>[
                _field(
                  controller: _mpPriceCtrl,
                  label: 'MeowPoints Price (MP)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (String? v) {
                    final String mp = _mpPriceCtrl.text.trim();
                    final String mc = _mcPriceCtrl.text.trim();
                    if (mp.isEmpty && mc.isEmpty) return 'Set at least one price';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _field(
                  controller: _mcPriceCtrl,
                  label: 'MeowCredit Price (MC)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _FormCard(
              label: 'Media',
              children: <Widget>[
                _field(
                  controller: _thumbnailCtrl,
                  label: 'Thumbnail URL',
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(widget.isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: AppTextStyles.caption.copyWith(color: AppColors.cocoaText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.brandGold),
        ),
        filled: true,
        fillColor: AppColors.warmBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children, this.label});
  final List<Widget> children;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Text(
              label!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mutedOliveText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _Category {
  const _Category({required this.id, required this.name, required this.slug});
  final int id;
  final String name;
  final String slug;

  @override
  bool operator ==(Object other) => other is _Category && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
