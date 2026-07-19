import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/image_utils.dart';
import '../suppliers_controller.dart';

class AddOrderDialog extends ConsumerStatefulWidget {
  final String supplierId;

  const AddOrderDialog({super.key, required this.supplierId});

  @override
  ConsumerState<AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends ConsumerState<AddOrderDialog> {
  final qtyController = TextEditingController();
  final costController = TextEditingController();
  final paidController = TextEditingController();
  final unitPriceController = TextEditingController();
  
  String? selectedProdId;
  String status = 'Pending';
  File? _chalanImage;

  @override
  void dispose() {
    qtyController.dispose();
    costController.dispose();
    paidController.dispose();
    unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsBySupplierProvider(widget.supplierId));

    return AlertDialog(
      title: const Text('নতুন রিকুইজিশন / অর্ডার লোগ করুন'),
      content: productsAsync.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (err, st) => Text('Error loading products: $err'),
        data: (products) {
          if (products.isEmpty) {
            return const Text('অর্ডার রেকর্ড করতে প্রথমে এই সরবরাহকারীর অধীনে পণ্য যুক্ত করুন।');
          }

          return StatefulBuilder(
            builder: (context, setDlgState) {
              void updateCost() {
                final qty = double.tryParse(qtyController.text) ?? 0.0;
                final unitPrice = double.tryParse(unitPriceController.text) ?? 0.0;
                if (qty > 0 && unitPrice > 0) {
                  setDlgState(() {
                    costController.text = (qty * unitPrice).toStringAsFixed(2);
                  });
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedProdId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'পণ্য সিলেক্ট করুন *', border: OutlineInputBorder()),
                      items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (val) {
                        setDlgState(() {
                          selectedProdId = val;
                          final prod = products.cast<Product?>().firstWhere((p) => p?.id == val, orElse: () => null);
                          if (prod != null) {
                            unitPriceController.text = prod.buyingPrice.toStringAsFixed(2);
                            updateCost();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'অর্ডার পরিমাণ (Quantity) *', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => updateCost(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitPriceController,
                      decoration: const InputDecoration(labelText: 'ক্রয়মূল্য প্রতি ইউনিট (Unit Buying Price) *', border: OutlineInputBorder(), prefixText: '৳'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => updateCost(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(labelText: 'মোট মূল্য (Total Cost) *', border: OutlineInputBorder(), prefixText: '৳'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: paidController,
                      decoration: const InputDecoration(labelText: 'পরিশোধিত মূল্য (Paid Amount)', border: OutlineInputBorder(), prefixText: '৳'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ডেলিভারি স্ট্যাটাস', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Pending', child: Text('Pending (অপেক্ষমান)')),
                        DropdownMenuItem(value: 'Partially Received', child: Text('Partially (আংশিক গ্রহণ)')),
                        DropdownMenuItem(value: 'Received', child: Text('Received (পূর্ণ গ্রহণ)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            status = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _chalanImage == null ? 'চালান ছবি: যুক্ত করা হয়নি' : 'চালান ছবি: যুক্ত করা হয়েছে',
                            style: TextStyle(
                              fontSize: 12,
                              color: _chalanImage == null ? Colors.grey : Colors.green,
                              fontWeight: _chalanImage == null ? FontWeight.normal : FontWeight.bold,
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
                          label: const Text('ছবি তুলুন', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () {
            if (selectedProdId == null) return;
            final qty = double.tryParse(qtyController.text) ?? 0.0;
            final cost = double.tryParse(costController.text) ?? 0.0;
            final paid = double.tryParse(paidController.text) ?? 0.0;
            final unitPrice = double.tryParse(unitPriceController.text);
            if (qty <= 0 || cost <= 0) return;

            final qtyReceived = status == 'Received' ? qty : 0.0;

            ref.read(suppliersControllerProvider.notifier).addSupplierOrder(
              supplierId: widget.supplierId,
              productId: selectedProdId!,
              qtyOrdered: qty,
              qtyReceived: qtyReceived,
              totalCost: cost,
              amtPaid: paid,
              date: DateTime.now(),
              status: status,
              newBuyingPrice: unitPrice,
              localChalanPath: _chalanImage?.path,
            );
            Navigator.pop(context);
          },
          child: const Text('সংরক্ষণ করুন'),
        ),
      ],
    );
  }
}
