import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pos_controller.dart';

class PosDiscountDialog extends ConsumerWidget {
  final PosCartState cart;

  const PosDiscountDialog({
    super.key,
    required this.cart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountController = TextEditingController(text: cart.discount.toString());

    return AlertDialog(
      title: const Text('অর্ডার ডিসকাউন্ট (টাকা)'),
      content: TextField(
        controller: discountController,
        decoration: const InputDecoration(
          labelText: 'ডিসকাউন্টের পরিমাণ (৳)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () {
            discountController.clear();
            ref.read(posCartProvider.notifier).applyDiscount(0.0);
            Navigator.pop(context);
          },
          child: const Text('ডিসকাউন্ট মুছুন', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(discountController.text) ?? 0.0;
            ref.read(posCartProvider.notifier).applyDiscount(amt, isPercentage: false);
            Navigator.pop(context);
          },
          child: const Text('প্রয়োগ করুন'),
        ),
      ],
    );
  }
}
