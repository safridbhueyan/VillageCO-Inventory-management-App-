import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../products_controller.dart';
import 'product_form_image_picker.dart';
import 'product_form_basic_fields.dart';
import 'product_form_stock_pricing_fields.dart';

class ProductFormSheet extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormSheet({
    super.key,
    this.product,
  });

  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  late final bool isEdit;
  late final TextEditingController nameController;
  late final TextEditingController brandController;
  late final TextEditingController barcodeController;
  late final TextEditingController buyPriceController;
  late final TextEditingController sellPriceController;
  late final TextEditingController stockController;
  late final TextEditingController minStockController;
  late final TextEditingController descController;
  late final TextEditingController batchController;

  DateTime? selectedExpiryDate;
  late String selectedUnit;
  String? selectedCategoryId;
  String? selectedSupplierId;
  String? imagePath;
  String? nameError;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    isEdit = p != null;
    nameController = TextEditingController(text: p?.name);
    brandController = TextEditingController(text: p?.brand);
    barcodeController = TextEditingController(text: p?.barcode);
    buyPriceController = TextEditingController(text: p?.buyingPrice.toString());
    sellPriceController = TextEditingController(text: p?.sellingPrice.toString());
    stockController = TextEditingController(text: p?.currentStock.toString());
    minStockController = TextEditingController(text: p?.minimumStock.toString());
    descController = TextEditingController(text: p?.description);
    batchController = TextEditingController(text: p?.batchNumber);

    selectedExpiryDate = p?.expiryDate;
    selectedUnit = p?.unit ?? 'pcs';
    selectedCategoryId = p?.categoryId;
    selectedSupplierId = p?.supplierId;
    imagePath = p?.imagePath;
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    barcodeController.dispose();
    buyPriceController.dispose();
    sellPriceController.dispose();
    stockController.dispose();
    minStockController.dispose();
    descController.dispose();
    batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'পণ্যের বিবরণ সংশোধন' : 'নতুন পণ্য যোগ করুন',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    ProductFormImagePicker(
                      imagePath: imagePath,
                      onImageSelected: (val) => setState(() => imagePath = val),
                    ),
                    const SizedBox(height: 16),
                    ProductFormBasicFields(
                      nameController: nameController,
                      barcodeController: barcodeController,
                      brandController: brandController,
                      selectedUnit: selectedUnit,
                      onUnitChanged: (val) => setState(() => selectedUnit = val),
                      selectedCategoryId: selectedCategoryId,
                      onCategoryChanged: (val) => setState(() => selectedCategoryId = val),
                      selectedSupplierId: selectedSupplierId,
                      onSupplierChanged: (val) => setState(() => selectedSupplierId = val),
                      nameError: nameError,
                    ),
                    const SizedBox(height: 12),
                    ProductFormStockPricingFields(
                      buyPriceController: buyPriceController,
                      sellPriceController: sellPriceController,
                      batchController: batchController,
                      selectedExpiryDate: selectedExpiryDate,
                      onExpiryDateChanged: (val) => setState(() => selectedExpiryDate = val),
                      stockController: stockController,
                      minStockController: minStockController,
                      descController: descController,
                      isEdit: isEdit,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('বাতিল'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      setState(() {
                        nameError = 'পণ্যের নাম আবশ্যক';
                      });
                      return;
                    }
                    final buyVal = double.tryParse(buyPriceController.text) ?? 0.0;
                    final sellVal = double.tryParse(sellPriceController.text) ?? 0.0;
                    final stockVal = double.tryParse(stockController.text) ?? 0.0;
                    final minVal = double.tryParse(minStockController.text) ?? 0.0;

                    final repo = ref.read(productsRepositoryProvider);

                    if (isEdit) {
                      final comp = ProductsCompanion(
                        name: drift.Value(nameController.text.trim()),
                        barcode: drift.Value(barcodeController.text.trim().isEmpty ? null : barcodeController.text.trim()),
                        brand: drift.Value(brandController.text.trim().isEmpty ? null : brandController.text.trim()),
                        categoryId: drift.Value(selectedCategoryId),
                        supplierId: drift.Value(selectedSupplierId),
                        unit: drift.Value(selectedUnit),
                        buyingPrice: drift.Value(buyVal),
                        sellingPrice: drift.Value(sellVal),
                        minimumStock: drift.Value(minVal),
                        imagePath: drift.Value(imagePath),
                        description: drift.Value(descController.text.trim().isEmpty ? null : descController.text.trim()),
                        batchNumber: drift.Value(batchController.text.trim().isEmpty ? null : batchController.text.trim()),
                        expiryDate: drift.Value(selectedExpiryDate),
                      );
                      repo.updateProduct(widget.product!.id, comp);
                    } else {
                      final newId = const Uuid().v4();
                      final comp = ProductsCompanion(
                        id: drift.Value(newId),
                        name: drift.Value(nameController.text.trim()),
                        barcode: drift.Value(barcodeController.text.trim().isEmpty ? null : barcodeController.text.trim()),
                        brand: drift.Value(brandController.text.trim().isEmpty ? null : brandController.text.trim()),
                        categoryId: drift.Value(selectedCategoryId),
                        supplierId: drift.Value(selectedSupplierId),
                        unit: drift.Value(selectedUnit),
                        buyingPrice: drift.Value(buyVal),
                        sellingPrice: drift.Value(sellVal),
                        currentStock: drift.Value(stockVal),
                        minimumStock: drift.Value(minVal),
                        imagePath: drift.Value(imagePath),
                        description: drift.Value(descController.text.trim().isEmpty ? null : descController.text.trim()),
                        batchNumber: drift.Value(batchController.text.trim().isEmpty ? null : batchController.text.trim()),
                        expiryDate: drift.Value(selectedExpiryDate),
                      );
                      repo.addProduct(comp);
                    }

                    Navigator.pop(context);
                  },
                  child: const Text('সংরক্ষণ করুন'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
