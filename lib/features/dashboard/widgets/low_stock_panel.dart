import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../products/products_controller.dart';

class LowStockPanel extends StatelessWidget {
  final AsyncValue<List<ProductWithDetails>> productsAsync;

  const LowStockPanel({
    super.key,
    required this.productsAsync,
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
}
