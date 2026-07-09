import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import 'reports_controller.dart';
import '../products/products_controller.dart';
import '../../core/database/firebase_sync_service.dart';

// Riverpod state providers for returns dialog
final returnFetchingProvider = StateProvider.autoDispose.family<bool, String>((ref, saleId) => true);
final returnSubmittingProvider = StateProvider.autoDispose.family<bool, String>((ref, saleId) => false);
final alreadyReturnedQtyProvider = StateProvider.autoDispose.family<Map<String, double>, String>((ref, saleId) => {});
final returnQuantitiesProvider = StateProvider.autoDispose.family<Map<String, double>, String>((ref, saleId) => {});
final returnRestockFlagsProvider = StateProvider.autoDispose.family<Map<String, bool>, String>((ref, saleId) => {});

class ProductReturnDialog extends ConsumerStatefulWidget {
  final SaleWithDetails saleWithDetails;

  const ProductReturnDialog({super.key, required this.saleWithDetails});

  @override
  ConsumerState<ProductReturnDialog> createState() => _ProductReturnDialogState();
}

class _ProductReturnDialogState extends ConsumerState<ProductReturnDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAlreadyReturnedData();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAlreadyReturnedData() async {
    final saleId = widget.saleWithDetails.sale.id;
    try {
      final db = ref.read(databaseProvider);

      final returns = await (db.select(db.salesReturns)
        ..where((t) => t.saleId.equals(saleId)))
        .get();
      
      if (returns.isNotEmpty) {
        final returnIds = returns.map((r) => r.id).toList();
        final returnedItems = await (db.select(db.salesReturnItems)
          ..where((t) => t.returnId.isIn(returnIds)))
          .get();
        
        final Map<String, double> temp = {};
        for (final item in returnedItems) {
          temp[item.productId] = (temp[item.productId] ?? 0.0) + item.quantity;
        }
        ref.read(alreadyReturnedQtyProvider(saleId).notifier).state = temp;
      }
    } catch (e) {
      debugPrint('Error loading already returned data: $e');
    } finally {
      ref.read(returnFetchingProvider(saleId).notifier).state = false;
    }
  }

  double _calculateRefundAmount() {
    final saleId = widget.saleWithDetails.sale.id;
    final returnQuantities = ref.read(returnQuantitiesProvider(saleId));
    double refundSubtotal = 0.0;
    
    for (final itemWithProduct in widget.saleWithDetails.items) {
      final productId = itemWithProduct.product.id;
      final returnQty = returnQuantities[productId] ?? 0.0;
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
    
    final saleId = widget.saleWithDetails.sale.id;
    final refundAmount = _calculateRefundAmount();
    if (refundAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুগ্রহ করে অন্তত একটি আইটেমের রিটার্ন পরিমাণ দিন।')),
      );
      return;
    }

    ref.read(returnSubmittingProvider(saleId).notifier).state = true;

    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();
      final returnId = const Uuid().v4();
      final returnQuantities = ref.read(returnQuantitiesProvider(saleId));
      final restockFlags = ref.read(returnRestockFlagsProvider(saleId));

      await db.transaction(() async {
        // 1. Insert SalesReturns record
        await db.into(db.salesReturns).insert(
          SalesReturnsCompanion(
            id: drift.Value(returnId),
            saleId: drift.Value(saleId),
            date: drift.Value(now),
            refundAmount: drift.Value(refundAmount),
            reason: drift.Value(_reasonController.text.trim().isEmpty ? null : _reasonController.text.trim()),
          ),
        );

        // 2. Insert return items and adjust stock
        for (final itemWithProduct in widget.saleWithDetails.items) {
          final productId = itemWithProduct.product.id;
          final returnQty = returnQuantities[productId] ?? 0.0;
          
          if (returnQty > 0) {
            final isRestocked = restockFlags[productId] ?? true;
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

            // Adjust inventory stock (fetching latest stock to prevent stale overrides)
            if (isRestocked) {
              final dbProduct = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
              final updatedStock = dbProduct.currentStock + returnQty;
              await (db.update(db.products)
                ..where((t) => t.id.equals(productId)))
                .write(ProductsCompanion(currentStock: drift.Value(updatedStock)));

              // Log StockHistory entry
              await db.into(db.stockHistory).insert(
                StockHistoryCompanion(
                  id: drift.Value(const Uuid().v4()),
                  productId: drift.Value(productId),
                  changeAmount: drift.Value(returnQty),
                  reason: drift.Value('Customer Return (Receipt: ${saleId.substring(0, 8).toUpperCase()})'),
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
                  reason: drift.Value('Return Wasted (Receipt: ${saleId.substring(0, 8).toUpperCase()})'),
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

      // Trigger automatic background database sync to Firebase
      triggerAutoSync(ref);

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
      ref.read(returnSubmittingProvider(saleId).notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sale = widget.saleWithDetails.sale;
    final saleId = sale.id;

    final fetching = ref.watch(returnFetchingProvider(saleId));
    final submitting = ref.watch(returnSubmittingProvider(saleId));
    final alreadyReturnedQty = ref.watch(alreadyReturnedQtyProvider(saleId));
    final returnQuantities = ref.watch(returnQuantitiesProvider(saleId));
    final restockFlags = ref.watch(returnRestockFlagsProvider(saleId));

    if (fetching) {
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
                    final alreadyReturned = alreadyReturnedQty[productId] ?? 0.0;
                    final maxReturnable = originalQty - alreadyReturned;

                    if (maxReturnable <= 0) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(itemWithProduct.product.name, style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        subtitle: const Text('সম্পূর্ণ পরিমাণ ইতিমধ্যেই ফেরত নেওয়া হয়েছে', style: TextStyle(color: Colors.red, fontSize: 10)),
                      );
                    }

                    final isRestocked = restockFlags[productId] ?? true;
                    final currentQty = returnQuantities[productId] ?? 0.0;

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
                                initialValue: currentQty > 0 ? Formatters.number(currentQty) : '0',
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
                                  final valDouble = double.tryParse(val) ?? 0.0;
                                  ref.read(returnQuantitiesProvider(saleId).notifier).update((state) {
                                    final copy = Map<String, double>.from(state);
                                    copy[productId] = valDouble;
                                    return copy;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if (currentQty > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: isRestocked,
                                    onChanged: (val) {
                                      final restockVal = val ?? true;
                                      ref.read(returnRestockFlagsProvider(saleId).notifier).update((state) {
                                        final copy = Map<String, bool>.from(state);
                                        copy[productId] = restockVal;
                                        return copy;
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
          onPressed: submitting ? null : () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(
          onPressed: submitting ? null : _submitReturn,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: submitting
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
