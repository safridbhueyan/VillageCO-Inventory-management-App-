import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../categories/categories_controller.dart';
import '../../suppliers/suppliers_controller.dart';

class ProductFormBasicFields extends ConsumerWidget {
  final TextEditingController nameController;
  final TextEditingController barcodeController;
  final TextEditingController brandController;
  final String selectedUnit;
  final ValueChanged<String> onUnitChanged;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final String? selectedSupplierId;
  final ValueChanged<String?> onSupplierChanged;
  final String? nameError;

  const ProductFormBasicFields({
    super.key,
    required this.nameController,
    required this.barcodeController,
    required this.brandController,
    required this.selectedUnit,
    required this.onUnitChanged,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.selectedSupplierId,
    required this.onSupplierChanged,
    this.nameError,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesControllerProvider);
    final suppliersAsync = ref.watch(suppliersControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'পণ্যের নাম *',
            border: const OutlineInputBorder(),
            errorText: nameError,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'বারকোড (ঐচ্ছিক)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'বারকোড জেনারেট',
              onPressed: () {
                final randomBarcode = List.generate(12, (_) => (const Uuid().v4().hashCode % 10).toString()).join();
                barcodeController.text = randomBarcode;
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: brandController,
                decoration: const InputDecoration(labelText: 'ব্র্যান্ড/লেবেল (ঐচ্ছিক)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedUnit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'একক', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'pcs', child: Text('টি (pcs)')),
                  DropdownMenuItem(value: 'kg', child: Text('কেজি (kg)')),
                  DropdownMenuItem(value: 'pack', child: Text('প্যাকেট (pack)')),
                  DropdownMenuItem(value: 'liter', child: Text('লিটার (liter)')),
                  DropdownMenuItem(value: 'bag', child: Text('ব্যাগ (bag)')),
                ],
                onChanged: (val) {
                  if (val != null) onUnitChanged(val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        categoriesAsync.maybeWhen(
          data: (categories) {
            final hasCategory = categories.any((c) => c.id == selectedCategoryId);
            return DropdownButtonFormField<String>(
              value: hasCategory ? selectedCategoryId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'ক্যাটাগরি সিলেক্ট করুন', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('ক্যাটাগরি ছাড়া')),
                ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: onCategoryChanged,
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        suppliersAsync.maybeWhen(
          data: (suppliers) {
            final hasSupplier = suppliers.any((s) => s.id == selectedSupplierId);
            return DropdownButtonFormField<String>(
              value: hasSupplier ? selectedSupplierId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'সরবরাহকারী (Supplier) সিলেক্ট করুন', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('সরবরাহকারী ছাড়া')),
                ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
              ],
              onChanged: onSupplierChanged,
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
