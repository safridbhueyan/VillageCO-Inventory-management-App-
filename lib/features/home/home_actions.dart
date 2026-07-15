import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/firebase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pdf_generator.dart';
import '../reports/reports_controller.dart';
import '../settings/settings_controller.dart';
import '../super_admin/admin_controller.dart';

Future<void> logoutAndGenerateClosingReport(BuildContext context, WidgetRef ref) async {
  final isImpersonating = ref.read(adminImpersonationProvider).isImpersonating;
  if (isImpersonating) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'ডাটাবেস ও রিপোর্ট সার্ভারে সিঙ্ক হচ্ছে...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      if (settings != null) {
        await ref.read(firebaseSyncServiceProvider).syncAllData(settings);
      }
    } catch (syncError) {
      debugPrint('Firebase Sync failed during impersonation logout: $syncError');
    }

    try {
      await ref.read(adminRepositoryProvider).clearLocalDatabase();
      ref.read(adminImpersonationProvider.notifier).stopImpersonation();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.go('/super_admin');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e')),
        );
      }
    }
    return;
  }

  // Show a loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'ডাটাবেস ও রিপোর্ট সার্ভারে সিঙ্ক হচ্ছে...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    // 1. Fetch the data
    final metrics = await ref.read(dashboardMetricsProvider.future);
    final sales = await ref.read(salesHistoryProvider.future);

    // 2. Filter sales to get only today's transactions
    final now = DateTime.now();
    final todaySalesList = sales.where((s) {
      final date = s.sale.date;
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).map((s) {
      return {
        'id': s.sale.id,
        'time': Formatters.dateTime(s.sale.date).split(" ").last,
        'customer': s.customer?.name ?? 'সাধারণ কাস্টমার',
        'payment': s.sale.paymentMethod == 'Cash'
            ? 'ক্যাশ'
            : (s.sale.paymentMethod == 'Card'
                ? 'কার্ড'
                : 'মোবাইল'),
        'amount': s.sale.total.toStringAsFixed(2),
      };
    }).toList();

    final settings = ref.read(settingsControllerProvider).valueOrNull;
    final pdfSavePath = settings?.pdfSavePath;

    // 3. Generate daily transaction PDF report and save it
    final reportPath = await PdfGenerator.generateAndSaveDailyTransactionReport(
      todaySales: metrics.todaySales,
      totalExpenses: metrics.totalExpenses,
      netProfit: metrics.netProfit,
      totalTransactionsCount: todaySalesList.length,
      todaySalesList: todaySalesList,
      customSavePath: pdfSavePath,
    );

    // 4. Sync all database data & upload report PDF to Firebase (Firestore + Storage)
    if (settings != null) {
      try {
        final syncService = ref.read(firebaseSyncServiceProvider);
        final docInfo = await syncService.getStoreDocIdAndShopID(settings.shopName);
        final storeDocId = docInfo['storeDocId']!;
        
        // Sync local SQLite tables to Cloud Firestore
        await syncService.syncAllData(settings);
        
        // Upload report PDF and save report metadata
        if (reportPath != null) {
          final pdfUrl = await syncService.uploadReportPdf(storeDocId, reportPath);
          await syncService.saveReportMetadata(
            storeDocId,
            todaySales: metrics.todaySales,
            totalExpenses: metrics.totalExpenses,
            netProfit: metrics.netProfit,
            totalTransactionsCount: todaySalesList.length,
            pdfUrl: pdfUrl,
            reportPath: reportPath,
          );
        }
      } catch (syncError) {
        debugPrint('Firebase Sync failed during logout: $syncError');
      }
    }

    // Dismiss loading dialog before success dialog/redirect to prevent route lock
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (reportPath != null) {
      if (context.mounted) {
        DialogUtils.showSaveSuccessDialog(context, reportPath);
      }
    }

    // 5. Log out
    if (context.mounted) {
      context.go('/login');
    }
  } catch (e) {
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
    
    debugPrint('Error generating closing report: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ক্লোজিং রিপোর্ট তৈরিতে সমস্যা হয়েছে: $e. লগআউট সম্পন্ন হচ্ছে...')),
      );
      context.go('/login');
    }
  }
}
