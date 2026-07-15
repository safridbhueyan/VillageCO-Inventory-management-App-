import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/permission_utils.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/csv_helper.dart';
import '../../products/products_controller.dart';
import '../../reports/reports_controller.dart';
import '../settings_controller.dart';
import 'restore_backup_dialog.dart';
import 'load_demo_dialog.dart';

class BackupDataSettings extends ConsumerStatefulWidget {
  const BackupDataSettings({super.key});

  @override
  ConsumerState<BackupDataSettings> createState() => _BackupDataSettingsState();
}

class _BackupDataSettingsState extends ConsumerState<BackupDataSettings> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => const RestoreBackupDialog(),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('পরীক্ষামূলক ডেমো ডেটা লোড করুন'),
                  subtitle: const Text('অ্যাপ বোঝার জন্য ডেমো পণ্যের তালিকা ও হিসাব লোড করুন'),
                  trailing: IconButton.filledTonal(
                    icon: const Icon(Icons.insights),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => const LoadDemoDialog(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

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
      ],
    );
  }
}
