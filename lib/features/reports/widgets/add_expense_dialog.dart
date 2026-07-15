import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../reports_controller.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  final descController = TextEditingController();
  String selectedCategory = 'Rent';
  DateTime selectedDate = DateTime.now();

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('নতুন খরচ লিখুন'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'খরচের নাম/খাত *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'খরচের পরিমাণ (টাকা) *',
                prefixText: '৳',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'ক্যাটাগরি',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Rent', child: Text('দোকান ভাড়া')),
                DropdownMenuItem(value: 'Electricity', child: Text('বিদ্যুৎ বিল')),
                DropdownMenuItem(value: 'Internet', child: Text('ইন্টারনেট বিল')),
                DropdownMenuItem(value: 'Transport', child: Text('পরিবহন ভাড়া')),
                DropdownMenuItem(value: 'Salary', child: Text('কর্মচারী বেতন')),
                DropdownMenuItem(value: 'Misc', child: Text('অন্যান্য খরচ')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => selectedCategory = val);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('খরচের তারিখ'),
              subtitle: Text(Formatters.date(selectedDate)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (dt != null) setState(() => selectedDate = dt);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'বিবরণ (ঐচ্ছিক)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            final amt = double.tryParse(amountController.text) ?? 0.0;
            if (name.isEmpty || amt <= 0) return;

            ref.read(expensesControllerProvider.notifier).addExpense(
                  name,
                  amt,
                  selectedCategory,
                  selectedDate,
                  descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
            Navigator.pop(context);
          },
          child: const Text('সংরক্ষণ করুন'),
        ),
      ],
    );
  }
}
