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
import '../domain/creator_video.dart';
import 'video_form_widgets.dart';

class EditVideoPage extends StatefulWidget {
  const EditVideoPage({super.key, required this.video});

  final CreatorVideo video;

  @override
  State<EditVideoPage> createState() => _EditVideoPageState();
}

class _EditVideoPageState extends State<EditVideoPage> {
  final ApiClient _apiClient = ApiClient();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;

  late String _visibility;
  late String _accessType;
  File? _thumbnailFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final CreatorVideo v = widget.video;
    _titleController = TextEditingController(text: v.title);
    _descriptionController = TextEditingController(text: v.description ?? '');
    _categoryController = TextEditingController(text: v.category ?? '');
    _visibility = v.visibility;
    _accessType = v.accessType ?? 'free';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
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
      final String category = _categoryController.text.trim();
      if (_thumbnailFile != null) {
        final formData = FormData.fromMap(<String, dynamic>{
          'title': title,
          'description': _descriptionController.text.trim(),
          'visibility': _visibility,
          'access_type': _accessType,
          if (category.isNotEmpty) 'category': category,
          'thumbnail': await MultipartFile.fromFile(_thumbnailFile!.path),
        });
        await _apiClient.patch<dynamic>(
          Endpoints.videoOwnerDetail(widget.video.id),
          data: formData,
          authenticated: true,
        );
      } else {
        await _apiClient.patch<dynamic>(
          Endpoints.videoOwnerDetail(widget.video.id),
          data: <String, dynamic>{
            'title': title,
            'description': _descriptionController.text.trim(),
            'visibility': _visibility,
            'access_type': _accessType,
            if (category.isNotEmpty) 'category': category,
          },
          authenticated: true,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Save failed. Please try again.');
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
              const BackNavHeader(title: 'Edit Video'),
              const SizedBox(height: AppSpacing.lg),

              // ── Current thumbnail preview ─────────────────────────────────
              if (widget.video.thumbnailUrl != null && _thumbnailFile == null)
                FieldCard(
                  label: 'Current Thumbnail',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Image.network(
                      widget.video.thumbnailUrl!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (widget.video.thumbnailUrl != null && _thumbnailFile == null)
                const SizedBox(height: AppSpacing.sm),

              // ── Thumbnail picker ──────────────────────────────────────────
              FieldCard(
                label: 'Replace Thumbnail (optional)',
                child: FilePicker(
                  icon: Icons.image_outlined,
                  label: _thumbnailFile != null
                      ? _thumbnailFile!.path.split('/').last
                      : 'Choose a new thumbnail image',
                  onTap: _saving ? null : _pickThumbnail,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Title ─────────────────────────────────────────────────────
              FieldCard(
                label: 'Title *',
                child: TextField(
                  controller: _titleController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  decoration: videoFieldDecoration('Enter video title'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Description ───────────────────────────────────────────────
              FieldCard(
                label: 'Description',
                child: TextField(
                  controller: _descriptionController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  maxLines: 4,
                  minLines: 2,
                  decoration: videoFieldDecoration('Describe your video…'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Visibility ────────────────────────────────────────────────
              FieldCard(
                label: 'Visibility',
                child: FormDropdownRow<String>(
                  value: _visibility,
                  items: const <String>['public', 'private'],
                  onChanged:
                      _saving ? null : (v) => setState(() => _visibility = v!),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Access type ───────────────────────────────────────────────
              FieldCard(
                label: 'Access Type',
                child: FormDropdownRow<String>(
                  value: _accessType,
                  items: const <String>['free', 'membership'],
                  onChanged:
                      _saving ? null : (v) => setState(() => _accessType = v!),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Category ──────────────────────────────────────────────────
              FieldCard(
                label: 'Category (optional)',
                child: TextField(
                  controller: _categoryController,
                  cursorColor: AppColors.brandGold,
                  style: AppTextStyles.body,
                  decoration: videoFieldDecoration('e.g. technology'),
                ),
              ),

              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                FormErrorBanner(message: _error!),
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
                        'Save Changes',
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
