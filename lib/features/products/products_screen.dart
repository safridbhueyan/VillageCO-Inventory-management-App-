import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import 'products_controller.dart';
import 'widgets/empty_products_state.dart';
import 'widgets/products_filter_panel.dart';
import 'widgets/product_grid_card.dart';
import 'widgets/product_slidable_tile.dart';
import 'widgets/product_details_sheet.dart';
import 'widgets/bulk_stock_update_dialog.dart';
import 'widgets/product_form_sheet.dart';

final productsMultiSelectModeProvider = StateProvider.autoDispose<bool>((ref) => false);
final productsSelectedIdsProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  void _toggleSelection(String id) {
    final selected = ref.read(productsSelectedIdsProvider);
    final copy = Set<String>.from(selected);
    if (copy.contains(id)) {
      copy.remove(id);
      if (copy.isEmpty) {
        ref.read(productsMultiSelectModeProvider.notifier).state = false;
      }
    } else {
      copy.add(id);
      ref.read(productsMultiSelectModeProvider.notifier).state = true;
    }
    ref.read(productsSelectedIdsProvider.notifier).state = copy;
  }

  void _clearSelection() {
    ref.read(productsSelectedIdsProvider.notifier).state = {};
    ref.read(productsMultiSelectModeProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final isMultiSelectMode = ref.watch(productsMultiSelectModeProvider);
    final selectedIds = ref.watch(productsSelectedIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMultiSelectMode ? '${selectedIds.length}টি পণ্য সিলেক্ট করা হয়েছে' : 'পণ্য তালিকা',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'স্টক পরিবর্তন করুন',
              onPressed: () => _showBulkStockUpdateDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'মুছে ফেলুন',
              onPressed: () => _confirmBulkDelete(context),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'বাতিল',
              onPressed: _clearSelection,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'নতুন পণ্য যোগ',
              onPressed: () => _showProductFormDialog(context),
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          const ProductsFilterPanel(),
          const Divider(height: 1),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('লোড করতে ত্রুটি হয়েছে: $err')),
              data: (products) {
                if (products.isEmpty) {
                  return const EmptyProductsState();
                }

                final double width = MediaQuery.of(context).size.width;
                final bool isDesktop = width > 850;

                if (isDesktop) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final item = products[index];
                      final isSelected = selectedIds.contains(item.product.id);
                      return ProductGridCard(
                        item: item,
                        isSelected: isSelected,
                        onLongPress: () => _toggleSelection(item.product.id),
                        onTap: () {
                          if (ref.read(productsMultiSelectModeProvider)) {
                            _toggleSelection(item.product.id);
                          } else {
                            _showProductDetailsSheet(context, item);
                          }
                        },
                      );
                    },
                  );
                } else {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = products[index];
                      final isSelected = selectedIds.contains(item.product.id);
                      return ProductSlidableTile(
                        item: item,
                        isSelected: isSelected,
                        onLongPress: () => _toggleSelection(item.product.id),
                        onTap: () {
                          if (ref.read(productsMultiSelectModeProvider)) {
                            _toggleSelection(item.product.id);
                          } else {
                            _showProductDetailsSheet(context, item);
                          }
                        },
                        onEdit: () => _showProductFormDialog(context, product: item.product),
                        onDelete: () => _confirmSingleDelete(context, item.product.id, item.product.name),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProductDetailsSheet(BuildContext context, ProductWithDetails item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProductDetailsSheet(
        item: item,
        onEdit: () => _showProductFormDialog(context, product: item.product),
        onDelete: () => _confirmSingleDelete(context, item.product.id, item.product.name),
      ),
    );
  }

  void _confirmSingleDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('পণ্যটি কি মুছে ফেলবেন?'),
        content: Text('আপনি কি নিশ্চিত যে "$name" মুছে ফেলতে চান? এর ফলে এই পণ্যের সব স্টক রিপোর্টও মুছে যাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(productsRepositoryProvider).deleteProduct(id);
            },
            child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('সিলেক্ট করা পণ্য মুছে ফেলবেন?'),
        content: Text('আপনি কি নিশ্চিত যে সিলেক্ট করা ${ref.read(productsSelectedIdsProvider).length}টি পণ্য মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(productsRepositoryProvider).bulkDelete(ref.read(productsSelectedIdsProvider).toList());
              _clearSelection();
            },
            child: const Text('সব মুছুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBulkStockUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BulkStockUpdateDialog(
        selectedIds: ref.read(productsSelectedIdsProvider).toList(),
        onApply: _clearSelection,
      ),
    );
  }

  void _showProductFormDialog(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductFormSheet(product: product),
    );
  }
}
