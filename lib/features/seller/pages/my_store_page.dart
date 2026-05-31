import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/back_nav_header.dart';
import '../../../app/widgets/gold_button.dart';
import '../application/seller_application_providers.dart';
import '../domain/seller_models.dart';

class MyStorePage extends ConsumerStatefulWidget {
  const MyStorePage({super.key});

  @override
  ConsumerState<MyStorePage> createState() => _MyStorePageState();
}

class _MyStorePageState extends ConsumerState<MyStorePage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _startEdit(SellerStore store) {
    _nameCtrl.text = store.name;
    _descCtrl.text = store.description ?? '';
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Store name cannot be empty');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(sellerRepositoryProvider).updateStore(<String, dynamic>{
        'name': name,
        'description': _descCtrl.text.trim(),
      });
      ref.invalidate(sellerStoreProvider);
      if (mounted) setState(() => _editing = false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(sellerStoreProvider);

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            BackNavHeader(
              title: 'My Store',
              trailing: storeAsync.value != null && !_editing
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.brandGold),
                      onPressed: () => _startEdit(storeAsync.value!),
                    )
                  : null,
            ),
            Expanded(
              child: storeAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brandGold),
                ),
                error: (e, _) => Center(
                  child: Text('Failed to load store',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.mutedOliveText)),
                ),
                data: (store) {
                  if (store == null) {
                    return Center(
                      child: Text('Store not found',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.mutedOliveText)),
                    );
                  }
                  return _editing
                      ? _EditView(
                          nameCtrl: _nameCtrl,
                          descCtrl: _descCtrl,
                          saving: _saving,
                          error: _error,
                          onSave: _save,
                          onCancel: () => setState(() => _editing = false),
                        )
                      : _InfoView(store: store);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Read-only view ────────────────────────────────────────────────────────────

class _InfoView extends StatelessWidget {
  const _InfoView({required this.store});
  final SellerStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        // Store avatar / logo
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.brandGold.withValues(alpha: 0.4), width: 2),
            ),
            child: store.logoUrl != null
                ? ClipOval(
                    child: Image.network(store.logoUrl!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.storefront_outlined,
                    color: AppColors.brandGold, size: 36),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Store name
        Center(
          child: Text(
            store.name,
            style: AppTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Status badge
        Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: store.isActive
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              store.isActive ? 'Active' : 'Inactive',
              style: AppTextStyles.caption.copyWith(
                color: store.isActive ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Description
        if (store.description?.isNotEmpty == true) ...<Widget>[
          Text('About',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.mutedOliveText)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(store.description!, style: AppTextStyles.body),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Info rows
        _InfoCard(
          children: <Widget>[
            _InfoRow(label: 'Store ID', value: '#${store.id}'),
            _InfoRow(
              label: 'Status',
              value: store.isActive ? 'Active' : 'Inactive',
            ),
          ],
        ),
      ],
    );
  }
}

// ── Edit view ─────────────────────────────────────────────────────────────────

class _EditView extends StatelessWidget {
  const _EditView({
    required this.nameCtrl,
    required this.descCtrl,
    required this.saving,
    required this.onSave,
    required this.onCancel,
    this.error,
  });

  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        _FieldLabel(label: 'Store Name'),
        const SizedBox(height: AppSpacing.xs),
        _InputField(controller: nameCtrl, hint: 'Your store name'),
        const SizedBox(height: AppSpacing.md),
        _FieldLabel(label: 'Description'),
        const SizedBox(height: AppSpacing.xs),
        _InputField(
          controller: descCtrl,
          hint: 'Tell customers about your store',
          maxLines: 4,
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(error!,
                style: AppTextStyles.caption.copyWith(color: Colors.red)),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        GoldButton(
          label: saving ? 'Saving…' : 'Save Changes',
          onTap: saving ? null : onSave,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: saving ? null : onCancel,
          child: Text('Cancel',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.mutedOliveText)),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.mutedOliveText,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTextStyles.body.copyWith(color: AppColors.mutedOliveText),
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(children: children),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.mutedOliveText)),
            const Spacer(),
            Text(value, style: AppTextStyles.caption),
          ],
        ),
      );
}
