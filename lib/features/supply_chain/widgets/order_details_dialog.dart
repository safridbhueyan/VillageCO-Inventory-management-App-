import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_generator.dart';
import '../supply_chain_controller.dart';

class OrderDetailsDialog extends StatelessWidget {
  final SupplyChainOrder order;
  final String Function(String) getStatusText;
  final String Function(String) getPaymentStatusText;

  const OrderDetailsDialog({
    super.key,
    required this.order,
    required this.getStatusText,
    required this.getPaymentStatusText,
  });

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('অর্ডার বিবরণী', style: TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('অर्डर আইডি', order.id),
            _detailRow('তারিখ', Formatters.dateTime(order.createdAt)),
            _detailRow('স্ট্যাটাস', getStatusText(order.status)),
            _detailRow('অনুরোধকারী', order.fromStoreName),
            _detailRow('সরবরাহকারী', order.toStoreName),
            const Divider(height: 20),
            _detailRow('পণ্য', order.productName),
            _detailRow('বারকোড', order.productBarcode.isNotEmpty ? order.productBarcode : 'N/A'),
            _detailRow('একক মূল্য', Formatters.currency(order.productSellingPrice)),
            _detailRow('অনুরোধকৃত পরিমাণ', '${order.quantityRequested} ${order.productUnit}'),
            if (order.approvedByAdmin) ...[
              _detailRow('প্রেরিত পরিমাণ', '${order.quantitySent} ${order.productUnit}'),
              _detailRow('গৃহীত পরিমাণ', '${order.quantityReceived} ${order.productUnit}'),
            ],
            const Divider(height: 20),
            _detailRow('মোট মূল্য', Formatters.currency(order.totalPrice)),
            _detailRow('পরিশোধিত', Formatters.currency(order.amountPaid)),
            _detailRow('বকেয়া', Formatters.currency(order.paymentDue), isBold: true),
            _detailRow('পেমেন্ট অবস্থা', getPaymentStatusText(order.paymentStatus)),
          ],
        ),
      ),
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.print_rounded),
          label: const Text('ইনভয়েস প্রিন্ট'),
          onPressed: () {
            Navigator.pop(context);
            PdfGenerator.printSupplyChainOrder(order);
          },
        ),
      ],
    );
  }
}

class UpdatePaymentDialog extends ConsumerStatefulWidget {
  final SupplyChainOrder order;

  const UpdatePaymentDialog({super.key, required this.order});

  @override
  ConsumerState<UpdatePaymentDialog> createState() => _UpdatePaymentDialogState();
}

class _UpdatePaymentDialogState extends ConsumerState<UpdatePaymentDialog> {
  late final TextEditingController controller;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.order.amountPaid.toStringAsFixed(2));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('পেমেন্ট আপডেট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('মোট মূল্য: ${Formatters.currency(widget.order.totalPrice)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'পরিশোধিত পরিমাণ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'পরিমাণ লিখুন';
                final amount = double.tryParse(val);
                if (amount == null) return 'সঠিক সংখ্যা দিন';
                if (amount < 0) return 'পরিমাণ ০ এর কম হতে পারবে না';
                if (amount > widget.order.totalPrice) return 'পরিমাণ মোট মূল্যের বেশি হতে পারবে না';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState?.validate() ?? false) {
              final amount = double.parse(controller.text);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              try {
                await ref.read(supplyChainServiceProvider).updatePayment(widget.order.id, amount);
                if (context.mounted) {
                  Navigator.pop(context); // dismiss loading
                  Navigator.pop(context); // dismiss update dialog
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('পেমেন্ট আপডেট ব্যর্থ: $e')));
                }
              }
            }
          },
          child: const Text('সংরক্ষণ'),
        ),
      ],
    );
  }
}
