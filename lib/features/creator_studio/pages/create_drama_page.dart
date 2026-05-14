import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/back_nav_header.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/endpoints.dart';

class CreateDramaPage extends StatefulWidget {
  const CreateDramaPage({super.key});

  @override
  State<CreateDramaPage> createState() => _CreateDramaPageState();
}

class _CreateDramaPageState extends State<CreateDramaPage> {
  final ApiClient _apiClient = ApiClient();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _totalEpisodesController =
      TextEditingController(text: '1');

  String _status = 'draft';
  File? _coverFile;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _totalEpisodesController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _coverFile = File(picked.path));
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final int totalEpisodes =
          int.tryParse(_totalEpisodesController.text.trim()) ?? 1;

      final formData = FormData.fromMap(<String, dynamic>{
        'title': title,
        'description': _descriptionController.text.trim(),
        'status': _status,
        'total_episodes': totalEpisodes,
        if (_categoryController.text.trim().isNotEmpty)
          'category': _categoryController.text.trim(),
        if (_coverFile != null)
          'cover': await MultipartFile.fromFile(_coverFile!.path),
      });

      await _apiClient.post<dynamic>(
        Endpoints.creatorDramas,
        data: formData,
        authenticated: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drama created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to create drama. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const BackNavHeader(title: 'Create Drama'),
              const SizedBox(height: AppSpacing.lg),

              // ── Cover picker ──────────────────────────────────────────────
              _FieldCard(
                label: 'Cover Image (optional)',
                child: _coverFile != null
                    ? _CoverPreview(
                        file: _coverFile!,
                        onChangeTap: _saving ? null : _pickCover,
                      )
                    : _FilePicker(
                        icon: Icons.image_outlined,
                        label: 'Select cover image',
                        onTap: _saving ? null : _pickCover,
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Title ─────────────────────────────────────────────────────
              _FieldCard(
                label: 'Title *',
                child: TextField(
                  controller: _titleController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  decoration: _fieldDecoration('Enter drama title'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Description ───────────────────────────────────────────────
              _FieldCard(
                label: 'Description',
                child: TextField(
                  controller: _descriptionController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  maxLines: 4,
                  minLines: 2,
                  decoration: _fieldDecoration('Describe your drama series…'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Category ──────────────────────────────────────────────────
              _FieldCard(
                label: 'Category ID (optional)',
                child: TextField(
                  controller: _categoryController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('e.g. 1'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Total episodes ────────────────────────────────────────────
              _FieldCard(
                label: 'Total Episodes',
                child: TextField(
                  controller: _totalEpisodesController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('Number of planned episodes'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Status ────────────────────────────────────────────────────
              _FieldCard(
                label: 'Status',
                child: _DropdownRow<String>(
                  value: _status,
                  items: const <String>['draft', 'published'],
                  onChanged:
                      _saving ? null : (v) => setState(() => _status = v!),
                ),
              ),

              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _ErrorBanner(message: _error!),
              ],

              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Create Drama',
                        style: AppTextStyles.body.copyWith(
                            color: Colors.black, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.file, required this.onChangeTap});
  final File file;
  final VoidCallback? onChangeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Image.file(file,
              width: 60, height: 80, fit: BoxFit.cover),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: onChangeTap,
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.brandGold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  const _FilePicker(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.warmBackground,
          border: Border.all(color: AppColors.softBorder),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.brandGold),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(label, style: AppTextStyles.caption),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.mutedOliveText),
          ],
        ),
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow(
      {required this.value, required this.items, required this.onChanged});
  final T value;
  final List<T> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warmBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.cardBackground,
          style: AppTextStyles.body,
          iconEnabledColor: AppColors.mutedOliveText,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(item.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(20),
        border: Border.all(color: Colors.redAccent.withAlpha(80)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(message,
          style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.caption,
    isDense: true,
    filled: true,
    fillColor: AppColors.warmBackground,
    contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: const BorderSide(color: AppColors.softBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: const BorderSide(color: AppColors.brandGold),
    ),
  );
}
