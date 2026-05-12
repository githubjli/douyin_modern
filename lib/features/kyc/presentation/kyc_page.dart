import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/back_nav_header.dart';
import '../../../app/widgets/gold_button.dart';
import '../application/kyc_providers.dart';
import '../domain/kyc_profile.dart';

class KycPage extends ConsumerStatefulWidget {
  const KycPage({super.key});

  @override
  ConsumerState<KycPage> createState() => _KycPageState();
}

class _KycPageState extends ConsumerState<KycPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _idExpiryCtrl = TextEditingController();

  String _nationalityCode = '';
  String _idType = 'passport';

  File? _idFrontFile;
  File? _selfieFile;

  // Tracks URLs already on server (from existing KycProfile)
  String? _idFrontUrl;
  String? _selfieUrl;

  bool _saving = false;
  bool _uploading = false;
  bool _submitting = false;
  String? _error;

  static const List<(String, String)> _idTypes = <(String, String)>[
    ('passport', 'Passport'),
    ('national_id', 'National ID'),
    ('driver_license', "Driver's License"),
  ];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _dobCtrl.dispose();
    _nationalityCtrl.dispose();
    _idNumberCtrl.dispose();
    _idExpiryCtrl.dispose();
    super.dispose();
  }

  void _populateFrom(KycProfile profile) {
    if (_fullNameCtrl.text.isEmpty && profile.fullName.isNotEmpty) {
      _fullNameCtrl.text = profile.fullName;
    }
    if (_dobCtrl.text.isEmpty && profile.dateOfBirth != null) {
      _dobCtrl.text = profile.dateOfBirth!;
    }
    if (_nationalityCode.isEmpty && profile.nationality.isNotEmpty) {
      _nationalityCode = profile.nationality;
      _nationalityCtrl.text = _countryName(profile.nationality);
    }
    if (profile.idType.isNotEmpty) _idType = profile.idType;
    if (_idNumberCtrl.text.isEmpty && profile.idNumber.isNotEmpty) {
      _idNumberCtrl.text = profile.idNumber;
    }
    if (_idExpiryCtrl.text.isEmpty && profile.idExpiryDate != null) {
      _idExpiryCtrl.text = profile.idExpiryDate!;
    }
    _idFrontUrl = profile.idFront?.imageUrl;
    _selfieUrl = profile.selfie?.imageUrl;
  }

  String _countryName(String code) {
    try {
      return CountryParser.parseCountryCode(code).name;
    } catch (_) {
      return code;
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(ctrl.text) ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.brandGold,
            onPrimary: Colors.black,
            surface: AppColors.cardBackground,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    ctrl.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickImage(String docType) async {
    final picker = ImagePicker();
    final XFile? xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    setState(() {
      if (docType == 'id_front') {
        _idFrontFile = File(xfile.path);
      } else {
        _selfieFile = File(xfile.path);
      }
    });
  }

  Future<void> _saveAndUpload() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_nationalityCode.isEmpty) {
      setState(() => _error = 'Please select a nationality.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(kycRepositoryProvider);
      await repo.saveProfile(
        fullName: _fullNameCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        nationality: _nationalityCode,
        idType: _idType,
        idNumber: _idNumberCtrl.text.trim(),
        idExpiryDate: _idExpiryCtrl.text.trim(),
      );

      setState(() => _uploading = true);
      if (_idFrontFile != null) {
        final doc = await repo.uploadDocument(
          documentType: 'id_front',
          image: _idFrontFile!,
        );
        _idFrontUrl = doc.imageUrl;
        _idFrontFile = null;
      }
      if (_selfieFile != null) {
        final doc = await repo.uploadDocument(
          documentType: 'selfie',
          image: _selfieFile!,
        );
        _selfieUrl = doc.imageUrl;
        _selfieFile = null;
      }

      if (!mounted) return;
      setState(() {});
      _showSnack('Profile saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final bool hasIdFront = _idFrontFile != null || _idFrontUrl != null;
    final bool hasSelfie = _selfieFile != null || _selfieUrl != null;
    if (!hasIdFront || !hasSelfie) {
      setState(() =>
          _error = 'Please upload both ID front photo and selfie.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Save unsaved changes first, then submit
      if (!(_formKey.currentState?.validate() ?? false)) {
        setState(() => _submitting = false);
        return;
      }
      final repo = ref.read(kycRepositoryProvider);
      await repo.saveProfile(
        fullName: _fullNameCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        nationality: _nationalityCode,
        idType: _idType,
        idNumber: _idNumberCtrl.text.trim(),
        idExpiryDate: _idExpiryCtrl.text.trim(),
      );
      if (_idFrontFile != null) {
        await repo.uploadDocument(
            documentType: 'id_front', image: _idFrontFile!);
        _idFrontFile = null;
      }
      if (_selfieFile != null) {
        await repo.uploadDocument(
            documentType: 'selfie', image: _selfieFile!);
        _selfieFile = null;
      }
      await repo.submit();
      if (!mounted) return;
      ref.invalidate(kycProfileProvider);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(kycProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.brandGold),
          ),
          error: (e, _) => _ErrorBody(message: e.toString()),
          data: (profile) {
            _populateFrom(profile);
            if (profile.isPending) return _PendingBody(profile: profile);
            if (profile.isApproved) return _ApprovedBody(profile: profile);
            return _buildForm(profile);
          },
        ),
      ),
    );
  }

  Widget _buildForm(KycProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const BackNavHeader(title: 'Private KYC/AML'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your information is encrypted and used only for identity verification.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.mutedOliveText),
            ),

            // Rejected banner
            if (profile.isRejected && profile.rejectReason.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                color: Colors.redAccent,
                icon: Icons.cancel_outlined,
                message: 'Rejected: ${profile.rejectReason}',
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            _sectionLabel('Personal Information'),
            const SizedBox(height: AppSpacing.sm),

            _field(
              controller: _fullNameCtrl,
              label: 'Full Name',
              hint: 'As shown on your ID',
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),

            _datePicker(
              controller: _dobCtrl,
              label: 'Date of Birth',
            ),
            const SizedBox(height: AppSpacing.sm),

            // Country picker
            _tappableField(
              controller: _nationalityCtrl,
              label: 'Nationality',
              hint: 'Select country',
              onTap: () => showCountryPicker(
                context: context,
                showPhoneCode: false,
                onSelect: (Country c) => setState(() {
                  _nationalityCode = c.countryCode;
                  _nationalityCtrl.text = c.name;
                }),
              ),
              validator: (_) =>
                  _nationalityCode.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            _sectionLabel('ID Document'),
            const SizedBox(height: AppSpacing.sm),

            // ID type dropdown
            _kycContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _idType,
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                  iconEnabledColor: AppColors.mutedOliveText,
                  items: _idTypes
                      .map((t) => DropdownMenuItem<String>(
                            value: t.$1,
                            child: Text(t.$2),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _idType = v ?? _idType),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            _field(
              controller: _idNumberCtrl,
              label: 'ID Number',
              hint: 'e.g. E12345678',
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),

            _datePicker(
              controller: _idExpiryCtrl,
              label: 'ID Expiry Date',
            ),
            const SizedBox(height: AppSpacing.lg),

            _sectionLabel('Documents'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Upload clear, well-lit photos. Both images required.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.mutedOliveText),
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: <Widget>[
                Expanded(
                  child: _DocUploadTile(
                    label: 'ID Front',
                    icon: Icons.credit_card_rounded,
                    localFile: _idFrontFile,
                    remoteUrl: _idFrontUrl,
                    onTap: () => _pickImage('id_front'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _DocUploadTile(
                    label: 'Selfie',
                    icon: Icons.face_rounded,
                    localFile: _selfieFile,
                    remoteUrl: _selfieUrl,
                    onTap: () => _pickImage('selfie'),
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                color: Colors.redAccent,
                icon: Icons.error_outline,
                message: _error!,
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Save draft button
            GoldButton(
              label: _uploading ? 'Uploading…' : 'Save Draft',
              loading: _saving,
              onTap: (_saving || _submitting) ? null : _saveAndUpload,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Submit button
            _SubmitButton(
              loading: _submitting,
              enabled: !_saving && !_submitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.mutedOliveText,
          letterSpacing: 0.8,
          fontSize: 11,
        ),
      );

  Widget _kycContainer({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.softBorder),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: child,
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: _inputDeco(label: label, hint: hint),
    );
  }

  Widget _datePicker({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.white),
      validator: _required,
      onTap: () => _pickDate(controller),
      decoration: _inputDeco(
        label: label,
        hint: 'YYYY-MM-DD',
        suffix: const Icon(Icons.calendar_today_rounded,
            size: 16, color: AppColors.mutedOliveText),
      ),
    );
  }

  Widget _tappableField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      onTap: onTap,
      decoration: _inputDeco(
        label: label,
        hint: hint,
        suffix: const Icon(Icons.arrow_drop_down_rounded,
            color: AppColors.mutedOliveText),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          AppTextStyles.caption.copyWith(color: AppColors.mutedOliveText),
      hintText: hint,
      hintStyle: AppTextStyles.caption
          .copyWith(color: Colors.white.withValues(alpha: 0.3)),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.softBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.softBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(
            color: AppColors.brandGold.withValues(alpha: 0.7)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide:
            const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide:
            const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

// ---------------------------------------------------------------------------
// Status bodies
// ---------------------------------------------------------------------------

class _PendingBody extends StatelessWidget {
  const _PendingBody({required this.profile});
  final KycProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const BackNavHeader(title: 'Private KYC/AML'),
          const SizedBox(height: AppSpacing.lg),
          const _Banner(
            color: Colors.orange,
            icon: Icons.hourglass_top_rounded,
            message:
                'Your KYC submission is under review. We\'ll notify you once it\'s processed.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoCard(profile: profile),
        ],
      ),
    );
  }
}

class _ApprovedBody extends StatelessWidget {
  const _ApprovedBody({required this.profile});
  final KycProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const BackNavHeader(title: 'Private KYC/AML'),
          const SizedBox(height: AppSpacing.lg),
          const _Banner(
            color: Colors.green,
            icon: Icons.verified_rounded,
            message: 'KYC Approved — your identity has been verified.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoCard(profile: profile),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const BackNavHeader(title: 'Private KYC/AML'),
          const SizedBox(height: AppSpacing.lg),
          _Banner(
              color: Colors.redAccent,
              icon: Icons.error_outline,
              message: message),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info card (read-only summary for pending/approved)
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});
  final KycProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row('Full Name', profile.fullName),
          _div(),
          _row('Date of Birth', profile.dateOfBirth ?? '—'),
          _div(),
          _row('Nationality', profile.nationality),
          _div(),
          _row('ID Type', _idTypeLabel(profile.idType)),
          _div(),
          _row('ID Number', profile.idNumber),
          _div(),
          _row('ID Expiry', profile.idExpiryDate ?? '—'),
          if (profile.submittedAt != null) ...[
            _div(),
            _row('Submitted', _formatDate(profile.submittedAt)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.mutedOliveText)),
            Text(value,
                style: AppTextStyles.body.copyWith(color: Colors.white)),
          ],
        ),
      );

  Widget _div() =>
      const Divider(height: 1, color: AppColors.softBorder);

  String _idTypeLabel(String raw) {
    switch (raw) {
      case 'passport':
        return 'Passport';
      case 'national_id':
        return 'National ID';
      case 'driver_license':
        return "Driver's License";
      default:
        return raw;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${l.day} ${months[l.month - 1]} ${l.year}';
  }
}

// ---------------------------------------------------------------------------
// Document upload tile
// ---------------------------------------------------------------------------

class _DocUploadTile extends StatelessWidget {
  const _DocUploadTile({
    required this.label,
    required this.icon,
    required this.localFile,
    required this.remoteUrl,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final File? localFile;
  final String? remoteUrl;
  final VoidCallback onTap;

  bool get _hasImage => localFile != null || (remoteUrl?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(
            color: _hasImage
                ? AppColors.brandGold.withValues(alpha: 0.5)
                : AppColors.softBorder,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: _hasImage ? _preview() : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: AppColors.mutedOliveText, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.mutedOliveText)),
          const SizedBox(height: 2),
          Text('Tap to upload',
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white38, fontSize: 10)),
        ],
      );

  Widget _preview() {
    Widget image;
    if (localFile != null) {
      image = Image.file(localFile!,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      image = Image.network(remoteUrl!,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
          child: image,
        ),
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.edit_rounded,
                size: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.message,
  });
  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.body.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Submit button
// ---------------------------------------------------------------------------

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.loading,
    required this.enabled,
    required this.onTap,
  });
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.brandGold),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.brandGold),
                )
              : Text(
                  'Submit for Review',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.brandGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
