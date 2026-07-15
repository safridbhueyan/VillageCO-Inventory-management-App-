import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/utils/excel_helper.dart';
import '../../core/utils/csv_helper.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/permission_utils.dart';
import '../../core/database/database_providers.dart';
import '../products/products_controller.dart';
import '../settings/settings_controller.dart';

class InventoryActions {
  static Future<void> exportInventoryToExcel(BuildContext context, WidgetRef ref) async {
    try {
      final productsAsync = ref.read(productsListProvider);
      final products = productsAsync.maybeWhen(data: (list) => list, orElse: () => <ProductWithDetails>[]);
      if (products.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('রপ্তানি করার মতো কোনো পণ্য পাওয়া যায়নি')),
          );
        }
        return;
      }
      
      final excelBytes = ExcelHelper.exportProducts(products);
      if (excelBytes == null) throw Exception('Excel creation failed');
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(excelBytes);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Report Excel');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('রপ্তানি ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }

  static Future<void> importInventoryFromExcel(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null || result.files.single.path == null) return;
      
      final path = result.files.single.path!;
      final bytes = await File(path).readAsBytes();
      final list = ExcelHelper.importProducts(bytes);
      
      if (list.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('এক্সেল ফাইলে কোনো সঠিক পণ্য তথ্য পাওয়া যায়নি')),
          );
        }
        return;
      }
      
      final db = ref.read(databaseProvider);
      
      await db.batch((batch) {
        for (final item in list) {
          batch.insert(
            db.products,
            item,
            mode: drift.InsertMode.insertOrReplace,
          );
        }
      });
      
      ref.invalidate(productsListProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সফলভাবে ${list.length}টি পণ্য ইনভেন্টরিতে ইম্পোর্ট করা হয়েছে')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('আমদানি ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }

  static Future<void> exportInventoryToCsv(BuildContext context, WidgetRef ref) async {
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

      final productsAsync = ref.read(productsListProvider);
      final products = productsAsync.maybeWhen(data: (list) => list, orElse: () => <ProductWithDetails>[]);
      if (products.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('রপ্তানি করার মতো কোনো পণ্য পাওয়া যায়নি')),
          );
        }
        return;
      }
      
      final csvData = CsvHelper.exportProductsToCsv(products);
      
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final csvSavePath = settings?.csvSavePath;
      final targetDir = await PdfGenerator.getCsvSaveDirectory(csvSavePath);

      final file = File('${targetDir.path}/inventory_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);

      if (context.mounted) {
        DialogUtils.showSaveSuccessDialog(context, file.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV রপ্তানি ব্যর্থ: $e')),
        );
      }
    }
  }

  static Future<void> importInventoryFromCsv(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return;
      
      final file = File(result.files.single.path!);
      final csvText = await file.readAsString();
      final list = CsvHelper.importProductsFromCsv(csvText);
      
      if (list.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV ফাইলে কোনো সঠিক পণ্য তথ্য পাওয়া যায়নি')),
          );
        }
        return;
      }
      
      final db = ref.read(databaseProvider);
      await db.batch((batch) {
        for (final item in list) {
          batch.insert(
            db.products,
            item,
            mode: drift.InsertMode.insertOrReplace,
          );
        }
      });
      
      ref.invalidate(productsListProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সফলভাবে ${list.length}টি পণ্য ইনভেন্টরিতে ইম্পোর্ট করা হয়েছে')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV আমদানি ব্যর্থ: $e')),
        );
      }
    }
  }
}
