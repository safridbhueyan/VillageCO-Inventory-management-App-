import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../reports_controller.dart';

class ProductInsightsTab extends StatelessWidget {
  final AsyncValue<List<ProductSaleAggregation>> topSellingAsync;

  const ProductInsightsTab({
    super.key,
    required this.topSellingAsync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return topSellingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('বিশ্লেষণ লোড ব্যর্থ: $err')),
      data: (insights) {
        if (insights.isEmpty) {
          return const Center(
            child: Text('বিশ্লেষণ দেখতে পিওএস থেকে পণ্য বিক্রি করুন।'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'সবচেয়ে বেশি বিক্রি হওয়া পণ্যসমূহ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.take(5).map((e) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(e.product.name.substring(0, 1)),
                ),
                title: Text(
                  e.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'বিক্রিত মোট মূল্য: ${Formatters.currency(e.totalRevenue)}',
                ),
                trailing: Text(
                  '${Formatters.number(e.quantitySold)} টি বিক্রিত',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
