import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../inventory_controller.dart';

class StockLogsTab extends StatelessWidget {
  final AsyncValue<List<StockHistoryWithDetails>> logsAsync;

  const StockLogsTab({
    super.key,
    required this.logsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('লগ লোড করতে ত্রুটি: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('এখনও কোনো স্টক পরিবর্তন করা হয়নি।'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final entry = logs[index];
            final product = entry.product;
            final log = entry.log;
            final isAddition = log.changeAmount > 0;
            final supplierText = entry.supplier != null ? ' • সরবরাহকারী: ${entry.supplier!.name}' : '';

            return ListTile(
              leading: Icon(
                isAddition ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                color: isAddition ? Colors.green : Colors.red,
                size: 28,
              ),
              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${log.reason}$supplierText\n${Formatters.dateTime(log.date)}'),
              isThreeLine: true,
              trailing: Text(
                '${isAddition ? '+' : ''}${Formatters.number(log.changeAmount)} ${product.unit}',
                style: TextStyle(
                  color: isAddition ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
