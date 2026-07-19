import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_utils.dart';
import '../suppliers_controller.dart';

class UpdateOrderDialog extends ConsumerStatefulWidget {
  final SupplierOrder order;
  final String supplierId;

  const UpdateOrderDialog({super.key, required this.order, required this.supplierId});

  @override
  ConsumerState<UpdateOrderDialog> createState() => _UpdateOrderDialogState();
}

class _UpdateOrderDialogState extends ConsumerState<UpdateOrderDialog> {
  final addQtyController = TextEditingController();
  final addPaidController = TextEditingController();
  late String status;
  File? _chalanImage;

  @override
  void initState() {
    super.initState();
    status = widget.order.status;
  }

  @override
  void dispose() {
    addQtyController.dispose();
    addPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final due = widget.order.totalCost - widget.order.amountPaid;
    final pending = widget.order.quantityOrdered - widget.order.quantityReceived;

    return AlertDialog(
      title: const Text('অর্ডার তথ্য আপডেট করুন'),
      content: StatefulBuilder(
        builder: (context, setDlgState) {
          final hasExistingChalan = widget.order.chalanPic != null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('বাকি পণ্য: ${Formatters.number(pending)} units', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('বকেয়া টাকা: ${Formatters.currency(due)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Divider(),
              TextField(
                controller: addQtyController,
                decoration: const InputDecoration(labelText: 'নতুন গ্রহণকৃত পণ্য সংখ্যা', border: OutlineInputBorder(), hintText: 'যেমন: ৫'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addPaidController,
                decoration: const InputDecoration(labelText: 'নতুন পরিশোধিত অর্থ', border: OutlineInputBorder(), prefixText: '৳', hintText: 'যেমন: ৫০০'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'স্ট্যাটাস বদলুন', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Pending', child: Text('Pending (অপেক্ষমান)')),
                  DropdownMenuItem(value: 'Partially Received', child: Text('Partially (আংশিক গ্রহণ)')),
                  DropdownMenuItem(value: 'Received', child: Text('Received (পূর্ণ গ্রহণ)')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => status = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _chalanImage != null
                          ? 'নতুন চালান ছবি সিলেক্ট করা হয়েছে'
                          : (hasExistingChalan ? 'চালান ছবি: আপলোড করা আছে' : 'চালান ছবি: যুক্ত করা হয়নি'),
                      style: TextStyle(
                        fontSize: 12,
                        color: (_chalanImage != null || hasExistingChalan) ? Colors.green : Colors.grey,
                        fontWeight: (_chalanImage != null || hasExistingChalan) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final file = await ImageUtils.pickAndCropImage(context);
                      if (file != null) {
                        setDlgState(() {
                          _chalanImage = file;
                        });
                      }
                    },
                    icon: const Icon(Icons.camera_alt, size: 14),
                    label: Text(hasExistingChalan ? 'বদলান' : 'ছবি তুলুন', style: const TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () {
            final addedReceived = double.tryParse(addQtyController.text) ?? 0.0;
            final addedPaid = double.tryParse(addPaidController.text) ?? 0.0;

            ref.read(suppliersControllerProvider.notifier).updateSupplierOrderPaidAndReceived(
              orderId: widget.order.id,
              supplierId: widget.supplierId,
              addedReceived: addedReceived,
              addedPaid: addedPaid,
              status: status,
              localChalanPath: _chalanImage?.path,
            );
            Navigator.pop(context);
          },
          child: const Text('আপডেট'),
        ),
      ],
    );
  }
}
