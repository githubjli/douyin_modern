import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../data/shipping_address_repository.dart';
import '../domain/shipping_address.dart';
import 'address_form_page.dart';

/// Address list page with two modes:
///
/// * **selection mode** (`selectionMode: true`) — tapping an address pops the
///   page with that [ShippingAddress]. Used from the purchase confirmation sheet.
/// * **management mode** (`selectionMode: false`) — tapping an address opens
///   the edit form. Used from profile / settings.
class AddressListPage extends ConsumerStatefulWidget {
  const AddressListPage({
    super.key,
    this.selectionMode = false,
    this.selectedId,
  });

  final bool selectionMode;

  /// Pre-selected address id (highlight in selection mode).
  final int? selectedId;

  @override
  ConsumerState<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends ConsumerState<AddressListPage> {
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
  }

  Future<void> _delete(ShippingAddress address) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete Address',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
        ),
        content: Text(
          'Remove the address for ${address.receiverName}?',
          style: AppTextStyles.body.copyWith(color: AppColors.mutedOliveText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.caption.copyWith(color: AppColors.cocoaText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.caption.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(shippingAddressRepositoryProvider)
          .deleteAddress(address.id);
      ref.invalidate(shippingAddressListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openForm({ShippingAddress? existing}) async {
    final ShippingAddress? result = await Navigator.of(context).push<ShippingAddress>(
      MaterialPageRoute<ShippingAddress>(
        builder: (_) => AddressFormPage(existing: existing),
      ),
    );
    if (result != null) {
      // List is already invalidated inside AddressFormPage on save.
      setState(() {
        if (widget.selectionMode) _selectedId = result.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ShippingAddress>> addressesAsync =
        ref.watch(shippingAddressListProvider);

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.cocoaText,
        elevation: 0,
        title: Text(
          widget.selectionMode ? 'Select Address' : 'My Addresses',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
        ),
        actions: <Widget>[
          if (widget.selectionMode)
            TextButton(
              onPressed: () {
                // Confirm current selection (or null if nothing chosen)
                final List<ShippingAddress> list =
                    addressesAsync.value ?? <ShippingAddress>[];
                final ShippingAddress? chosen = _selectedId == null
                    ? null
                    : list.where((ShippingAddress a) => a.id == _selectedId).firstOrNull;
                Navigator.of(context).pop(chosen);
              },
              child: Text(
                'Confirm',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.brandGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.brandGold,
        foregroundColor: AppColors.warmBackground,
        child: const Icon(Icons.add_rounded),
      ),
      body: addressesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brandGold),
        ),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Failed to load addresses',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.mutedOliveText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => ref.invalidate(shippingAddressListProvider),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.brandGold),
                ),
              ),
            ],
          ),
        ),
        data: (List<ShippingAddress> addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.location_off_outlined,
                    size: 48,
                    color: AppColors.mutedOliveText,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No saved addresses',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.mutedOliveText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: () => _openForm(),
                    child: const Text(
                      'Add one now',
                      style: TextStyle(color: AppColors.brandGold),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              96, // room for FAB
            ),
            itemCount: addresses.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final ShippingAddress a = addresses[index];
              final bool isSelected = _selectedId == a.id;
              return _AddressCard(
                address: a,
                selectionMode: widget.selectionMode,
                isSelected: isSelected,
                onTap: () {
                  if (widget.selectionMode) {
                    setState(() => _selectedId = a.id);
                  } else {
                    _openForm(existing: a);
                  }
                },
                onEdit: () => _openForm(existing: a),
                onDelete: () => _delete(a),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Address card
// ---------------------------------------------------------------------------

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ShippingAddress address;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool highlight = selectionMode && isSelected;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: highlight ? AppColors.brandGold : AppColors.softBorder,
            width: highlight ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Selection indicator
            if (selectionMode) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1, right: AppSpacing.sm),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? AppColors.brandGold
                      : AppColors.mutedOliveText,
                  size: 20,
                ),
              ),
            ],

            // Address info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        address.receiverName,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.cocoaText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        address.phone,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mutedOliveText,
                        ),
                      ),
                      if (address.isDefault) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        _DefaultBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.oneLine,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mutedOliveText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons (management mode)
            if (!selectionMode) ...<Widget>[
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.mutedOliveText,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.mutedOliveText,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Default',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.brandGold,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
