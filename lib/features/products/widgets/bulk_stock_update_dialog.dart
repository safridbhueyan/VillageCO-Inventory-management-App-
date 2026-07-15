import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../products_controller.dart';

class BulkStockUpdateDialog extends ConsumerStatefulWidget {
  final List<String> selectedIds;
  final VoidCallback onApply;

  const BulkStockUpdateDialog({
    super.key,
    required this.selectedIds,
    required this.onApply,
  });

  @override
  ConsumerState<BulkStockUpdateDialog> createState() => _BulkStockUpdateDialogState();
}

class _BulkStockUpdateDialogState extends ConsumerState<BulkStockUpdateDialog> {
  final qtyController = TextEditingController();
  String reason = 'স্টক সমন্বয়';

  @override
  void dispose() {
    qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('সব পণ্যের স্টক পরিবর্তন'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('সিলেক্ট করা ${widget.selectedIds.length}টি পণ্যের স্টক সমন্বয় করুন। যোগ করতে পজিটিভ নম্বর এবং কমাতে মাইনাস (-) নম্বর লিখুন।'),
          const SizedBox(height: 16),
          TextField(
            controller: qtyController,
            decoration: const InputDecoration(
              labelText: 'পরিবর্তনের পরিমাণ',
              hintText: 'যেমন: ১০ বা -৫',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: reason,
            decoration: const InputDecoration(labelText: 'কারণ', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'স্টক সমন্বয়', child: Text('স্টক সমন্বয়')),
              DropdownMenuItem(value: 'নতুন স্টক যোগ', child: Text('নতুন স্টক যোগ')),
              DropdownMenuItem(value: 'স্টক আউট/ক্ষতি', child: Text('স্টক আউট/ক্ষতি')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => reason = val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(qtyController.text);
            if (amt != null) {
              ref.read(productsRepositoryProvider).bulkStockUpdate(widget.selectedIds, amt, reason);
              Navigator.pop(context);
              widget.onApply();
            }
          },
          child: const Text('প্রয়োগ করুন'),
        ),
      ],
    );
  }
}
