import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../reports_controller.dart';
import '../reports_actions.dart';

class FinancialsTab extends ConsumerWidget {
  final AsyncValue<DashboardMetrics> metricsAsync;

  const FinancialsTab({
    super.key,
    required this.metricsAsync,
  });

  Widget _buildPlRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    bool isPositive = false,
    bool isNegative = false,
  }) {
    Color? color;
    if (isPositive) color = Colors.green;
    if (isNegative) color = Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return metricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('হিসাব লোড ব্যর্থ: $err')),
      data: (metrics) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'লাভ-ক্ষতি বিবরণী',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'লাভ-ক্ষতি বিবরণী (Profit & Loss Statement)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'তারিখ: ${Formatters.dateTime(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'আজকের লাভ-ক্ষতি বিবরণী (Today\'s Financials)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPlRow('বিক্রয় রাজস্ব (Sales Revenue)', Formatters.currency(metrics.todaySales), isPositive: true),
                      const SizedBox(height: 6),
                      _buildPlRow('বিক্রীত পণ্যের খরচ (COGS)', '- ${Formatters.currency(metrics.todayCOGS)}', isNegative: true),
                      const SizedBox(height: 6),
                      _buildPlRow('মোট লাভ (Gross Profit)', Formatters.currency(metrics.todayGrossProfit), isBold: true),
                      const SizedBox(height: 6),
                      _buildPlRow('আজকের খরচ (Operating Expenses)', '- ${Formatters.currency(metrics.todayExpenses)}', isNegative: true),
                      const SizedBox(height: 6),
                      _buildPlRow(
                        'আজকের নিট লাভ (Net Profit)', 
                        Formatters.currency(metrics.todayNetProfit),
                        isBold: true,
                        isPositive: metrics.todayNetProfit >= 0,
                        isNegative: metrics.todayNetProfit < 0,
                      ),
                      
                      const Divider(height: 24),
                      
                      Text(
                        'সর্বমোট লাভ-ক্ষতি বিবরণী (All-Time Financials)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPlRow('সর্বমোট বিক্রয় (Total Sales)', Formatters.currency(metrics.totalSales), isPositive: true),
                      const SizedBox(height: 6),
                      _buildPlRow('সর্বমোট পণ্যের খরচ (Total COGS)', '- ${Formatters.currency(metrics.totalCOGS)}', isNegative: true),
                      const SizedBox(height: 6),
                      _buildPlRow('সর্বমোট মোট লাভ (Total Gross Profit)', Formatters.currency(metrics.grossProfit), isBold: true),
                      const SizedBox(height: 6),
                      _buildPlRow('সর্বমোট খরচ (Total Expenses)', '- ${Formatters.currency(metrics.totalExpenses)}', isNegative: true),
                      const SizedBox(height: 6),
                      _buildPlRow(
                        'সর্বমোট নিট লাভ (Total Net Profit)', 
                        Formatters.currency(metrics.netProfit),
                        isBold: true,
                        isPositive: metrics.netProfit >= 0,
                        isNegative: metrics.netProfit < 0,
                      ),
                      
                      const Divider(height: 24),
                      
                      _buildPlRow(
                        'মজুদ পণ্যের মূল্য (Inventory Value)', 
                        Formatters.currency(metrics.inventoryValue),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'রিপোর্ট এক্সপোর্ট ও প্রিন্ট করুন',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => ReportsActions.exportProfitLossCsv(context, ref, metrics),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('CSV শীট'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => ReportsActions.exportProfitLossPdf(context, ref, metrics),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => ReportsActions.printProfitLoss(context, metrics),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('প্রিন্ট'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
