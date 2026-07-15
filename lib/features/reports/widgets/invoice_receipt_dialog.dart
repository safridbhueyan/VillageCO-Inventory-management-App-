import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/formatters.dart';
import '../reports_controller.dart';
import '../return_dialog.dart';

class InvoiceReceiptDialog extends ConsumerWidget {
  final SaleWithDetails saleWithDetails;

  const InvoiceReceiptDialog({
    super.key,
    required this.saleWithDetails,
  });

  Widget _buildReceiptMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptFinancialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(
            value,
            style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = saleWithDetails.sale;
    final customer = saleWithDetails.customer;
    final itemsList = saleWithDetails.items;
    final historyReceiptKey = GlobalKey();
    final paymentStr = sale.paymentMethod == 'Cash' ? 'ক্যাশ' : (sale.paymentMethod == 'Card' ? 'কার্ড' : 'মোবাইল ব্যাংকিং');

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      content: SizedBox(
        width: 380,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: historyReceiptKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ভিলেজকো স্টোর',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                    ),
                    const Text(
                      'বিক্রির রশিদের কপি',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.black38, thickness: 1),
                    _buildReceiptMetaRow('রশিদ নং', sale.id.substring(0, 8).toUpperCase()),
                    _buildReceiptMetaRow('তারিখ ও সময়', Formatters.dateTime(sale.date)),
                    _buildReceiptMetaRow('পেমেন্ট পদ্ধতি', paymentStr),
                    _buildReceiptMetaRow('ক্রেতা', customer?.name ?? 'সাধারণ কাস্টমার'),
                    const Divider(color: Colors.black38, thickness: 1),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(flex: 3, child: Text('পণ্যের বিবরণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                        Expanded(flex: 1, child: Text('পরিমাণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('মোট টাকা', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.right)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Column(
                      children: itemsList.map((item) {
                        final subtotal = item.item.price * item.item.quantity;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.product.name,
                                  style: const TextStyle(fontSize: 11, color: Colors.black),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${Formatters.number(item.item.quantity)} ${item.product.unit}',
                                  style: const TextStyle(fontSize: 11, color: Colors.black),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Formatters.currency(subtotal),
                                  style: const TextStyle(fontSize: 11, color: Colors.black),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(color: Colors.black38, thickness: 1),
                    _buildReceiptFinancialRow('উপ-মোট বিল', Formatters.currency(sale.subtotal)),
                    _buildReceiptFinancialRow('ডিসকাউন্ট ছাড়', '- ${Formatters.currency(sale.discount)}'),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'পরিশোধযোগ্য মোট বিল',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                        ),
                        Text(
                          Formatters.currency(sale.total),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বন্ধ করুন'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.keyboard_return_rounded),
          label: const Text('পণ্য ফেরত/রিটার্ন'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => ProductReturnDialog(saleWithDetails: saleWithDetails),
            );
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('প্রিন্ট'),
          onPressed: () async {
            try {
              final itemsMapped = itemsList.map((i) => {
                'name': i.product.name,
                'qty': '${Formatters.number(i.item.quantity)} ${i.product.unit}',
                'total': Formatters.currency(i.item.price * i.item.quantity),
              }).toList();

              await PdfGenerator.printTextReceipt(
                saleId: sale.id,
                dateStr: Formatters.dateTime(sale.date),
                paymentMethod: paymentStr,
                customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                items: itemsMapped,
                subtotal: sale.subtotal,
                discount: sale.discount,
                total: sale.total,
                paidAmount: sale.total,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('প্রিন্ট ব্যর্থ হয়েছে: $e')));
              }
            }
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('PDF রসিদ'),
          onPressed: () async {
            try {
              final itemsMapped = itemsList.map((i) => {
                'name': i.product.name,
                'qty': '${Formatters.number(i.item.quantity)} ${i.product.unit}',
                'total': Formatters.currency(i.item.price * i.item.quantity),
              }).toList();

              await PdfGenerator.generateAndSaveTextReceipt(
                saleId: sale.id,
                dateStr: Formatters.dateTime(sale.date),
                paymentMethod: paymentStr,
                customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                items: itemsMapped,
                subtotal: sale.subtotal,
                discount: sale.discount,
                total: sale.total,
                paidAmount: sale.total,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('রসিদটি সফলভাবে ডাউনলোড করা হয়েছে')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF তৈরি করতে ব্যর্থ: $e')));
              }
            }
          },
        ),
      ],
    );
  }
}
