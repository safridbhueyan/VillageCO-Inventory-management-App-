import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/utils/formatters.dart';
import '../../reports/reports_controller.dart';
import 'metric_card.dart';

class MetricsGrid extends StatelessWidget {
  final DashboardMetrics metrics;

  const MetricsGrid({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : (width > 600 ? 2 : 1),
      childAspectRatio: 1.9,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        MetricCard(
          title: "আজকের বিক্রি",
          value: Formatters.currency(metrics.todaySales),
          icon: Icons.today_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        MetricCard(
          title: "মজুদ পণ্যের মূল্য",
          value: Formatters.currency(metrics.inventoryValue),
          icon: Icons.inventory_2_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        MetricCard(
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
        MetricCard(
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
    ).animate().slideY(begin: 0.08, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
