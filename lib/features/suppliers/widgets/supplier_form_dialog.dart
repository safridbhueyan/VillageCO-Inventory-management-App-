import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/image_utils.dart';
import '../suppliers_controller.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  final Supplier? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController addressController;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.supplier?.name);
    phoneController = TextEditingController(text: widget.supplier?.phone);
    emailController = TextEditingController(text: widget.supplier?.email);
    addressController = TextEditingController(text: widget.supplier?.address);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEdit ? 'Update Supplier Details' : 'Register Supplier Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (widget.supplier?.imagePath != null
                            ? (widget.supplier!.imagePath!.startsWith('http')
                                ? NetworkImage(widget.supplier!.imagePath!) as ImageProvider
                                : FileImage(File(widget.supplier!.imagePath!)))
                            : null),
                    child: _imageFile == null && widget.supplier?.imagePath == null
                        ? Icon(Icons.local_shipping, size: 40, color: theme.colorScheme.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primary,
                      child: GestureDetector(
                        onTap: () async {
                          final file = await ImageUtils.pickAndCropImage(context);
                          if (file != null) {
                            setState(() {
                              _imageFile = file;
                            });
                          }
                        },
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Supplier Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Office Address', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            final phone = phoneController.text.trim();
            if (name.isEmpty || phone.isEmpty) return;

            final notifier = ref.read(suppliersControllerProvider.notifier);
            if (isEdit) {
              notifier.updateSupplier(
                widget.supplier!.id,
                name,
                phone,
                emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                localImagePath: _imageFile?.path,
              );
            } else {
              notifier.addSupplier(
                name,
                phone,
                emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                localImagePath: _imageFile?.path,
              );
            }
            Navigator.pop(context);
          },
          child: Text(isEdit ? 'Update' : 'Register'),
        ),
      ],
    );
  }
}
