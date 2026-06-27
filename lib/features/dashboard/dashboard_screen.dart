import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/utils/formatters.dart';
import '../reports/reports_controller.dart';
import '../products/products_controller.dart';
import '../settings/settings_controller.dart';

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
            orElse: () => 'VillageCO Inventory',
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
      body: metricsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading dashboard: $err')),
        data: (metrics) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardMetricsProvider);
            ref.invalidate(productsListProvider);
            ref.invalidate(salesHistoryProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header Block
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, Admin 👋',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Here is how VillageCO is performing today.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live POS Pulsing Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B074).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00B074).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00B074),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'POS ACTIVE',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .custom(duration: 1.seconds, builder: (context, val, child) {
                       return Opacity(opacity: 0.5 + (val * 0.5), child: child);
                     }),
                  ],
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 24),

                // Metrics Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isDesktop ? 4 : (width > 600 ? 2 : 1),
                  childAspectRatio: 1.9,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _MetricCard(
                      title: "Today's Sales",
                      value: Formatters.currency(metrics.todaySales),
                      icon: Icons.today_rounded,
                      iconColor: theme.colorScheme.primary,
                      bgColor: theme.colorScheme.primary.withOpacity(0.08),
                    ),
                    _MetricCard(
                      title: "Monthly Sales",
                      value: Formatters.currency(metrics.monthlySales),
                      icon: Icons.calendar_month_rounded,
                      iconColor: const Color(0xFF6366F1), // Indigo
                      bgColor: const Color(0xFF6366F1).withOpacity(0.08),
                    ),
                    _MetricCard(
                      title: "Inventory Value",
                      value: Formatters.currency(metrics.inventoryValue),
                      icon: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFF0EA5E9), // Sky Blue
                      bgColor: const Color(0xFF0EA5E9).withOpacity(0.08),
                    ),
                    _MetricCard(
                      title: "Net Profit",
                      value: Formatters.currency(metrics.netProfit),
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF00B074), // Shopify Green
                      bgColor: const Color(0xFF00B074).withOpacity(0.08),
                      valueColor: metrics.netProfit >= 0 ? const Color(0xFF00B074) : Colors.redAccent,
                    ),
                    _MetricCard(
                      title: "Total Products",
                      value: metrics.totalProducts.toString(),
                      icon: Icons.grid_view_rounded,
                      iconColor: const Color(0xFF8B5CF6), // Violet
                      bgColor: const Color(0xFF8B5CF6).withOpacity(0.08),
                    ),
                    _MetricCard(
                      title: "Categories",
                      value: metrics.totalCategories.toString(),
                      icon: Icons.category_outlined,
                      iconColor: const Color(0xFFEC4899), // Pink
                      bgColor: const Color(0xFFEC4899).withOpacity(0.08),
                    ),
                    _MetricCard(
                      title: "Low Stock Items",
                      value: metrics.lowStockProducts.toString(),
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFF59E0B), // Amber
                      bgColor: const Color(0xFFF59E0B).withOpacity(0.08),
                      valueColor: metrics.lowStockProducts > 0 ? const Color(0xFFF59E0B) : null,
                    ),
                    _MetricCard(
                      title: "Out of Stock Items",
                      value: metrics.outOfStockProducts.toString(),
                      icon: Icons.error_outline_rounded,
                      iconColor: const Color(0xFFEF4444), // Red
                      bgColor: const Color(0xFFEF4444).withOpacity(0.08),
                      valueColor: metrics.outOfStockProducts > 0 ? const Color(0xFFEF4444) : null,
                    ),
                  ],
                ).animate().slideY(begin: 0.08, duration: 400.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: 28),

                // Quick Actions Dashboard Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _QuickActionCard(
                            label: 'New Sale',
                            icon: Icons.point_of_sale_rounded,
                            color: theme.colorScheme.primary,
                            onTap: () => context.go('/pos'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'Add Product',
                            icon: Icons.add_circle_outline_rounded,
                            color: Colors.blue,
                            onTap: () => context.go('/products'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'Stock In',
                            icon: Icons.call_received_rounded,
                            color: Colors.teal,
                            onTap: () => context.go('/inventory'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'View Reports',
                            icon: Icons.bar_chart_rounded,
                            color: Colors.purple,
                            onTap: () => context.go('/reports'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                const SizedBox(height: 28),

                // Sales Trend Chart & Alerts
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildSalesChart(context, salesAsync),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildLowStockPanel(context, productsAsync),
                      ),
                    ],
                  )
                else ...[
                  _buildSalesChart(context, salesAsync),
                  const SizedBox(height: 16),
                  _buildLowStockPanel(context, productsAsync),
                ],

                const SizedBox(height: 28),

                // Recent Sales List
                _buildRecentSalesList(context, salesAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesChart(BuildContext context, AsyncValue<List<SaleWithDetails>> salesAsync) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Revenue (Last 7 Days)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            salesAsync.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (err, st) => SizedBox(height: 200, child: Center(child: Text('Chart error: $err'))),
              data: (sales) {
                if (sales.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No sales recorded yet. Perform transactions in POS to generate data.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final chartPoints = _getLast7DaysSales(sales);
                
                return SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '\$${value.toInt()}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < chartPoints.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    chartPoints[index].label,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(chartPoints.length, (index) {
                            return FlSpot(index.toDouble(), chartPoints[index].value);
                          }),
                          isCurved: true,
                          color: theme.colorScheme.primary,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: theme.colorScheme.primary,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.18),
                                theme.colorScheme.primary.withOpacity(0.01),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<ChartDataPoint> _getLast7DaysSales(List<SaleWithDetails> sales) {
    final List<ChartDataPoint> list = [];
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStr = '${date.day}/${date.month}';
      
      double dayTotal = 0;
      for (final s in sales) {
        if (s.sale.date.year == date.year &&
            s.sale.date.month == date.month &&
            s.sale.date.day == date.day) {
          dayTotal += s.sale.total;
        }
      }
      list.add(ChartDataPoint(dayStr, dayTotal));
    }
    return list;
  }

  Widget _buildLowStockPanel(BuildContext context, AsyncValue<List<ProductWithDetails>> productsAsync) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        height: 312,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Low Stock Alerts',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/inventory'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(child: Text('Error: $err')),
                data: (products) {
                  final lowStockList = products.where((p) {
                    final prod = p.product;
                    return prod.currentStock <= prod.minimumStock;
                  }).toList();

                  if (lowStockList.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 36),
                          SizedBox(height: 8),
                          Text('All stocks healthy!', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: lowStockList.length > 5 ? 5 : lowStockList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = lowStockList[index].product;
                      final isOut = item.currentStock <= 0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Min: ${Formatters.number(item.minimumStock)} ${item.unit}', style: const TextStyle(fontSize: 11)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOut ? Colors.red.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOut ? Colors.red.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${Formatters.number(item.currentStock)} ${item.unit}',
                            style: TextStyle(
                              color: isOut ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSalesList(BuildContext context, AsyncValue<List<SaleWithDetails>> salesAsync) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/reports'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error loading transactions: $err')),
              data: (sales) {
                if (sales.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36.0),
                    child: Center(
                      child: Text('No transactions recorded yet.', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sales.length > 5 ? 5 : sales.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final saleWithDetails = sales[index];
                    final sale = saleWithDetails.sale;
                    final customerName = saleWithDetails.customer?.name ?? 'Walk-in Customer';
                    final itemsCount = saleWithDetails.items.length;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 20),
                      ),
                      title: Text(
                        customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${Formatters.dateTime(sale.date)} • $itemsCount items • ${sale.paymentMethod}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.currency(sale.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B074).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Paid',
                              style: TextStyle(
                                color: Color(0xFF00B074),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color? valueColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Quick access',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
