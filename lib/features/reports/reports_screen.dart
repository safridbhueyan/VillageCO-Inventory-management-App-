import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reports_controller.dart';
import 'widgets/financials_tab.dart';
import 'widgets/sales_log_tab.dart';
import 'widgets/expenses_tab.dart';
import 'widgets/product_insights_tab.dart';
import 'widgets/returns_log_tab.dart';
import 'widgets/expiry_tab.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final salesHistoryAsync = ref.watch(salesHistoryProvider);
    final expensesAsync = ref.watch(expensesControllerProvider);
    final topSellingAsync = ref.watch(topSellingProductsProvider);
    final returnsAsync = ref.watch(returnsHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'হিসাব ও রিপোর্ট',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'লাভ-ক্ষতি হিসাব'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'বিক্রির খাতা'),
            Tab(icon: Icon(Icons.money_off_rounded), text: 'খরচের খাতা'),
            Tab(icon: Icon(Icons.auto_graph_rounded), text: 'বিক্রিত পণ্য বিশ্লেষণ'),
            Tab(icon: Icon(Icons.keyboard_return_rounded), text: 'পণ্য ফেরত/রিটার্ন'),
            Tab(icon: Icon(Icons.av_timer_outlined), text: 'মেয়াদোত্তীর্ণ পণ্য'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FinancialsTab(metricsAsync: metricsAsync),
          SalesLogTab(salesHistoryAsync: salesHistoryAsync),
          ExpensesTab(expensesAsync: expensesAsync),
          ProductInsightsTab(topSellingAsync: topSellingAsync),
          ReturnsLogTab(returnsAsync: returnsAsync),
          const ExpiryTab(),
        ],
      ),
    );
  }
}
