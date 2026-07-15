import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../reports_controller.dart';

class ReturnsLogTab extends StatelessWidget {
  final AsyncValue<List<SalesReturnWithDetails>> returnsAsync;

  const ReturnsLogTab({
    super.key,
    required this.returnsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: returnsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('রিটার্ন খাতা লোড ব্যর্থ: $err')),
            data: (returns) {
              if (returns.isEmpty) {
                return const Center(
                  child: Text('কোনো রিফান্ড বা রিটার্নের রেকর্ড পাওয়া যায়নি।'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: returns.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final returnWithDetails = returns[index];
                  final ret = returnWithDetails.salesReturn;

                  final itemsSummary = returnWithDetails.items
                      .map((i) => '${i.product.name} (${Formatters.number(i.item.quantity)} ${i.product.unit})')
                      .join(', ');

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'রশিদ নং: ${returnWithDetails.originalSaleId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          'তারিখ ও সময়: ${Formatters.dateTime(ret.date)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (ret.reason != null && ret.reason!.isNotEmpty)
                          Text(
                            'কারণ: ${ret.reason}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey,
                            ),
                          ),
                        Text(
                          'ফেরতকৃত পণ্য: $itemsSummary',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: Text(
                      '- ${Formatters.currency(ret.refundAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
