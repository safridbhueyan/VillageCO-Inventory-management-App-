import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../reports/reports_controller.dart';
import '../products/products_controller.dart';
import '../settings/settings_controller.dart';
import 'widgets/welcome_header.dart';
import 'widgets/metrics_grid.dart';
import 'widgets/quick_actions_panel.dart';
import 'widgets/sales_chart_panel.dart';
import 'widgets/low_stock_panel.dart';
import 'widgets/recent_sales_list.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final productsAsync = ref.watch(productsListProvider);
    final salesAsync = ref.watch(salesHistoryProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          settingsAsync.maybeWhen(
            data: (settings) => settings.shopName,
            orElse: () => 'ভিলেজকো ইনভেন্টরি',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              Formatters.date(DateTime.now()),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.03),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: metricsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('ড্যাশবোর্ড লোড করতে সমস্যা হয়েছে: $err')),
          data: (metrics) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardMetricsProvider);
              ref.invalidate(productsListProvider);
              ref.invalidate(salesHistoryProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header (Bangla)
                  const WelcomeHeader(),
                  const SizedBox(height: 28),

                  // Metrics Grid
                  MetricsGrid(metrics: metrics),
                  const SizedBox(height: 32),

                  // Quick Actions
                  const QuickActionsPanel(),
                  const SizedBox(height: 32),

                  // Sales Trend Chart & Alerts
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: SalesChartPanel(salesAsync: salesAsync),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: LowStockPanel(productsAsync: productsAsync),
                        ),
                      ],
                    )
                  else ...[
                    SalesChartPanel(salesAsync: salesAsync),
                    const SizedBox(height: 16),
                    LowStockPanel(productsAsync: productsAsync),
                  ],

                  const SizedBox(height: 32),

                  // Recent Sales List
                  RecentSalesList(salesAsync: salesAsync),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
