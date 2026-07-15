import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../products/products_controller.dart';
import 'stock_status_badge.dart';

class StockStatusTab extends StatelessWidget {
  final AsyncValue<List<ProductWithDetails>> productsAsync;

  const StockStatusTab({
    super.key,
    required this.productsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('লোড করতে ত্রুটি হয়েছে: $err')),
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('কোনো পণ্য পাওয়া যায়নি। পণ্য তালিকা থেকে পণ্য যোগ করুন।'));
        }

        return Column(
          children: [
            if (isDesktop)
              Container(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('পণ্যের নাম', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('ক্যাটাগরি', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('স্টক পরিমাণ', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('ক্রয়মূল্য', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('বিক্রয়মূল্য', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('নিট লাভ', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('অবস্থা', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: isDesktop ? const EdgeInsets.all(8) : const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = products[index];
                  final p = item.product;
                  final categoryName = item.category?.name ?? 'ক্যাটাগরি ছাড়া';
                  final profit = p.sellingPrice - p.buyingPrice;

                  if (isDesktop) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 8, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(categoryName)),
                          Expanded(flex: 1, child: Text('${Formatters.number(p.currentStock)} ${p.unit}')),
                          Expanded(flex: 1, child: Text(Formatters.currency(p.buyingPrice))),
                          Expanded(flex: 1, child: Text(Formatters.currency(p.sellingPrice))),
                          Expanded(flex: 1, child: Text(Formatters.currency(profit), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          Expanded(
                            flex: 1,
                            child: StockStatusBadge(currentStock: p.currentStock, minimumStock: p.minimumStock),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$categoryName • কেনা: ${Formatters.currency(p.buyingPrice)} • লাভ: ${Formatters.currency(profit)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${Formatters.number(p.currentStock)} ${p.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          StockStatusBadge(currentStock: p.currentStock, minimumStock: p.minimumStock),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
