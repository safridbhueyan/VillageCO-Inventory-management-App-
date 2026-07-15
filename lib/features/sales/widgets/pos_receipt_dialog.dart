import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/permission_utils.dart';
import '../../settings/settings_controller.dart';
import '../pos_controller.dart';

class PosReceiptDialog extends ConsumerWidget {
  final Sale sale;
  final PosCartState cartStateAtCheckout;
  final double paidAmount;

  const PosReceiptDialog({
    super.key,
    required this.sale,
    required this.cartStateAtCheckout,
    required this.paidAmount,
  });

  Widget _buildReceiptMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600)),
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
          Text(value, style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsList = cartStateAtCheckout.items;
    final discount = cartStateAtCheckout.discountAmount;
    final subtotal = cartStateAtCheckout.subtotal;
    final total = cartStateAtCheckout.total;
    final customer = cartStateAtCheckout.selectedCustomer;
    final paymentStr = sale.paymentMethod == 'Cash' ? 'ক্যাশ' : (sale.paymentMethod == 'Card' ? 'কার্ড' : 'মোবাইল ব্যাংকিং');

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ভিলেজকো স্টোর', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
            const Text('মুদি দোকান ও পিওএস কেন্দ্র', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const Text('মোবাইল: +৮৮০ ১৭০০০০০০০০', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 12),
            const Divider(color: Colors.black38, thickness: 1),
            _buildReceiptMetaRow('রশিদ নং', sale.id.substring(0, 8).toUpperCase()),
            _buildReceiptMetaRow('তারিখ ও সময়', Formatters.dateTime(sale.date)),
            _buildReceiptMetaRow('পেমেন্ট পদ্ধতি', paymentStr),
            _buildReceiptMetaRow('ক্রেতার নাম', customer?.name ?? 'সাধারণ কাস্টমার'),
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: itemsList.map((item) {
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
                              '${Formatters.number(item.quantity)} ${item.product.unit}',
                              style: const TextStyle(fontSize: 11, color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(Formatters.currency(item.subtotal), style: const TextStyle(fontSize: 11, color: Colors.black), textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(color: Colors.black38, thickness: 1),
            _buildReceiptFinancialRow('উপ-মোট বিল', Formatters.currency(subtotal)),
            if (discount > 0) _buildReceiptFinancialRow('ডিসকাউন্ট ছাড়', '- ${Formatters.currency(discount)}'),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('পরিশোধযোগ্য মোট বিল', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                Text(Formatters.currency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
              ],
            ),
            if (paidAmount > 0) ...[
              const SizedBox(height: 4),
              _buildReceiptFinancialRow('পরিশোধিত টাকা', Formatters.currency(paidAmount)),
              _buildReceiptFinancialRow(paidAmount >= total ? 'ফেরতযোগ্য টাকা' : 'বাকি বিল', Formatters.currency((paidAmount - total).abs())),
            ],
            const SizedBox(height: 16),
            const Text('ভিলেজকো স্টোরে কেনাকাটার জন্য ধন্যবাদ!', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.black)),
            const SizedBox(height: 8),
            const Icon(Icons.bar_chart, size: 50, color: Colors.black54),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('প্রিন্ট'),
          onPressed: () async {
            try {
              final itemsMapped = itemsList.map((i) => {
                'name': i.product.name,
                'qty': '${Formatters.number(i.quantity)} ${i.product.unit}',
                'total': Formatters.currency(i.subtotal),
              }).toList();

              await PdfGenerator.printTextReceipt(
                saleId: sale.id,
                dateStr: Formatters.dateTime(sale.date),
                paymentMethod: paymentStr,
                customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                items: itemsMapped,
                subtotal: subtotal,
                discount: discount,
                total: total,
                paidAmount: paidAmount,
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
              final hasPermission = await PermissionUtils.requestStoragePermission(context);
              if (!hasPermission) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ফাইলের সুরক্ষার জন্য স্টোরেজ পারমিশন প্রয়োজন!')));
                }
                return;
              }

              final itemsMapped = itemsList.map((i) => {
                'name': i.product.name,
                'qty': '${Formatters.number(i.quantity)} ${i.product.unit}',
                'total': Formatters.currency(i.subtotal),
              }).toList();

              final settings = ref.read(settingsControllerProvider).valueOrNull;
              final pdfSavePath = settings?.pdfSavePath;

              final savedPath = await PdfGenerator.generateAndSaveTextReceipt(
                saleId: sale.id,
                dateStr: Formatters.dateTime(sale.date),
                paymentMethod: paymentStr,
                customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                items: itemsMapped,
                subtotal: subtotal,
                discount: discount,
                total: total,
                paidAmount: paidAmount,
                customSavePath: pdfSavePath,
              );

              if (savedPath != null && context.mounted) {
                DialogUtils.showSaveSuccessDialog(context, savedPath);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF ডাউনলোড ব্যর্থ: $e')));
              }
            }
          },
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('নতুন অর্ডার'),
        ),
      ],
    );
  }
}
