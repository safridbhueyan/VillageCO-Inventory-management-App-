import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../suppliers_controller.dart';

class AddDamageDialog extends ConsumerStatefulWidget {
  final String supplierId;

  const AddDamageDialog({super.key, required this.supplierId});

  @override
  ConsumerState<AddDamageDialog> createState() => _AddDamageDialogState();
}

class _AddDamageDialogState extends ConsumerState<AddDamageDialog> {
  final qtyController = TextEditingController();
  final notesController = TextEditingController();
  String? selectedProdId;
  String status = 'Pending Replacement';

  @override
  void dispose() {
    qtyController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsBySupplierProvider(widget.supplierId));

    return AlertDialog(
      title: const Text('ক্ষতিগ্রস্ত পণ্য রেকর্ড লোগ করুন'),
      content: productsAsync.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (err, st) => Text('Error loading products: $err'),
        data: (products) {
          if (products.isEmpty) {
            return const Text('ক্ষতিগ্রস্ত পণ্য রেকর্ড করতে প্রথমে এই সরবরাহকারীর অধীনে পণ্য যুক্ত করুন।');
          }

          return StatefulBuilder(
            builder: (context, setDlgState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProdId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'পণ্য সিলেক্ট করুন *', border: OutlineInputBorder()),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (val) => setDlgState(() => selectedProdId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: 'ক্ষতিগ্রস্ত সংখ্যা *', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'মীমাংসা স্ট্যাটাস', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Pending Replacement', child: Text('Pending Replacement (প্রতিস্থাপন অপেক্ষমান)')),
                      DropdownMenuItem(value: 'Replaced', child: Text('Replaced (প্রতিস্থাপিত)')),
                      DropdownMenuItem(value: 'Pending Refund', child: Text('Pending Refund (ফেরত অপেক্ষমান)')),
                      DropdownMenuItem(value: 'Refunded', child: Text('Refunded (ফেরতকৃত)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => status = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'অতিরিক্ত নোট (ঐচ্ছিক)', border: OutlineInputBorder()),
                  ),
                ],
              );
            },
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () {
            if (selectedProdId == null) return;
            final qty = double.tryParse(qtyController.text) ?? 0.0;
            if (qty <= 0) return;

            ref.read(suppliersControllerProvider.notifier).addDamagedItem(
              supplierId: widget.supplierId,
              productId: selectedProdId!,
              quantity: qty,
              status: status,
              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
            );
            Navigator.pop(context);
          },
          child: const Text('রেকর্ড করুন'),
        ),
      ],
    );
  }
}
