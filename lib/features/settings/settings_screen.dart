import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/csv_helper.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/permission_utils.dart';
import 'settings_controller.dart';
import '../../widgets/shared/main_layout.dart';
import '../categories/categories_controller.dart';
import '../products/products_controller.dart';
import '../reports/reports_controller.dart';
import '../suppliers/suppliers_controller.dart';
import '../../core/database/firebase_sync_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedCurrency = 'BDT';
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppSettingsTableData>>(settingsControllerProvider, (prev, next) {
      next.whenData((settings) {
        _shopNameController.text = settings.shopName;
        _taxRateController.text = settings.taxRate.toString();
        _selectedCurrency = settings.currency;
      });
    });

    final settingsAsync = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('অ্যাপ সেটিংস ও ব্যাকআপ', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('সেটিংস লোড করতে ত্রুটি: $err')),
        data: (settings) {
          if (_shopNameController.text.isEmpty) {
            _shopNameController.text = settings.shopName;
            _taxRateController.text = settings.taxRate.toString();
            _selectedCurrency = settings.currency;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme settings section
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

                // Shop settings section
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
                          controller: _shopNameController,
                          decoration: const InputDecoration(labelText: 'দোকানের নাম', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCurrency,
                                decoration: const InputDecoration(labelText: 'মুদ্রার প্রতীক', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'BDT', child: Text('BDT (৳)')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCurrency = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _taxRateController,
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
                              final name = _shopNameController.text.trim();
                              final tax = double.tryParse(_taxRateController.text) ?? 0.0;
                              if (name.isNotEmpty) {
                                ref.read(firebaseSyncServiceProvider).clearIdCache();
                                await ref.read(settingsControllerProvider.notifier).updateShopDetails(
                                      name,
                                      tax,
                                      _selectedCurrency,
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

                // Category management shortcuts
                Text('পণ্যের ক্যাটাগরি', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('পণ্যের ক্যাটাগরি ম্যানেজ করুন'),
                    subtitle: const Text('নতুন ক্যাটাগরি তৈরি, সংশোধন বা মুছে ফেলুন'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _showCategoryManagementDialog(context),
                  ),
                ),
                const SizedBox(height: 24),

                // Security admin lock code
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
                                controller: _pinController,
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
                                final pin = _pinController.text.trim();
                                if (pin.length == 4 && int.tryParse(pin) != null) {
                                  await ref.read(settingsControllerProvider.notifier).setAdminPin(pin);
                                  _pinController.clear();
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
                const SizedBox(height: 24),

                Text('ব্যাকআপ ও ডেটা পুনরুদ্ধার', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('ডেটা ব্যাকআপ ফাইল এক্সপোর্ট (JSON)'),
                          subtitle: const Text('সম্পূর্ণ ডেটা একটি JSON ফাইলে সংরক্ষণ করুন'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.cloud_upload_outlined),
                            onPressed: () => _exportDatabaseBackup(context),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('ব্যাকআপ ফাইল রিস্টোর (JSON)'),
                          subtitle: const Text('পূর্বে এক্সপোর্ট করা JSON ফাইল দিয়ে ডেটা রিস্টোর করুন'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.cloud_download_outlined),
                            onPressed: () => _importDatabaseBackup(context),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('পরীক্ষামূলক ডেমো ডেটা লোড করুন'),
                          subtitle: const Text('অ্যাপ বোঝার জন্য ডেমো পণ্যের তালিকা ও হিসাব লোড করুন'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.insights),
                            onPressed: () => _loadDemoStoreData(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // CSV Import / Export section
                Text('CSV আমদানি ও রপ্তানি', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.table_chart_outlined),
                          title: const Text('পণ্য তালিকা CSV রপ্তানি'),
                          subtitle: const Text('সমস্ত পণ্যের তালিকা .csv ফাইলে সেভ ও শেয়ার করুন'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.upload_file_outlined),
                            onPressed: () => _exportProductsCsv(context),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.table_rows_outlined),
                          title: const Text('পণ্য তালিকা CSV আমদানি'),
                          subtitle: const Text('.csv ফাইল থেকে নতুন পণ্য আমদানি করুন'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.download_for_offline_outlined),
                            onPressed: () => _importProductsCsv(context),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: const Text('বিক্রয় রিপোর্ট CSV রপ্তানি'),
                          subtitle: const Text('সমস্ত বিক্রয় লেনদেন .csv ফাইলে সেভ ও শেয়ার করুন'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () => _exportSalesCsv(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Storage and Save Location section
                Text('স্টোরেজ ও সেভ লোকেশন', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: const Text('ডিফল্ট পিডিএফ সেভ ফোল্ডার'),
                          subtitle: Text(
                            settings.pdfSavePath != null && settings.pdfSavePath!.isNotEmpty
                                ? settings.pdfSavePath!
                                : 'ডিফল্ট ডাউনলোড/ডকুমেন্টস',
                            style: TextStyle(
                              color: settings.pdfSavePath != null ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                icon: const Icon(Icons.folder_open_outlined),
                                onPressed: () async {
                                  try {
                                    final path = await FilePicker.platform.getDirectoryPath();
                                    if (path != null) {
                                      await ref.read(settingsControllerProvider.notifier).updatePdfSavePath(path);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('পিডিএফ সেভ ফোল্ডার সেট করা হয়েছে!')),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('ফোল্ডার সিলেক্ট করতে সমস্যা হয়েছে: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                              if (settings.pdfSavePath != null && settings.pdfSavePath!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () async {
                                    await ref.read(settingsControllerProvider.notifier).updatePdfSavePath(null);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('পিডিএফ সেভ ফোল্ডার রিসেট করা হয়েছে')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('ডিফল্ট সিএসভি সেভ ফোল্ডার'),
                          subtitle: Text(
                            settings.csvSavePath != null && settings.csvSavePath!.isNotEmpty
                                ? settings.csvSavePath!
                                : 'ডিফল্ট ডাউনলোড/ডকুমেন্টস',
                            style: TextStyle(
                              color: settings.csvSavePath != null ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                icon: const Icon(Icons.folder_open_outlined),
                                onPressed: () async {
                                  try {
                                    final path = await FilePicker.platform.getDirectoryPath();
                                    if (path != null) {
                                      await ref.read(settingsControllerProvider.notifier).updateCsvSavePath(path);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('সিএসভি সেভ ফোল্ডার সেট করা হয়েছে!')),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('ফোল্ডার সিলেক্ট করতে সমস্যা হয়েছে: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                              if (settings.csvSavePath != null && settings.csvSavePath!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () async {
                                    await ref.read(settingsControllerProvider.notifier).updateCsvSavePath(null);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('সিএসভি সেভ ফোল্ডার রিসেট করা হয়েছে')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('ফায়ারবেস ক্লাউড সিঙ্ক', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cloud_sync_rounded,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ফায়ারবেস ডাটাবেস সিঙ্ক',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'আপনার অফলাইন ডাটাবেস ক্লাউডে সিঙ্ক করুন',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        // Show Store ID
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'স্টোর আইডি (Firestore Collection ID):',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<Map<String, String>>(
                              future: ref.read(firebaseSyncServiceProvider).getStoreDocIdAndShopID(settings.shopName),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                }
                                return Text(
                                  snapshot.data?['storeDocId'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Show last sync time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'সর্বশেষ সিঙ্ক:',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _lastSyncTime != null
                                    ? Formatters.dateTime(_lastSyncTime!)
                                    : 'এখনো সিঙ্ক করা হয়নি',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Sync Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded),
                            label: Text(_isSyncing ? 'সিঙ্ক হচ্ছে...' : 'এখনই সিঙ্ক করুন'),
                            onPressed: _isSyncing
                                ? null
                                : () async {
                                    setState(() {
                                      _isSyncing = true;
                                    });
                                    try {
                                      final syncService = ref.read(firebaseSyncServiceProvider);
                                      await syncService.syncAllData(settings);
                                      setState(() {
                                        _lastSyncTime = DateTime.now();
                                      });
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('ডাটাবেস সফলভাবে ফায়ারবেসে সিঙ্ক করা হয়েছে!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('সিঙ্ক করতে সমস্যা হয়েছে: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      setState(() {
                                        _isSyncing = false;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('সেশন ও লগআউট', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.logout_rounded, color: Colors.red),
                          title: const Text(
                            'লগআউট ও দৈনিক ক্লোজিং রিপোর্ট',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('লগআউট করুন এবং আজকের দৈনিক লেনদেনের PDF রিপোর্ট সংরক্ষণ করুন'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                          onTap: () => logoutAndGenerateClosingReport(context, ref),
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

  // Dialog Categories CRUD
  void _showCategoryManagementDialog(BuildContext context) {
    final theme = Theme.of(context);
    final catNameController = TextEditingController();
    String selectedIcon = 'local_cafe';
    String selectedColor = '0xFF008060';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categoriesAsync = ref.watch(categoriesControllerProvider);

            return AlertDialog(
              title: const Text('ক্যাটাগরি সমূহ ম্যানেজ করুন'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.25,
                        ),
                        child: categoriesAsync.maybeWhen(
                          data: (list) {
                            if (list.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Text('কোনো ক্যাটাগরি তৈরি করা হয়নি।'),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final cat = list[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: Color(int.parse(cat.color)),
                                    child: const Icon(Icons.category, color: Colors.white, size: 16),
                                  ),
                                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      ref.read(categoriesControllerProvider.notifier).deleteCategory(cat.id);
                                      ref.invalidate(productsListProvider);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                          orElse: () => const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      const Divider(height: 24),
                      const Text(
                        'নতুন ক্যাটাগরি তৈরি করুন',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: catNameController,
                        decoration: const InputDecoration(
                          labelText: 'ক্যাটাগরির নাম',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('আইকন নির্বাচন করুন'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'local_cafe',
                          'fastfood',
                          'shopping_basket',
                          'grass',
                          'soap',
                          'cleaning_services',
                        ].map((icName) {
                          IconData iconData;
                          switch (icName) {
                            case 'local_cafe': iconData = Icons.local_cafe; break;
                            case 'fastfood': iconData = Icons.fastfood; break;
                            case 'shopping_basket': iconData = Icons.shopping_basket; break;
                            case 'grass': iconData = Icons.grass; break;
                            case 'soap': iconData = Icons.soap; break;
                            default: iconData = Icons.cleaning_services;
                          }
                          final isSelected = selectedIcon == icName;
                          return IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                              foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            ),
                            icon: Icon(iconData, size: 18),
                            onPressed: () => setDialogState(() => selectedIcon = icName),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text('রঙ নির্বাচন করুন'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          '0xFF008060',
                          '0xFFFF8C00',
                          '0xFF4682B4',
                          '0xFFDAA520',
                          '0xFFBA55D3',
                        ].map((hexStr) {
                          final isSelected = selectedColor == hexStr;
                          return InkWell(
                            onTap: () => setDialogState(() => selectedColor = hexStr),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(int.parse(hexStr)),
                                border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = catNameController.text.trim();
                            if (name.isNotEmpty) {
                              ref.read(categoriesControllerProvider.notifier).addCategory(
                                    name,
                                    selectedIcon,
                                    selectedColor,
                                  );
                              catNameController.clear();
                            }
                          },
                          child: const Text('ক্যাটাগরি যোগ করুন'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('বন্ধ করুন'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportProductsCsv(BuildContext context) async {
    try {
      final hasPermission = await PermissionUtils.requestStoragePermission(context);
      if (!hasPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('স্টোরেজ পারমিশন প্রয়োজন!')),
          );
        }
        return;
      }

      final products = await ref.read(productsListProvider.future);
      final csvString = CsvHelper.exportProductsToCsv(products);

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final csvSavePath = settings?.csvSavePath;
      final targetDir = await PdfGenerator.getCsvSaveDirectory(csvSavePath);

      final path = p.join(targetDir.path, 'products_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      final file = File(path);
      await file.writeAsString(csvString);

      if (mounted) {
        DialogUtils.showSaveSuccessDialog(context, path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV রপ্তানি ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }

  // CSV Import: Products
  Future<void> _importProductsCsv(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return;

      final csvFile = File(result.files.single.path!);
      final csvString = await csvFile.readAsString();
      final importedProducts = CsvHelper.importProductsFromCsv(csvString);

      int count = 0;
      for (final companion in importedProducts) {
        await ref.read(productsRepositoryProvider).addProduct(companion);
        count++;
      }

      ref.invalidate(productsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count টি পণ্য সফলভাবে আমদানি হয়েছে!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV আমদানি ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }

  Future<void> _exportSalesCsv(BuildContext context) async {
    try {
      final hasPermission = await PermissionUtils.requestStoragePermission(context);
      if (!hasPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('স্টোরেজ পারমিশন প্রয়োজন!')),
          );
        }
        return;
      }

      final salesWithDetails = await ref.read(salesHistoryProvider.future);
      final sales = salesWithDetails.map((s) => s.sale).toList();
      final csvString = CsvHelper.exportSalesToCsv(sales);

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final csvSavePath = settings?.csvSavePath;
      final targetDir = await PdfGenerator.getCsvSaveDirectory(csvSavePath);

      final path = p.join(targetDir.path, 'sales_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      final file = File(path);
      await file.writeAsString(csvString);

      if (mounted) {
        DialogUtils.showSaveSuccessDialog(context, path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('বিক্রয় CSV রপ্তানি ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }

  // Backup Export
  Future<void> _exportDatabaseBackup(BuildContext context) async {
    try {
      final jsonStr = await ref.read(settingsControllerProvider.notifier).exportToJson();
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'villageco_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      final file = File(path);
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ডেটা এখানে এক্সপোর্ট করা হয়েছে: $path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ব্যাকআপ ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }

  // Backup Import
  void _importDatabaseBackup(BuildContext context) {
    final inputController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('JSON ব্যাকআপ ফাইলটি সঠিক নয়: $e')),
                );
              }
            },
            child: const Text('রিস্টোর করুন'),
          ),
        ],
      ),
    );
  }

  // Load Demo Data (Localized Bangla datasets)
  Future<void> _loadDemoStoreData(BuildContext context) async {
    const demoJson = '''
    {
      "categories": [
        {"id": "c1", "name": "পানীয় ও জুস", "icon": "local_cafe", "color": "0xFF008060"},
        {"id": "c2", "name": "নাস্তা ও চিপস", "icon": "fastfood", "color": "0xFFFF8C00"},
        {"id": "c3", "name": "নিত্য প্রয়োজনীয়", "icon": "shopping_basket", "color": "0xFF4682B4"},
        {"id": "c4", "name": "চাল ও ডাল", "icon": "grass", "color": "0xFFDAA520"}
      ],
      "suppliers": [
        {"id": "s1", "name": "মেট্রো ডিস্ট্রিবিউশন লিঃ", "phone": "01711223344", "email": "info@metro.com", "address": "তেজগাঁও শিল্প এলাকা, ঢাকা"},
        {"id": "s2", "name": "গ্রিন ভ্যালি ট্রেডার্স", "phone": "01999998888", "email": "sales@greenvalley.com", "address": "খাতুনগঞ্জ, চট্টগ্রাম"}
      ],
      "customers": [
        {"id": "cust1", "name": "কামাল উদ্দিন", "phone": "01671112222", "email": "kamal@gmail.com", "address": "মিরপুর, ঢাকা"},
        {"id": "cust2", "name": "ফাতেমা বেগম", "phone": "01851234567", "email": "fatima@gmail.com", "address": "গুলশান, ঢাকা"}
      ],
      "products": [
        {"id": "p1", "name": "কোকাকোলা ২৫০ মিলি", "barcode": "88010203040", "categoryId": "c1", "brand": "কোকাকোলা", "buyingPrice": 30.00, "sellingPrice": 35.00, "currentStock": 120.0, "minimumStock": 30.0, "unit": "pcs", "supplierId": "s1", "description": "কোকাকোলা সফট ড্রিংক ক্যান।", "imageUrl": "https://images.unsplash.com/photo-1622483767028-3f66f32aef97?q=80&w=400", "isArchived": false, "isFavorite": true},
        {"id": "p2", "name": "স্প্রাইট ২৫০ মিলি", "barcode": "88010203045", "categoryId": "c1", "brand": "কোকাকোলা", "buyingPrice": 30.00, "sellingPrice": 35.00, "currentStock": 80.0, "minimumStock": 20.0, "unit": "pcs", "supplierId": "s1", "description": "স্প্রাইট সফট ড্রিংক।", "imageUrl": "https://images.unsplash.com/photo-1625772290748-160b6160168f?q=80&w=400", "isArchived": false, "isFavorite": false},
        {"id": "p3", "name": "বসুন্ধরা আটা ২ কেজি", "barcode": "88010203052", "categoryId": "c4", "brand": "বসুন্ধরা", "buyingPrice": 120.00, "sellingPrice": 135.00, "currentStock": 40.0, "minimumStock": 10.0, "unit": "bag", "supplierId": "s2", "description": "প্যাকেটজাত সাদা ময়দা/আটা।", "imageUrl": "https://images.unsplash.com/photo-1574316071802-0d684efa7bf5?q=80&w=400", "isArchived": false, "isFavorite": true},
        {"id": "p4", "name": "মিনিকেট চাল ২৫ কেজি", "barcode": "88010203058", "categoryId": "c4", "brand": "রশিদ রাইস", "buyingPrice": 1600.00, "sellingPrice": 1750.00, "currentStock": 8.0, "minimumStock": 15.0, "unit": "bag", "supplierId": "s2", "description": "প্রিমিয়াম মিনিকেট চালের বস্তা।", "imageUrl": "https://images.unsplash.com/photo-1586201375761-83865001e31c?q=80&w=400", "isArchived": false, "isFavorite": true},
        {"id": "p5", "name": "লেস পটেটো চিপস মাসালা", "barcode": "88010203061", "categoryId": "c2", "brand": "পেপসিকো", "buyingPrice": 18.00, "sellingPrice": 25.00, "currentStock": 15.0, "minimumStock": 25.0, "unit": "pcs", "supplierId": "s1", "description": "লেস ম্যাজিক মাসালা চিপস।", "imageUrl": "https://images.unsplash.com/photo-1566478989037-eec170784d0b?q=80&w=400", "isArchived": false, "isFavorite": false},
        {"id": "p6", "name": "লিপটন ব্ল্যাক টি ১০০ ব্যাগ", "barcode": "88010203070", "categoryId": "c3", "brand": "ইউনিলিভার", "buyingPrice": 220.00, "sellingPrice": 270.00, "currentStock": 25.0, "minimumStock": 5.0, "unit": "pcs", "supplierId": "s1", "description": "লিপটন ব্ল্যাক টি ব্যাগ।", "imageUrl": "https://images.unsplash.com/photo-1576092768241-dec231879fc3?q=80&w=400", "isArchived": false, "isFavorite": false}
      ]
    }
    ''';

    final screenContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: !isLoading,
              child: AlertDialog(
                title: const Text('ডেমো ডেটা লোড করবেন?'),
                content: isLoading
                    ? const SizedBox(
                        height: 100,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('ডেমো ডেটা লোড হচ্ছে, অনুগ্রহ করে অপেক্ষা করুন...'),
                            ],
                          ),
                        ),
                      )
                    : const Text('সতর্কতা: এটি করলে আপনার বর্তমান পণ্য, ক্যাটাগরি এবং বিক্রির হিসাব মুছে যাবে এবং পরীক্ষামূলক নতুন ডেমো পণ্যের তালিকা লোড হবে।'),
                actions: isLoading
                    ? []
                    : [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('বাতিল'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            setDialogState(() {
                              isLoading = true;
                            });

                            try {
                              await ref.read(settingsControllerProvider.notifier).importFromJson(demoJson);
                              ref.invalidate(productsListProvider);
                              ref.invalidate(categoriesControllerProvider);
                              ref.invalidate(suppliersControllerProvider);
                              ref.invalidate(salesHistoryProvider);
                              ref.invalidate(dashboardMetricsProvider);

                              if (screenContext.mounted) {
                                Navigator.pop(dialogCtx); // Close the dialog
                                ScaffoldMessenger.of(screenContext).showSnackBar(
                                  const SnackBar(content: Text('ডেমো পণ্যের ডেটাসেট লোড সম্পন্ন হয়েছে! ড্যাশবোর্ড দেখুন।')),
                                );
                              }
                            } catch (e) {
                              if (screenContext.mounted) {
                                Navigator.pop(dialogCtx); // Close the dialog
                                ScaffoldMessenger.of(screenContext).showSnackBar(
                                  SnackBar(content: Text('ডেমো ডেটা লোড ব্যর্থ: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('ডেমো ডেটা লোড'),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }
}
