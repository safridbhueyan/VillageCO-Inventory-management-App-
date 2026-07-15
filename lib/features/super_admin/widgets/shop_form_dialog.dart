import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_controller.dart';
import '../super_admin_screen.dart';

class ShopFormDialog extends ConsumerStatefulWidget {
  final String? storeDocId;
  final String? currentName;
  final String? currentPin;
  final String? currentCurrency;
  final double? currentTax;

  const ShopFormDialog({
    super.key,
    this.storeDocId,
    this.currentName,
    this.currentPin,
    this.currentCurrency,
    this.currentTax,
  });

  @override
  ConsumerState<ShopFormDialog> createState() => _ShopFormDialogState();
}

class _ShopFormDialogState extends ConsumerState<ShopFormDialog> {
  late final TextEditingController nameController;
  late final TextEditingController pinController;
  late final TextEditingController taxController;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentName);
    pinController = TextEditingController(text: widget.currentPin);
    taxController = TextEditingController(text: widget.currentTax?.toString() ?? '0.0');
    
    // Schedule updating provider state safely
    Future.microtask(() {
      ref.read(superAdminDialogCurrencyProvider.notifier).state = widget.currentCurrency ?? 'BDT';
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    pinController.dispose();
    taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.storeDocId == null ? 'নতুন শপ তৈরি করুন' : 'শপ এডিট করুন',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'দোকানের নাম',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'নাম খালি হতে পারে না'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pinController,
                decoration: const InputDecoration(
                  labelText: 'অ্যাডমিন পিন (৪ সংখ্যা)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                maxLength: 4,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null ||
                        v.trim().length != 4 ||
                        int.tryParse(v) == null
                    ? 'সঠিক ৪ সংখ্যার পিন দিন'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ref.watch(superAdminDialogCurrencyProvider),
                decoration: const InputDecoration(
                  labelText: 'কারেন্সি',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'BDT', child: Text('BDT (৳)')),
                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(superAdminDialogCurrencyProvider.notifier).state = val;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: taxController,
                decoration: const InputDecoration(
                  labelText: 'ভ্যাট হার (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'সঠিক সংখ্যা লিখুন'
                    : null,
              ),
            ],
          ),
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
              final pin = pinController.text.trim();
              final tax = double.parse(taxController.text);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final adminRepo = ref.read(adminRepositoryProvider);
                if (widget.storeDocId == null) {
                  await adminRepo.createShop(
                    name: name,
                    pin: pin,
                    currency: ref.read(superAdminDialogCurrencyProvider),
                    taxRate: tax,
                  );
                } else {
                  await adminRepo.editShop(
                    storeDocId: widget.storeDocId!,
                    newName: name,
                    newPin: pin,
                    currency: ref.read(superAdminDialogCurrencyProvider),
                    taxRate: tax,
                  );
                }
                if (context.mounted) {
                  Navigator.pop(context); // loading
                  Navigator.pop(context); // dialog
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
                }
              }
            }
          },
          child: const Text('সংরক্ষণ করুন'),
        ),
      ],
    );
  }
}
