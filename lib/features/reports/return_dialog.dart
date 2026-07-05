import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import 'reports_controller.dart';
import '../products/products_controller.dart';

class ProductReturnDialog extends ConsumerStatefulWidget {
  final SaleWithDetails saleWithDetails;

  const ProductReturnDialog({super.key, required this.saleWithDetails});

  @override
  ConsumerState<ProductReturnDialog> createState() => _ProductReturnDialogState();
}

class _ProductReturnDialogState extends ConsumerState<ProductReturnDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _fetchingReturnedData = true;
  bool _submitting = false;
  
  // Maps productId -> already returned quantity
  final Map<String, double> _alreadyReturnedQty = {};
  
  // Maps productId -> current quantity input to return
  final Map<String, double> _returnQuantities = {};
  
  // Maps productId -> isRestocked checkbox flag
  final Map<String, bool> _restockFlags = {};

  @override
  void initState() {
    super.initState();
    _loadAlreadyReturnedData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAlreadyReturnedData() async {
    try {
      final db = ref.read(databaseProvider);
      final saleId = widget.saleWithDetails.sale.id;

      final returns = await (db.select(db.salesReturns)
        ..where((t) => t.saleId.equals(saleId)))
        .get();
      
      if (returns.isNotEmpty) {
        final returnIds = returns.map((r) => r.id).toList();
        final returnedItems = await (db.select(db.salesReturnItems)
          ..where((t) => t.returnId.isIn(returnIds)))
          .get();
        
        for (final item in returnedItems) {
          _alreadyReturnedQty[item.productId] = 
              (_alreadyReturnedQty[item.productId] ?? 0.0) + item.quantity;
        }
      }
    } catch (e) {
      debugPrint('Error loading already returned data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _fetchingReturnedData = false;
        });
      }
    }
  }

  double _calculateRefundAmount() {
    double refundSubtotal = 0.0;
    
    for (final itemWithProduct in widget.saleWithDetails.items) {
      final productId = itemWithProduct.product.id;
      final returnQty = _returnQuantities[productId] ?? 0.0;
      if (returnQty > 0) {
        refundSubtotal += returnQty * itemWithProduct.item.price;
      }
    }

    // Apply proportional discount
    final sale = widget.saleWithDetails.sale;
    if (sale.subtotal > 0 && sale.discount > 0) {
      final discountFactor = 1.0 - (sale.discount / sale.subtotal);
      final netRefund = refundSubtotal * discountFactor;
      return netRefund < 0 ? 0.0 : netRefund;
    }
    
    return refundSubtotal;
  }

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) return;
    
    final refundAmount = _calculateRefundAmount();
    if (refundAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুগ্রহ করে অন্তত একটি আইটেমের রিটার্ন পরিমাণ দিন।')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();
      final returnId = const Uuid().v4();

      await db.transaction(() async {
        // 1. Insert SalesReturns record
        await db.into(db.salesReturns).insert(
          SalesReturnsCompanion(
            id: drift.Value(returnId),
            saleId: drift.Value(widget.saleWithDetails.sale.id),
            date: drift.Value(now),
            refundAmount: drift.Value(refundAmount),
            reason: drift.Value(_reasonController.text.trim().isEmpty ? null : _reasonController.text.trim()),
          ),
        );

        // 2. Insert return items and adjust stock
        for (final itemWithProduct in widget.saleWithDetails.items) {
          final productId = itemWithProduct.product.id;
          final returnQty = _returnQuantities[productId] ?? 0.0;
          
          if (returnQty > 0) {
            final isRestocked = _restockFlags[productId] ?? true;
            final returnItemId = const Uuid().v4();

            await db.into(db.salesReturnItems).insert(
              SalesReturnItemsCompanion(
                id: drift.Value(returnItemId),
                returnId: drift.Value(returnId),
                productId: drift.Value(productId),
                quantity: drift.Value(returnQty),
                price: drift.Value(itemWithProduct.item.price),
                cost: drift.Value(itemWithProduct.item.cost),
                isRestocked: drift.Value(isRestocked),
              ),
            );

            // Adjust inventory stock
            if (isRestocked) {
              final updatedStock = itemWithProduct.product.currentStock + returnQty;
              await (db.update(db.products)
                ..where((t) => t.id.equals(productId)))
                .write(ProductsCompanion(currentStock: drift.Value(updatedStock)));

              // Log StockHistory entry
              await db.into(db.stockHistory).insert(
                StockHistoryCompanion(
                  id: drift.Value(const Uuid().v4()),
                  productId: drift.Value(productId),
                  changeAmount: drift.Value(returnQty),
                  reason: drift.Value('Customer Return (Receipt: ${widget.saleWithDetails.sale.id.substring(0, 8).toUpperCase()})'),
                  date: drift.Value(now),
                ),
              );
            } else {
              // Log StockHistory entry as Wasted/Damaged (no stock change)
              await db.into(db.stockHistory).insert(
                StockHistoryCompanion(
                  id: drift.Value(const Uuid().v4()),
                  productId: drift.Value(productId),
                  changeAmount: drift.Value(0.0),
                  reason: drift.Value('Return Wasted (Receipt: ${widget.saleWithDetails.sale.id.substring(0, 8).toUpperCase()})'),
                  date: drift.Value(now),
                ),
              );
            }
          }
        }
      });

      // Invalidate queries
      ref.invalidate(productsListProvider);
      ref.invalidate(salesHistoryProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(topSellingProductsProvider);
      ref.invalidate(returnsHistoryProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('রিটার্ন সফলভাবে সম্পন্ন হয়েছে।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('রিটার্ন সাবমিট করতে ব্যর্থ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sale = widget.saleWithDetails.sale;

    if (_fetchingReturnedData) {
      return const AlertDialog(
        backgroundColor: Colors.white,
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final refundAmount = _calculateRefundAmount();

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'পণ্য রিটার্ন / ফেরত',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'রশিদ নং: ${sale.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'রিটার্ন আইটেম নির্বাচন করুন:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.saleWithDetails.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final itemWithProduct = widget.saleWithDetails.items[index];
                    final productId = itemWithProduct.product.id;
                    final originalQty = itemWithProduct.item.quantity;
                    final alreadyReturned = _alreadyReturnedQty[productId] ?? 0.0;
                    final maxReturnable = originalQty - alreadyReturned;

                    if (maxReturnable <= 0) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(itemWithProduct.product.name, style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        subtitle: const Text('সম্পূর্ণ পরিমাণ ইতিমধ্যেই ফেরত নেওয়া হয়েছে', style: TextStyle(color: Colors.red, fontSize: 10)),
                      );
                    }

                    _restockFlags.putIfAbsent(productId, () => true);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemWithProduct.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ক্রয়মূল্য: ${Formatters.currency(itemWithProduct.item.price)} • মূল পরিমাণ: ${Formatters.number(originalQty)} ${itemWithProduct.product.unit}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  if (alreadyReturned > 0)
                                    Text(
                                      'পূর্বে ফেরত নেওয়া হয়েছে: ${Formatters.number(alreadyReturned)} ${itemWithProduct.product.unit}',
                                      style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: '0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  labelText: 'পরিমাণ',
                                ),
                                style: const TextStyle(fontSize: 12),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return null;
                                  final numVal = double.tryParse(val);
                                  if (numVal == null) return 'ভুল সংখ্যা';
                                  if (numVal < 0) return 'ঋণাত্মক নয়';
                                  if (numVal > maxReturnable) return 'অনূর্ধ্ব $maxReturnable';
                                  return null;
                                },
                                onChanged: (val) {
                                  setState(() {
                                    _returnQuantities[productId] = double.tryParse(val) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if ((_returnQuantities[productId] ?? 0.0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _restockFlags[productId],
                                    onChanged: (val) {
                                      setState(() {
                                        _restockFlags[productId] = val ?? true;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'স্টকে ফেরত নিয়ে যোগ করুন (Restock)',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'ফেরত নেওয়ার কারণ (ঐচ্ছিক)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ফেরতযোগ্য মোট রিফান্ড:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        Formatters.currency(refundAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submitReturn,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('নিশ্চিত করুন'),
        ),
      ],
    );
  }
}
