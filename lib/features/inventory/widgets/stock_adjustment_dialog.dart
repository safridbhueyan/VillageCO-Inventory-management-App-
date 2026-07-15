import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../products/products_controller.dart';
import '../../suppliers/suppliers_controller.dart';
import '../inventory_controller.dart';
import 'stock_in_fields.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  const StockAdjustmentDialog({super.key});

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final amountController = TextEditingController();
  final costController = TextEditingController();
  final invoiceController = TextEditingController();
  final batchController = TextEditingController();
  DateTime? selectedExpiryDate;

  String selectedType = 'Stock In'; // 'Stock In', 'Stock Out', 'Adjust Stock'
  String? selectedProductId;
  String? selectedSupplierId;
  String reason = 'ক্রয়';

  @override
  void dispose() {
    amountController.dispose();
    costController.dispose();
    invoiceController.dispose();
    batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final suppliersAsync = ref.watch(suppliersControllerProvider);

    return AlertDialog(
      title: const Text('স্টক পরিবর্তন নথিভুক্ত করুন'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product selector
              productsAsync.maybeWhen(
                data: (products) => DropdownButtonFormField<String>(
                  value: selectedProductId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'পণ্য সিলেক্ট করুন *', border: OutlineInputBorder()),
                  items: products.map((p) {
                    return DropdownMenuItem(
                      value: p.product.id,
                      child: Text('${p.product.name} (বর্তমান: ${Formatters.number(p.product.currentStock)} ${p.product.unit})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedProductId = val),
                ),
                orElse: () => const Text('পণ্য লোড হচ্ছে...'),
              ),
              const SizedBox(height: 12),
              // Transaction Type
              DropdownButtonFormField<String>(
                value: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'পরিবর্তনের ধরন', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Stock In', child: Text('স্টক যোগ করুন (Stock In)')),
                  DropdownMenuItem(value: 'Stock Out', child: Text('স্টক কমান (Stock Out)')),
                  DropdownMenuItem(value: 'Adjust Stock', child: Text('সরাসরি স্টক সেট করুন')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedType = val;
                      if (val == 'Stock In') reason = 'ক্রয়';
                      if (val == 'Stock Out') reason = 'নষ্ট/ক্ষতি';
                      if (val == 'Adjust Stock') reason = 'স্টক গণনা';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              // Quantity
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: selectedType == 'Adjust Stock' ? 'নতুন মোট স্টক সংখ্যা *' : 'পরিমাণ *',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              // Reason Dropdown
              DropdownButtonFormField<String>(
                value: reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'কারণ', border: OutlineInputBorder()),
                items: selectedType == 'Stock In'
                    ? const [
                        DropdownMenuItem(value: 'ক্রয়', child: Text('নতুন ক্রয়')),
                        DropdownMenuItem(value: 'ফেরত', child: Text('কাস্টমার ফেরত')),
                        DropdownMenuItem(value: 'অন্যান্য', child: Text('অন্যান্য')),
                      ]
                    : (selectedType == 'Stock Out'
                        ? const [
                            DropdownMenuItem(value: 'নষ্ট/ক্ষতি', child: Text('নষ্ট / ভাঙা পণ্য')),
                            DropdownMenuItem(value: 'চুরি', child: Text('চুরি / হারানো')),
                            DropdownMenuItem(value: 'মেয়াদ শেষ', child: Text('মেয়াদোত্তীর্ণ পণ্য')),
                          ]
                        : const [
                            DropdownMenuItem(value: 'স্টক গণনা', child: Text('ভৌত স্টক গণনা')),
                            DropdownMenuItem(value: 'সংশোধন', child: Text('হিসাব সংশোধন')),
                          ]),
                onChanged: (val) {
                  if (val != null) setState(() => reason = val);
                },
              ),
              const SizedBox(height: 12),
              // Conditional fields for 'Stock In'
              if (selectedType == 'Stock In') ...[
                StockInFields(
                  suppliersAsync: suppliersAsync,
                  selectedSupplierId: selectedSupplierId,
                  onSupplierChanged: (val) => setState(() => selectedSupplierId = val),
                  costController: costController,
                  invoiceController: invoiceController,
                  batchController: batchController,
                  selectedExpiryDate: selectedExpiryDate,
                  onExpiryDateChanged: (val) => setState(() => selectedExpiryDate = val),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () async {
            if (selectedProductId == null) return;
            final amt = double.tryParse(amountController.text) ?? 0.0;
            if (amt <= 0) return;

            final repo = ref.read(productsRepositoryProvider);
            final db = ref.read(databaseProvider);

            double diff = 0.0;

            if (selectedType == 'Stock In') {
              diff = amt;
              if (selectedSupplierId != null) {
                final cost = double.tryParse(costController.text) ?? 0.0;
                await db.into(db.purchases).insert(
                  PurchasesCompanion(
                    id: drift.Value(const Uuid().v4()),
                    supplierId: drift.Value(selectedSupplierId!),
                    date: drift.Value(DateTime.now()),
                    cost: drift.Value(cost * amt),
                    quantity: drift.Value(amt),
                    invoiceNo: drift.Value(invoiceController.text.trim().isEmpty ? null : invoiceController.text.trim()),
                  ),
                );
              }
              await (db.update(db.products)..where((t) => t.id.equals(selectedProductId!))).write(
                ProductsCompanion(
                  batchNumber: drift.Value(batchController.text.trim().isEmpty ? null : batchController.text.trim()),
                  expiryDate: drift.Value(selectedExpiryDate),
                ),
              );
              await repo.adjustStock(selectedProductId!, diff, reason, supplierId: selectedSupplierId);
            } else if (selectedType == 'Stock Out') {
              diff = -amt;
              await repo.adjustStock(selectedProductId!, diff, reason);
            } else {
              final pList = productsAsync.value ?? [];
              final match = pList.firstWhere((p) => p.product.id == selectedProductId);
              diff = amt - match.product.currentStock;
              await repo.adjustStock(selectedProductId!, diff, reason);
            }

            ref.invalidate(stockHistoryListProvider);
            ref.invalidate(supplierPurchasesProvider);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('নিশ্চিত করুন'),
        ),
      ],
    );
  }
}
