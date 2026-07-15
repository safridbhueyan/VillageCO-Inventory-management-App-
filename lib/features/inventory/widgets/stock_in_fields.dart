import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/formatters.dart';

class StockInFields extends StatelessWidget {
  final AsyncValue<List<Supplier>> suppliersAsync;
  final String? selectedSupplierId;
  final ValueChanged<String?> onSupplierChanged;
  final TextEditingController costController;
  final TextEditingController invoiceController;
  final TextEditingController batchController;
  final DateTime? selectedExpiryDate;
  final ValueChanged<DateTime?> onExpiryDateChanged;

  const StockInFields({
    super.key,
    required this.suppliersAsync,
    required this.selectedSupplierId,
    required this.onSupplierChanged,
    required this.costController,
    required this.invoiceController,
    required this.batchController,
    required this.selectedExpiryDate,
    required this.onExpiryDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        suppliersAsync.maybeWhen(
          data: (suppliers) => DropdownButtonFormField<String>(
            value: selectedSupplierId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'সরবরাহকারী (ঐচ্ছিক)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('সরবরাহকারী ছাড়া')),
              ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
            ],
            onChanged: onSupplierChanged,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: costController,
                decoration: const InputDecoration(
                  labelText: 'ক্রয়মূল্য (ঐচ্ছিক)',
                  prefixText: '৳',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: invoiceController,
                decoration: const InputDecoration(
                  labelText: 'চালান নং (ঐচ্ছিক)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: batchController,
                decoration: const InputDecoration(
                  labelText: 'ব্যাচ নম্বর (ঐচ্ছিক)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) {
                    onExpiryDateChanged(picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'মেয়াদোত্তীর্ণের তারিখ (ঐচ্ছিক)',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedExpiryDate == null
                              ? 'সিলেক্ট করুন'
                              : Formatters.date(selectedExpiryDate!),
                          style: TextStyle(
                            color: selectedExpiryDate == null ? Colors.grey : null,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedExpiryDate != null)
                        GestureDetector(
                          onTap: () => onExpiryDateChanged(null),
                          child: const Icon(Icons.clear, size: 14),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
