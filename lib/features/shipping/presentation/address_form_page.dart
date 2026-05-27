import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../data/shipping_address_repository.dart';
import '../domain/shipping_address.dart';

/// Create or edit a shipping address.
///
/// Pops with the saved [ShippingAddress] on success, or null on cancel.
class AddressFormPage extends ConsumerStatefulWidget {
  const AddressFormPage({super.key, this.existing});

  /// Non-null → edit mode; null → create mode.
  final ShippingAddress? existing;

  @override
  ConsumerState<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<AddressFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _line2Ctrl;
  late final TextEditingController _postalCtrl;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final ShippingAddress? a = widget.existing;
    _nameCtrl    = TextEditingController(text: a?.receiverName ?? '');
    _phoneCtrl   = TextEditingController(text: a?.phone ?? '');
    _countryCtrl = TextEditingController(text: a?.country ?? '');
    _stateCtrl   = TextEditingController(text: a?.state ?? '');
    _cityCtrl    = TextEditingController(text: a?.city ?? '');
    _districtCtrl= TextEditingController(text: a?.district ?? '');
    _line1Ctrl   = TextEditingController(text: a?.addressLine1 ?? '');
    _line2Ctrl   = TextEditingController(text: a?.addressLine2 ?? '');
    _postalCtrl  = TextEditingController(text: a?.postalCode ?? '');
    _isDefault   = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _nameCtrl, _phoneCtrl, _countryCtrl, _stateCtrl, _cityCtrl,
      _districtCtrl, _line1Ctrl, _line2Ctrl, _postalCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ShippingAddressRepository repo =
        ref.read(shippingAddressRepositoryProvider);

    try {
      ShippingAddress result;
      if (widget.existing == null) {
        // Create
        result = await repo.createAddress(
          ShippingAddress(
            id: 0,
            receiverName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            country: _countryCtrl.text.trim(),
            state: _stateCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            district: _districtCtrl.text.trim(),
            addressLine1: _line1Ctrl.text.trim(),
            addressLine2: _line2Ctrl.text.trim(),
            postalCode: _postalCtrl.text.trim(),
            isDefault: _isDefault,
          ),
        );
      } else {
        // Patch only changed fields (we send all for simplicity)
        result = await repo.updateAddress(
          widget.existing!.id,
          <String, dynamic>{
            'receiver_name': _nameCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'country': _countryCtrl.text.trim(),
            'state': _stateCtrl.text.trim(),
            'city': _cityCtrl.text.trim(),
            'district': _districtCtrl.text.trim(),
            'address_line1': _line1Ctrl.text.trim(),
            'address_line2': _line2Ctrl.text.trim(),
            'postal_code': _postalCtrl.text.trim(),
            'is_default': _isDefault,
          },
        );
      }

      // Invalidate the cached list so callers see fresh data.
      ref.invalidate(shippingAddressListProvider);

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.cardBackground,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: Text(
          isEdit ? 'Edit Address' : 'New Address',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandGold,
                    ),
                  )
                : Text(
                    'Save',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.brandGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            const _SectionLabel('RECIPIENT'),
            const SizedBox(height: AppSpacing.xs),
            _Field(
              controller: _nameCtrl,
              label: 'Receiver Name',
              hint: 'Full name',
              required: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _phoneCtrl,
              label: 'Phone',
              hint: '+65 9123 4567',
              keyboardType: TextInputType.phone,
              required: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionLabel('ADDRESS'),
            const SizedBox(height: AppSpacing.xs),
            _Field(
              controller: _line1Ctrl,
              label: 'Address Line 1',
              hint: 'Street, building, unit number',
              required: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _line2Ctrl,
              label: 'Address Line 2',
              hint: 'Apt, floor (optional)',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Field(
                    controller: _districtCtrl,
                    label: 'District',
                    hint: 'optional',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Field(
                    controller: _cityCtrl,
                    label: 'City',
                    hint: 'Singapore',
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Field(
                    controller: _stateCtrl,
                    label: 'State / Province',
                    hint: 'optional',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Field(
                    controller: _postalCtrl,
                    label: 'Postal Code',
                    hint: '123456',
                    keyboardType: TextInputType.number,
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _countryCtrl,
              label: 'Country',
              hint: 'Singapore',
              required: true,
            ),
            const SizedBox(height: AppSpacing.md),
            _DefaultToggle(
              value: _isDefault,
              onChanged: (bool v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form field helpers
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.mutedOliveText,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.body.copyWith(color: AppColors.cocoaText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.mutedOliveText,
        ),
        hintStyle: AppTextStyles.caption.copyWith(
          color: AppColors.softBorder,
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.brandGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: required
          ? (String? v) =>
              (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }
}

class _DefaultToggle extends StatelessWidget {
  const _DefaultToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(
          'Set as default address',
          style: AppTextStyles.body.copyWith(color: AppColors.cocoaText),
        ),
        activeColor: AppColors.brandGold,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
        ),
      ),
    );
  }
}
