import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../products/products_controller.dart';

class ExpiryTab extends ConsumerWidget {
  const ExpiryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsListProvider);
    final theme = Theme.of(context);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('পণ্য লোড ব্যর্থ: $err')),
      data: (list) {
        final now = DateTime.now();
        final expiredList = list.where((p) {
          final exp = p.product.expiryDate;
          return exp != null && exp.isBefore(now);
        }).toList();

        final expiringSoonList = list.where((p) {
          final exp = p.product.expiryDate;
          return exp != null && exp.isAfter(now) && exp.isBefore(now.add(const Duration(days: 30)));
        }).toList();

        if (expiredList.isEmpty && expiringSoonList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'কোনো মেয়াদোত্তীর্ণ পণ্য নেই',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'সকল পণ্য নিরাপদ এবং ব্যবহারের উপযোগী।',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (expiredList.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.dangerous_outlined, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'মেয়াদোত্তীর্ণ পণ্য (${expiredList.length}টি)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expiredList.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final p = expiredList[index].product;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ব্যাচ: ${p.batchNumber ?? "নেই"} • স্টক: ${Formatters.number(p.currentStock)} ${p.unit}'),
                    trailing: Text(
                      'মেয়াদ শেষ: ${Formatters.date(p.expiryDate!)}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (expiringSoonList.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    '৩০ দিনের মধ্যে মেয়াদ শেষ হবে (${expiringSoonList.length}টি)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expiringSoonList.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final p = expiringSoonList[index].product;
                  final daysLeft = p.expiryDate!.difference(now).inDays;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ব্যাচ: ${p.batchNumber ?? "নেই"} • স্টক: ${Formatters.number(p.currentStock)} ${p.unit}'),
                    trailing: Text(
                      'বাকী: $daysLeft দিন (${Formatters.date(p.expiryDate!)})',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
