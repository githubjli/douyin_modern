import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/back_nav_header.dart';
import '../../../app/widgets/gold_button.dart';
import '../application/seller_application_providers.dart';
import '../domain/seller_models.dart';

class SellerApplicationPage extends ConsumerStatefulWidget {
  const SellerApplicationPage({super.key});

  @override
  ConsumerState<SellerApplicationPage> createState() =>
      _SellerApplicationPageState();
}

class _SellerApplicationPageState
    extends ConsumerState<SellerApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  String _businessType = 'individual';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(sellerRepositoryProvider).submitApplication(
            storeName: _storeNameCtrl.text.trim(),
            businessType: _businessType,
            businessDescription: _descriptionCtrl.text.trim(),
            contactPhone: _phoneCtrl.text.trim(),
            contactEmail: _emailCtrl.text.trim(),
            businessLicenseUrl: _licenseCtrl.text.trim().isNotEmpty
                ? _licenseCtrl.text.trim()
                : null,
          );
      ref.invalidate(sellerApplicationProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final dynamic data = e.response?.data;
      String msg = 'Submission failed. Please try again.';
      if (data is Map<String, dynamic>) {
        final dynamic detail = data['detail'] ?? data.values.firstOrNull;
        if (detail is String) msg = detail;
        if (detail is List && detail.isNotEmpty) msg = detail.first.toString();
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const BackNavHeader(title: 'Apply to Sell'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Tell us about your store',
                          style: AppTextStyles.cardTitle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Our team will review your application within 1–3 business days.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.mutedOliveText),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _FieldLabel(label: 'Store Name'),
                      const SizedBox(height: AppSpacing.xs),
                      _InputField(
                        controller: _storeNameCtrl,
                        hint: 'e.g. Alice Handmade',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _FieldLabel(label: 'Business Type'),
                      const SizedBox(height: AppSpacing.xs),
                      _BusinessTypeSelector(
                        value: _businessType,
                        onChanged: (v) => setState(() => _businessType = v),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _FieldLabel(label: 'What will you sell?'),
                      const SizedBox(height: AppSpacing.xs),
                      _InputField(
                        controller: _descriptionCtrl,
                        hint: 'Briefly describe your products or services',
                        maxLines: 3,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _FieldLabel(label: 'Contact Phone'),
                      const SizedBox(height: AppSpacing.xs),
                      _InputField(
                        controller: _phoneCtrl,
                        hint: '+1 555 000 0000',
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _FieldLabel(label: 'Contact Email'),
                      const SizedBox(height: AppSpacing.xs),
                      _InputField(
                        controller: _emailCtrl,
                        hint: 'your@email.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),

                      if (_businessType == 'company') ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _FieldLabel(label: 'Business License URL'),
                        const SizedBox(height: AppSpacing.xs),
                        _InputField(
                          controller: _licenseCtrl,
                          hint: 'https://…',
                          keyboardType: TextInputType.url,
                          validator: (v) =>
                              _businessType == 'company' &&
                                      (v == null || v.trim().isEmpty)
                                  ? 'Required for company accounts'
                                  : null,
                        ),
                      ],

                      if (_error != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color:
                                Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.red),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),
                      GoldButton(
                        label: _submitting
                            ? 'Submitting…'
                            : 'Submit Application',
                        onTap: _submitting ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status view ───────────────────────────────────────────────────────────────

class SellerApplicationStatusPage extends ConsumerWidget {
  const SellerApplicationStatusPage({
    super.key,
    required this.application,
  });

  final SellerApplication application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SellerApplicationStatus status = application.status;
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const BackNavHeader(title: 'Seller Application'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _StatusBanner(status: status),
                    const SizedBox(height: AppSpacing.lg),
                    _InfoRow(
                        label: 'Store Name', value: application.storeName),
                    _InfoRow(
                      label: 'Business Type',
                      value: application.businessType == 'company'
                          ? 'Company'
                          : 'Individual',
                    ),
                    _InfoRow(
                        label: 'Contact Email',
                        value: application.contactEmail),
                    _InfoRow(
                        label: 'Contact Phone',
                        value: application.contactPhone),
                    if (application.submittedAt != null)
                      _InfoRow(
                        label: 'Submitted',
                        value: _formatDate(application.submittedAt!),
                      ),
                    if (status == SellerApplicationStatus.rejected &&
                        application.rejectionReason?.isNotEmpty ==
                            true) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Reason for rejection',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              application.rejectionReason!,
                              style: AppTextStyles.caption
                                  .copyWith(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GoldButton(
                        label: 'Submit New Application',
                        onTap: () {
                          Navigator.of(context)
                              .pushReplacement<bool?, bool?>(
                            MaterialPageRoute<bool?>(
                              builder: (_) => const SellerApplicationPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
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

class _BusinessTypeSelector extends StatelessWidget {
  const _BusinessTypeSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          _TypeChip(
            label: 'Individual',
            selected: value == 'individual',
            onTap: () => onChanged('individual'),
          ),
          const SizedBox(width: AppSpacing.sm),
          _TypeChip(
            label: 'Company',
            selected: value == 'company',
            onTap: () => onChanged('company'),
          ),
        ],
      );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandGold : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? Colors.black : AppColors.mutedOliveText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final SellerApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (String icon, String title, String subtitle, Color color) =
        switch (status) {
      SellerApplicationStatus.pending => (
          '⏳',
          'Under Review',
          'Our team is reviewing your application. This typically takes 1–3 business days.',
          Colors.orange,
        ),
      SellerApplicationStatus.approved => (
          '✅',
          'Approved',
          'Your seller account is active. You can now list products.',
          Colors.green,
        ),
      SellerApplicationStatus.rejected => (
          '❌',
          'Not Approved',
          'Your application was not approved. See the reason below and reapply.',
          Colors.red,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: AppTextStyles.cardTitle.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.mutedOliveText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.mutedOliveText),
              ),
            ),
            Expanded(
              child: Text(value, style: AppTextStyles.caption),
            ),
          ],
        ),
      );
}
