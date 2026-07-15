import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../reports_controller.dart';
import 'invoice_receipt_dialog.dart';

class SalesLogTab extends ConsumerWidget {
  final AsyncValue<List<SaleWithDetails>> salesHistoryAsync;

  const SalesLogTab({
    super.key,
    required this.salesHistoryAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(salesFilterProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'রশিদ আইডি বা কাস্টমারের নাম দিয়ে খুঁজুন...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    ref.read(salesFilterProvider.notifier).update((s) => s.copyWith(searchQuery: val));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: filter.paymentMethod,
                    hint: const Text('পদ্ধতি'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('সব')),
                      DropdownMenuItem(value: 'Cash', child: Text('ক্যাশ')),
                      DropdownMenuItem(
                        value: 'Mobile Banking',
                        child: Text('মোবাইল'),
                      ),
                      DropdownMenuItem(value: 'Card', child: Text('কার্ড')),
                    ],
                    onChanged: (val) {
                      ref.read(salesFilterProvider.notifier).update((s) => s.copyWith(paymentMethod: val));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: salesHistoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('বিক্রি লগ লোড ব্যর্থ: $err')),
            data: (sales) {
              if (sales.isEmpty) {
                return const Center(
                  child: Text('ম্যাচিং কোনো বিক্রির রেকর্ড পাওয়া যায়নি।'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sales.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final saleWithDetails = sales[index];
                  final sale = saleWithDetails.sale;
                  final customer = saleWithDetails.customer?.name ?? 'সাধারণ কাস্টমার';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      customer,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'রশিদ: ${sale.id.substring(0, 8).toUpperCase()} • ${Formatters.dateTime(sale.date)} • ${sale.paymentMethod == "Cash" ? "ক্যাশ" : (sale.paymentMethod == "Card" ? "কার্ড" : "মোবাইল")}',
                    ),
                    trailing: Text(
                      Formatters.currency(sale.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => InvoiceReceiptDialog(saleWithDetails: saleWithDetails),
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
