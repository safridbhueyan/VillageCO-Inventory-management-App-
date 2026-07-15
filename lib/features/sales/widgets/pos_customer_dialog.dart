import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/firebase_sync_service.dart';
import '../pos_controller.dart';
import '../pos_screen.dart';

class PosCustomerDialog extends ConsumerWidget {
  const PosCustomerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return AlertDialog(
      title: const Text('নতুন কাস্টমার যোগ করুন'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'কাস্টমারের নাম (Name)',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'নাম লিখুন' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'মোবাইল নাম্বার (Mobile Number)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (val) => val == null || val.trim().isEmpty ? 'মোবাইল নাম্বার লিখুন' : null,
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
          onPressed: () async {
            if (formKey.currentState?.validate() ?? false) {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final id = const Uuid().v4();

              final db = ref.read(databaseProvider);
              final customer = Customer(id: id, name: name, phone: phone);

              await db.into(db.customers).insert(customer);

              // Refresh list
              ref.invalidate(posCustomersListProvider);
              triggerAutoSync(ref);

              // Select the new customer
              ref.read(posCartProvider.notifier).setCustomer(customer);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name কাস্টমার হিসেবে যোগ করা হয়েছে')),
                );
              }
            }
          },
          child: const Text('যোগ করুন'),
        ),
      ],
    );
  }
}
