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
      body: metricsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('ড্যাশবোর্ড লোড করতে সমস্যা হয়েছে: $err')),
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
                // Welcome Header (Bangla)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'স্বাগতম, অ্যাডমিন 👋',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'আজকের দোকানের বেচা-বিক্রি ও হিসাব নিচে দেওয়া হলো।',
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
                    // Live Status (Bangla)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'বিক্রি চালু',
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

                // Metrics Grid (Simplified: 4 Key metrics instead of 8)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isDesktop ? 4 : (width > 600 ? 2 : 1),
                  childAspectRatio: 1.9,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _MetricCard(
                      title: "আজকের বিক্রি",
                      value: Formatters.currency(metrics.todaySales),
                      icon: Icons.today_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _MetricCard(
                      title: "মজুদ পণ্যের মূল্য",
                      value: Formatters.currency(metrics.inventoryValue),
                      icon: Icons.inventory_2_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _MetricCard(
                      title: "আজকের নিট লাভ",
                      value: Formatters.currency(metrics.netProfit),
                      icon: Icons.trending_up_rounded,
                      gradient: LinearGradient(
                        colors: metrics.netProfit >= 0
                            ? [const Color(0xFF059669), const Color(0xFF34D399)]
                            : [const Color(0xFFDC2626), const Color(0xFFF87171)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _MetricCard(
                      title: "কম স্টক পণ্য",
                      value: metrics.lowStockProducts.toString(),
                      icon: Icons.warning_amber_rounded,
                      gradient: LinearGradient(
                        colors: metrics.lowStockProducts > 0
                            ? [const Color(0xFFD97706), const Color(0xFFFBBF24)]
                            : [const Color(0xFF4B5563), const Color(0xFF9CA3AF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ],
                ).animate().slideY(begin: 0.08, duration: 400.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: 28),

                // Quick Actions (Bangla)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'দ্রুত অ্যাক্সেস',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _QuickActionCard(
                            label: 'নতুন বিক্রি',
                            icon: Icons.point_of_sale_rounded,
                            color: theme.colorScheme.primary,
                            onTap: () => context.go('/pos'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'পণ্য যোগ',
                            icon: Icons.add_circle_outline_rounded,
                            color: Colors.blue,
                            onTap: () => context.go('/products'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'স্টক আপডেট',
                            icon: Icons.call_received_rounded,
                            color: Colors.teal,
                            onTap: () => context.go('/inventory'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'লাভ-ক্ষতি রিপোর্ট',
                            icon: Icons.bar_chart_rounded,
                            color: Colors.purple,
                            onTap: () => context.go('/reports'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'সাপ্লায়ার রেজিস্ট্রি',
                            icon: Icons.local_shipping_rounded,
                            color: Colors.orange,
                            onTap: () => context.go('/suppliers'),
                          ),
                          const SizedBox(width: 14),
                          _QuickActionCard(
                            label: 'সাপ্লাই চেইন',
                            icon: Icons.hub_rounded,
                            color: Colors.indigo,
                            onTap: () => context.go('/supply_chain'),
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
              'সাপ্তাহিক বিক্রি রিপোর্ট (টাকা)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            salesAsync.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (err, st) => SizedBox(height: 200, child: Center(child: Text('চার্ট লোড ব্যর্থ: $err'))),
              data: (sales) {
                if (sales.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'এখনও কোনো বিক্রি করা হয়নি। পিওএস থেকে নতুন পণ্য বিক্রি করুন।',
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
                                '৳${value.toInt()}',
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
                  'কম স্টক এলার্ট',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/inventory'),
                  child: const Text('সব দেখুন'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(child: Text('লোডে সমস্যা: $err')),
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
                          Text('সব পণ্যের স্টক পর্যাপ্ত!', style: TextStyle(color: Colors.grey)),
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
                        subtitle: Text('সর্বনিম্ন স্টক: ${Formatters.number(item.minimumStock)} ${item.unit}', style: const TextStyle(fontSize: 11)),
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
                  'সাম্প্রতিক বিক্রি সমূহ',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/reports'),
                  child: const Text('সব দেখুন'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('বিক্রি তালিকা লোড ব্যর্থ: $err')),
              data: (sales) {
                if (sales.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36.0),
                    child: Center(
                      child: Text('এখনও কোনো পণ্য বিক্রি হয়নি।', style: TextStyle(color: Colors.grey)),
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
                    final customerName = saleWithDetails.customer?.name ?? 'সাধারণ কাস্টমার';
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
                        '${Formatters.dateTime(sale.date)} • $itemsCountটি আইটেম • ${sale.paymentMethod}',
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
                              color: theme.colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'পরিশোধিত',
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
  final Gradient gradient;
  final Color textColor;
  final Color iconColor;
  final Color iconBgColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
    this.iconBgColor = const Color(0x33FFFFFF), // white with 20% opacity
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                color: iconBgColor,
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
                    style: TextStyle(
                      color: textColor.withOpacity(0.85),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 18,
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
              'ক্লিক করুন',
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
