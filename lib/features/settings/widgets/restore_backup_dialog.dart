import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/categories_controller.dart';
import '../../products/products_controller.dart';
import '../../reports/reports_controller.dart';
import '../../suppliers/suppliers_controller.dart';
import '../settings_controller.dart';

class RestoreBackupDialog extends ConsumerStatefulWidget {
  const RestoreBackupDialog({super.key});

  @override
  ConsumerState<RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends ConsumerState<RestoreBackupDialog> {
  final inputController = TextEditingController();

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ব্যাকআপ থেকে ডেটা রিস্টোর করুন'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('পূর্বে এক্সপোর্ট করা ডেটা ফাইলে থাকা JSON লেখাটি নিচে পেস্ট করুন।'),
          const SizedBox(height: 12),
          TextField(
            controller: inputController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'এখানে ব্যাকআপ JSON পেস্ট করুন...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () async {
            final json = inputController.text.trim();
            if (json.isEmpty) return;

            try {
              await ref.read(settingsControllerProvider.notifier).importFromJson(json);
              ref.invalidate(productsListProvider);
              ref.invalidate(categoriesControllerProvider);
              ref.invalidate(suppliersControllerProvider);
              ref.invalidate(salesHistoryProvider);
              ref.invalidate(dashboardMetricsProvider);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ডেটা সফলভাবে পুনরুদ্ধার করা হয়েছে!')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('JSON ব্যাকআপ ফাইলটি সঠিক নয়: $e')),
                );
              }
            }
          },
          child: const Text('রিস্টোর করুন'),
        ),
      ],
    );
  }
}
