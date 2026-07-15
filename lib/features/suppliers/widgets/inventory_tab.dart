import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../suppliers_controller.dart';

class InventoryTab extends ConsumerWidget {
  final String supplierId;

  const InventoryTab({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsBySupplierProvider(supplierId));

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error loading products: $err')),
      data: (products) {
        final lowStockProducts = products.where((p) => p.currentStock <= p.minimumStock).toList();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lowStockProducts.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'রিকুইজিশন প্রয়োজন! (Requisition Alert)',
                              style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'নিম্নোক্ত পণ্যগুলোর স্টক ফুরিয়ে যাচ্ছে: ${lowStockProducts.map((p) => p.name).join(', ')}',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              Text('সাপ্লাইড পণ্য ও স্টক (${products.length}টি)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              if (products.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('এই সরবরাহকারীর অধীনে কোনো পণ্য তালিকাভুক্ত নেই।', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final isLow = p.currentStock <= p.minimumStock;
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ProductImageWidget(
                        imagePath: p.imagePath,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        borderRadius: 8,
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p.brand ?? 'No Brand'} • Unit: ${p.unit}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${Formatters.number(p.currentStock)} stock',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isLow ? Colors.red : Colors.green,
                            ),
                          ),
                          if (isLow)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                              child: const Text('নিম্ন স্টক', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
