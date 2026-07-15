import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';

class ProductFormStockPricingFields extends StatelessWidget {
  final TextEditingController buyPriceController;
  final TextEditingController sellPriceController;
  final TextEditingController batchController;
  final DateTime? selectedExpiryDate;
  final ValueChanged<DateTime?> onExpiryDateChanged;
  final TextEditingController stockController;
  final TextEditingController minStockController;
  final TextEditingController descController;
  final bool isEdit;

  const ProductFormStockPricingFields({
    super.key,
    required this.buyPriceController,
    required this.sellPriceController,
    required this.batchController,
    required this.selectedExpiryDate,
    required this.onExpiryDateChanged,
    required this.stockController,
    required this.minStockController,
    required this.descController,
    required this.isEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: buyPriceController,
                decoration: const InputDecoration(labelText: 'ক্রয়মূল্য (টাকা) *', border: OutlineInputBorder(), prefixText: '৳'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: sellPriceController,
                decoration: const InputDecoration(labelText: 'বিক্রয়মূল্য (টাকা) *', border: OutlineInputBorder(), prefixText: '৳'),
                keyboardType: TextInputType.number,
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
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedExpiryDate != null)
                        GestureDetector(
                          onTap: () => onExpiryDateChanged(null),
                          child: const Icon(Icons.clear, size: 16),
                        ),
                    ],
                  ),
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
                controller: stockController,
                enabled: !isEdit,
                decoration: InputDecoration(
                  labelText: isEdit ? 'স্টক পরিবর্তন হবে না' : 'প্রারম্ভিক স্টক *',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: minStockController,
                decoration: const InputDecoration(labelText: 'সর্বনিম্ন স্টক *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'পণ্যের বিবরণ (ঐচ্ছিক)', border: OutlineInputBorder()),
        ),
      ],
    );
  }
}
