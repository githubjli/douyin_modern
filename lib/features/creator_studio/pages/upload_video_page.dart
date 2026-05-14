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

class UploadVideoPage extends StatefulWidget {
  const UploadVideoPage({super.key});

  @override
  State<UploadVideoPage> createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends State<UploadVideoPage> {
  final ApiClient _apiClient = ApiClient();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String _visibility = 'public';
  String _accessType = 'free';
  File? _videoFile;
  File? _thumbnailFile;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? picked =
        await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _videoFile = File(picked.path));
  }

  Future<void> _pickThumbnail() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 720,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _thumbnailFile = File(picked.path));
  }

  Future<void> _upload() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_videoFile == null) {
      setState(() => _error = 'Please select a video file.');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final formData = FormData.fromMap(<String, dynamic>{
        'title': title,
        'description': _descriptionController.text.trim(),
        'visibility': _visibility,
        'access_type': _accessType,
        if (_categoryController.text.trim().isNotEmpty)
          'category': _categoryController.text.trim(),
        'file': await MultipartFile.fromFile(_videoFile!.path),
        if (_thumbnailFile != null)
          'thumbnail': await MultipartFile.fromFile(_thumbnailFile!.path),
      });

      await _apiClient.post<dynamic>(
        Endpoints.creatorVideos,
        data: formData,
        authenticated: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
              const BackNavHeader(title: 'Upload Video'),
              const SizedBox(height: AppSpacing.lg),

              // ── Video file picker ─────────────────────────────────────────
              _FieldCard(
                label: 'Video File',
                child: _FilePicker(
                  icon: Icons.videocam_outlined,
                  label: _videoFile != null
                      ? _videoFile!.path.split('/').last
                      : 'Select video from gallery',
                  onTap: _uploading ? null : _pickVideo,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Thumbnail picker ──────────────────────────────────────────
              _FieldCard(
                label: 'Thumbnail (optional)',
                child: _FilePicker(
                  icon: Icons.image_outlined,
                  label: _thumbnailFile != null
                      ? _thumbnailFile!.path.split('/').last
                      : 'Select thumbnail image',
                  onTap: _uploading ? null : _pickThumbnail,
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
                  decoration: _fieldDecoration('Enter video title'),
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
                  decoration: _fieldDecoration('Describe your video…'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Visibility ────────────────────────────────────────────────
              _FieldCard(
                label: 'Visibility',
                child: _DropdownRow<String>(
                  value: _visibility,
                  items: const <String>['public', 'private'],
                  onChanged: _uploading
                      ? null
                      : (v) => setState(() => _visibility = v!),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Access type ───────────────────────────────────────────────
              _FieldCard(
                label: 'Access Type',
                child: _DropdownRow<String>(
                  value: _accessType,
                  items: const <String>['free', 'paid'],
                  onChanged: _uploading
                      ? null
                      : (v) => setState(() => _accessType = v!),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Category ──────────────────────────────────────────────────
              _FieldCard(
                label: 'Category (optional)',
                child: TextField(
                  controller: _categoryController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  decoration: _fieldDecoration('e.g. technology'),
                ),
              ),

              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _ErrorBanner(message: _error!),
              ],

              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: _uploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Upload',
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

// ── Shared field widgets ──────────────────────────────────────────────────────

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
              child: Text(
                label,
                style: AppTextStyles.caption,
                overflow: TextOverflow.ellipsis,
              ),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
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
