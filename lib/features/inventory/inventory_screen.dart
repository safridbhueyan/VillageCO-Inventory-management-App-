import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../products/products_controller.dart';
import 'inventory_controller.dart';
import 'inventory_actions.dart';
import 'widgets/stock_status_tab.dart';
import 'widgets/stock_logs_tab.dart';
import 'widgets/stock_adjustment_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsListProvider);
    final logsAsync = ref.watch(stockHistoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টক ও ইনভেন্টরি', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_upload_rounded),
            tooltip: 'আমদানি করুন (Import)',
            onSelected: (val) {
              if (val == 'excel') {
                InventoryActions.importInventoryFromExcel(context, ref);
              } else if (val == 'csv') {
                InventoryActions.importInventoryFromCsv(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'excel', child: Text('এক্সেল (.xlsx) আমদানি')),
              PopupMenuItem(value: 'csv', child: Text('সিএসভি (.csv) আমদানি')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'রপ্তানি করুন (Export)',
            onSelected: (val) {
              if (val == 'excel') {
                InventoryActions.exportInventoryToExcel(context, ref);
              } else if (val == 'csv') {
                InventoryActions.exportInventoryToCsv(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'excel', child: Text('এক্সেল (.xlsx) রপ্তানি')),
              PopupMenuItem(value: 'csv', child: Text('সিএসভি (.csv) রপ্তানি')),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_rounded), text: 'স্টক রিপোর্ট'),
            Tab(icon: Icon(Icons.history_rounded), text: 'আদান-প্রদান লগ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StockStatusTab(productsAsync: productsAsync),
          StockLogsTab(logsAsync: logsAsync),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const StockAdjustmentDialog(),
        ),
        icon: const Icon(Icons.swap_vertical_circle_outlined),
        label: const Text('স্টক পরিবর্তন করুন'),
      ),
    );
  }
}
