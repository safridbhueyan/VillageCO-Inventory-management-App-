import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/firebase_sync_service.dart';
import '../settings_screen.dart';
import '../settings_controller.dart';

class ShopProfileSettings extends ConsumerWidget {
  final AppSettingsTableData settings;
  final TextEditingController shopNameController;
  final TextEditingController taxRateController;
  final TextEditingController pinController;

  const ShopProfileSettings({
    key,
    required this.settings,
    required this.shopNameController,
    required this.taxRateController,
    required this.pinController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ডিসপ্লে ও থিম', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('ডার্ক থিম মোড'),
            subtitle: const Text('সাদা বা কালো স্ক্রিন মোড পরিবর্তন করুন'),
            trailing: Switch(
              value: settings.isDarkMode,
              onChanged: (val) {
                ref.read(settingsControllerProvider.notifier).setDarkMode(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text('দোকানের প্রোফাইল', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: shopNameController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'দোকানের নাম', 
                    border: OutlineInputBorder(),
                    helperText: 'দোকানের নাম শুধুমাত্র সুপার অ্যাডমিন পরিবর্তন করতে পারবেন।',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: ref.watch(settingsSelectedCurrencyProvider),
                        decoration: const InputDecoration(labelText: 'মুদ্রার প্রতীক', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'BDT', child: Text('BDT (৳)')),
                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                        ],
                        onChanged: (val) {
                          if (val != null) ref.read(settingsSelectedCurrencyProvider.notifier).state = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: taxRateController,
                        decoration: const InputDecoration(
                          labelText: 'ভ্যাট হার (%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = shopNameController.text.trim();
                      final tax = double.tryParse(taxRateController.text) ?? 0.0;
                      if (name.isNotEmpty) {
                        ref.read(firebaseSyncServiceProvider).clearIdCache();
                        await ref.read(settingsControllerProvider.notifier).updateShopDetails(
                              name,
                              tax,
                              ref.read(settingsSelectedCurrencyProvider),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('দোকানের প্রোফাইল আপডেট করা হয়েছে!')),
                          );
                        }
                      }
                    },
                    child: const Text('প্রোফাইল সংরক্ষণ করুন'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text('নিরাপত্তা ও অ্যাডমিন পিন', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('৪-সংখ্যার অ্যাডমিন পিন পরিবর্তন করুন', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pinController,
                        decoration: const InputDecoration(
                          labelText: 'নতুন ৪-সংখ্যার পিন',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                      onPressed: () async {
                        final pin = pinController.text.trim();
                        if (pin.length == 4 && int.tryParse(pin) != null) {
                          await ref.read(settingsControllerProvider.notifier).setAdminPin(pin);
                          pinController.clear();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('অ্যাডমিন পিন পরিবর্তন হয়েছে!')),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('পিন ৪ সংখ্যার হতে হবে!')),
                            );
                          }
                        }
                      },
                      child: const Text('পিন পরিবর্তন'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
