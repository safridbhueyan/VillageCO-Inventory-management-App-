import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/pdf_generator.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/permission_utils.dart';
import '../../core/utils/formatters.dart';
import '../settings/settings_controller.dart';
import 'reports_controller.dart';

class ReportsActions {
  static Future<void> exportSalesCsv(BuildContext context, WidgetRef ref) async {
    final list = ref.read(salesHistoryProvider).value ?? [];
    if (list.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ডাউনলোড করার মতো কোনো বিক্রির রেকর্ড নেই।'),
          ),
        );
      }
      return;
    }

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

      final buffer = StringBuffer();
      buffer.writeln(
        'Invoice ID,Date,Customer,Subtotal,Discount,Total,Payment Method',
      );

      for (final item in list) {
        final s = item.sale;
        final c = item.customer?.name ?? 'Walk-in';
        buffer.writeln(
          '${s.id},${s.date.toIso8601String()},$c,${s.subtotal},${s.discount},${s.total},${s.paymentMethod}',
        );
      }

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final csvSavePath = settings?.csvSavePath;
      final targetDir = await PdfGenerator.getCsvSaveDirectory(csvSavePath);

      final path = p.join(
        targetDir.path,
        'villageco_sales_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      final file = File(path);
      await file.writeAsString(buffer.toString());

      if (context.mounted) {
        DialogUtils.showSaveSuccessDialog(context, path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ডাউনলোড ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }

  static Future<void> exportProfitLossCsv(BuildContext context, WidgetRef ref, DashboardMetrics metrics) async {
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

      final buffer = StringBuffer();
      buffer.writeln('লাভ-ক্ষতি বিবরণী (Profit & Loss Statement)');
      buffer.writeln('তারিখ,${Formatters.dateTime(DateTime.now())}');
      buffer.writeln();
      buffer.writeln('আজকের লাভ-ক্ষতি বিবরণী (Today\'s Financials)');
      buffer.writeln('আজকের বিক্রয় রাজস্ব (Sales Revenue),${metrics.todaySales}');
      buffer.writeln('আজকের বিক্রীত পণ্যের খরচ (COGS),-${metrics.todayCOGS}');
      buffer.writeln('আজকের মোট লাভ (Gross Profit),${metrics.todayGrossProfit}');
      buffer.writeln('আজকের খরচ (Operating Expenses),-${metrics.todayExpenses}');
      buffer.writeln('আজকের নিট লাভ (Net Profit),${metrics.todayNetProfit}');
      buffer.writeln();
      buffer.writeln('সর্বমোট লাভ-ক্ষতি বিবরণী (All-Time Financials)');
      buffer.writeln('সর্বমোট বিক্রয় (Total Sales),${metrics.totalSales}');
      buffer.writeln('সর্বমোট বিক্রীত পণ্যের খরচ (Total COGS),-${metrics.totalCOGS}');
      buffer.writeln('সর্বমোট মোট লাভ (Total Gross Profit),${metrics.grossProfit}');
      buffer.writeln('সর্বমোট খরচ (Total Expenses),-${metrics.totalExpenses}');
      buffer.writeln('সর্বমোট নিট লাভ (Total Net Profit),${metrics.netProfit}');
      buffer.writeln();
      buffer.writeln('মজুদ পণ্যের মূল্য (Inventory Value),${metrics.inventoryValue}');

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final csvSavePath = settings?.csvSavePath;
      final targetDir = await PdfGenerator.getCsvSaveDirectory(csvSavePath);

      final file = File(
        '${targetDir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buffer.toString());

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

  static Future<void> exportProfitLossPdf(BuildContext context, WidgetRef ref, DashboardMetrics metrics) async {
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

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final pdfSavePath = settings?.pdfSavePath;

      final savedPath = await PdfGenerator.generateAndSaveTextProfitLoss(
        todaySales: metrics.todaySales,
        inventoryValue: metrics.inventoryValue,
        totalExpenses: metrics.totalExpenses,
        netProfit: metrics.netProfit,
        todayExpenses: metrics.todayExpenses,
        todayGrossProfit: metrics.todayGrossProfit,
        todayNetProfit: metrics.todayNetProfit,
        totalSales: metrics.totalSales,
        todayCOGS: metrics.todayCOGS,
        totalCOGS: metrics.totalCOGS,
        grossProfit: metrics.grossProfit,
        customSavePath: pdfSavePath,
      );

      if (savedPath != null) {
        if (context.mounted) {
          DialogUtils.showSaveSuccessDialog(context, savedPath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF তৈরি করতে ব্যর্থ: $e')),
        );
      }
    }
  }

  static Future<void> printProfitLoss(BuildContext context, DashboardMetrics metrics) async {
    try {
      await PdfGenerator.printTextProfitLoss(
        todaySales: metrics.todaySales,
        inventoryValue: metrics.inventoryValue,
        totalExpenses: metrics.totalExpenses,
        netProfit: metrics.netProfit,
        todayExpenses: metrics.todayExpenses,
        todayGrossProfit: metrics.todayGrossProfit,
        todayNetProfit: metrics.todayNetProfit,
        totalSales: metrics.totalSales,
        todayCOGS: metrics.todayCOGS,
        totalCOGS: metrics.totalCOGS,
        grossProfit: metrics.grossProfit,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('প্রিন্ট ব্যর্থ হয়েছে: $e')),
        );
      }
    }
  }
}
