import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:villageco/features/home/home_actions.dart';

import '../../core/database/database.dart';
import 'settings_controller.dart';
import 'widgets/shop_profile_settings.dart';
import 'widgets/category_management_dialog.dart';
import 'widgets/backup_data_settings.dart';
import 'widgets/storage_locations_settings.dart';
import 'widgets/firebase_sync_settings.dart';

final settingsSelectedCurrencyProvider = StateProvider.autoDispose<String>(
  (ref) => 'BDT',
);
final settingsIsSyncingProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
final settingsLastSyncTimeProvider = StateProvider.autoDispose<DateTime?>(
  (ref) => null,
);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _shopNameController.dispose();
    _taxRateController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppSettingsTableData>>(settingsControllerProvider, (
      prev,
      next,
    ) {
      next.whenData((settings) {
        _shopNameController.text = settings.shopName;
        _taxRateController.text = settings.taxRate.toString();

        const allowedCurrencies = ['BDT', 'USD', 'EUR'];
        ref
            .read(settingsSelectedCurrencyProvider.notifier)
            .state = allowedCurrencies.contains(settings.currency)
            ? settings.currency
            : 'USD';
      });
    });

    final settingsAsync = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'অ্যাপ সেটিংস ও ব্যাকআপ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('সেটিংস লোড করতে ত্রুটি: $err')),
        data: (settings) {
          if (_shopNameController.text.isEmpty) {
            _shopNameController.text = settings.shopName;
            _taxRateController.text = settings.taxRate.toString();

            const allowedCurrencies = ['BDT', 'USD', 'EUR'];
            final initialCurrency =
                allowedCurrencies.contains(settings.currency)
                ? settings.currency
                : 'USD';
            Future.microtask(() {
              ref.read(settingsSelectedCurrencyProvider.notifier).state =
                  initialCurrency;
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopProfileSettings(
                  settings: settings,
                  shopNameController: _shopNameController,
                  taxRateController: _taxRateController,
                  pinController: _pinController,
                ),
                const SizedBox(height: 24),
                Text(
                  'পণ্যের ক্যাটাগরি',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('পণ্যের ক্যাটাগরি ম্যানেজ করুন'),
                    subtitle: const Text(
                      'নতুন ক্যাটাগরি তৈরি, সংশোধন বা মুছে ফেলুন',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => const CategoryManagementDialog(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const BackupDataSettings(),
                const SizedBox(height: 24),
                StorageLocationsSettings(settings: settings),
                const SizedBox(height: 24),
                FirebaseSyncSettings(settings: settings),
                const SizedBox(height: 24),
                Text(
                  'সেশন ও লগআউট',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'লগআউট ও দৈনিক ক্লোজিং রিপোর্ট',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'লগআউট করুন এবং আজকের দৈনিক লেনদেনের PDF রিপোর্ট সংরক্ষণ করুন',
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.red,
                          ),
                          onTap: () =>
                              logoutAndGenerateClosingReport(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
