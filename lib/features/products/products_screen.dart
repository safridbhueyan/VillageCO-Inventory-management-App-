import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/database/database.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_utils.dart';
import 'products_controller.dart';
import '../categories/categories_controller.dart';
import '../suppliers/suppliers_controller.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedIds.add(id);
        _isMultiSelectMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isMultiSelectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsListProvider);
    final filter = ref.watch(productsFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isMultiSelectMode ? '${_selectedIds.length}টি পণ্য সিলেক্ট করা হয়েছে' : 'পণ্য তালিকা',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isMultiSelectMode) ...[
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
          _buildFilterPanel(context, filter),
          const Divider(height: 1),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('লোড করতে ত্রুটি হয়েছে: $err')),
              data: (products) {
                if (products.isEmpty) {
                  return const _EmptyProductsState();
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
                      final isSelected = _selectedIds.contains(item.product.id);
                      return _buildProductGridCard(context, item, isSelected);
                    },
                  );
                } else {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = products[index];
                      final isSelected = _selectedIds.contains(item.product.id);
                      return _buildProductSlidableTile(context, item, isSelected);
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

  Widget _buildFilterPanel(BuildContext context, ProductsFilterState filter) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'নাম বা বারকোড দিয়ে পণ্য খুঁজুন...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(searchQuery: val));
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: filter.sortBy,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'name_asc', child: Text('নাম: ক-অ')),
                    DropdownMenuItem(value: 'name_desc', child: Text('নাম: অ-ক')),
                    DropdownMenuItem(value: 'stock_asc', child: Text('স্টক: কম থেকে বেশি')),
                    DropdownMenuItem(value: 'stock_desc', child: Text('স্টক: বেশি থেকে কম')),
                    DropdownMenuItem(value: 'price_asc', child: Text('মূল্য: কম থেকে বেশি')),
                    DropdownMenuItem(value: 'price_desc', child: Text('মূল্য: বেশি থেকে কম')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(sortBy: val));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('প্রিয় পণ্য'),
                    ],
                  ),
                  selected: filter.favoritesOnly,
                  onSelected: (val) {
                    ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(favoritesOnly: val));
                  },
                ),
                const SizedBox(width: 8),
                categoriesAsync.maybeWhen(
                  data: (categories) => Row(
                    children: categories.map((cat) {
                      final isSelected = filter.categoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (val) {
                            ref.read(productsFilterProvider.notifier).update(
                                  (s) => s.copyWith(categoryId: val ? cat.id : null),
                                );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const VerticalDivider(width: 16),
                ...[
                  {'id': 'Healthy', 'label': 'পর্যাপ্ত স্টক'},
                  {'id': 'Low', 'label': 'কম স্টক'},
                  {'id': 'Critical', 'label': 'খুবই কম স্টক'},
                  {'id': 'OutOfStock', 'label': 'স্টক নেই'},
                ].map((status) {
                  final isSelected = filter.stockStatus == status['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status['label']!),
                      selected: isSelected,
                      selectedColor: _getStatusColor(status['id']!).withOpacity(0.2),
                      onSelected: (val) {
                        ref.read(productsFilterProvider.notifier).update(
                              (s) => s.copyWith(stockStatus: val ? status['id'] : null),
                            );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Healthy': return Colors.green;
      case 'Low': return Colors.orange;
      case 'Critical': return Colors.red;
      case 'OutOfStock': return Colors.grey;
      default: return Colors.blue;
    }
  }

  Widget _buildProductGridCard(BuildContext context, ProductWithDetails item, bool isSelected) {
    final theme = Theme.of(context);
    final product = item.product;
    final isLow = product.currentStock <= product.minimumStock;
    final isOut = product.currentStock <= 0;

    return Card(
      elevation: isSelected ? 4 : 0,
      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onLongPress: () => _toggleSelection(product.id),
        onTap: () {
          if (_isMultiSelectMode) {
            _toggleSelection(product.id);
          } else {
            _showProductDetailsSheet(context, item);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: product.imagePath != null && File(product.imagePath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(product.imagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: Icon(
                          product.isFavorite ? Icons.star : Icons.star_border,
                          color: product.isFavorite ? Colors.orange : Colors.grey,
                        ),
                        onPressed: () {
                          ref.read(productsRepositoryProvider).toggleFavorite(product.id, !product.isFavorite);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                product.brand ?? 'ব্র্যান্ড ছাড়া',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.currency(product.sellingPrice),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOut
                          ? Colors.red.withOpacity(0.1)
                          : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${Formatters.number(product.currentStock)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOut ? Colors.red : (isLow ? Colors.orange : Colors.green),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSlidableTile(BuildContext context, ProductWithDetails item, bool isSelected) {
    final theme = Theme.of(context);
    final product = item.product;
    final isLow = product.currentStock <= product.minimumStock;
    final isOut = product.currentStock <= 0;

    return Slidable(
      key: ValueKey(product.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showProductFormDialog(context, product: product),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'সংশোধন',
          ),
          SlidableAction(
            onPressed: (_) => _confirmSingleDelete(context, product.id, product.name),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'মুছুন',
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isSelected ? 4 : 0,
        color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ListTile(
          onLongPress: () => _toggleSelection(product.id),
          onTap: () {
            if (_isMultiSelectMode) {
              _toggleSelection(product.id);
            } else {
              _showProductDetailsSheet(context, item);
            }
          },
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: product.imagePath != null && File(product.imagePath!).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(product.imagePath!),
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                    ),
                  )
                : Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${product.brand ?? "ব্র্যান্ড ছাড়া"} • ${Formatters.currency(product.sellingPrice)}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOut
                      ? Colors.red.withOpacity(0.1)
                      : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${Formatters.number(product.currentStock)} ${product.unit}',
                  style: TextStyle(
                    color: isOut ? Colors.red : (isLow ? Colors.orange : Colors.green),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                product.isFavorite ? Icons.star : Icons.star_border,
                color: product.isFavorite ? Colors.orange : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetailsSheet(BuildContext context, ProductWithDetails item) {
    final theme = Theme.of(context);
    final p = item.product;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (p.imagePath != null && File(p.imagePath!).existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(p.imagePath!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(p.isFavorite ? Icons.star : Icons.star_border, color: Colors.orange),
                        onPressed: () {
                          ref.read(productsRepositoryProvider).toggleFavorite(p.id, !p.isFavorite);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  Text(
                    p.brand ?? 'ব্র্যান্ড: ব্র্যান্ড ছাড়া',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(context, 'বারকোড', p.barcode ?? 'নেই'),
                  _buildDetailRow(context, 'ক্যাটাগরি', item.category?.name ?? 'ক্যাটাগরি ছাড়া'),
                  _buildDetailRow(context, 'ক্রয়মূল্য', Formatters.currency(p.buyingPrice)),
                  _buildDetailRow(context, 'বিক্রয়মূল্য', Formatters.currency(p.sellingPrice)),
                  _buildDetailRow(context, 'বর্তমান স্টক', '${Formatters.number(p.currentStock)} ${p.unit}'),
                  _buildDetailRow(context, 'সর্বনিম্ন স্টক', '${Formatters.number(p.minimumStock)} ${p.unit}'),
                  _buildDetailRow(context, 'বিবরণ', p.description ?? 'কোনো বিবরণ দেওয়া হয়নি।'),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmSingleDelete(context, p.id, p.name),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showProductFormDialog(context, product: p);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('তথ্য সংশোধন'),
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
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
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
              Navigator.of(context).popUntil((route) => route.isFirst);
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
        content: Text('আপনি কি নিশ্চিত যে সিলেক্ট করা ${_selectedIds.length}টি পণ্য মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(productsRepositoryProvider).bulkDelete(_selectedIds.toList());
              _clearSelection();
            },
            child: const Text('সব মুছুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBulkStockUpdateDialog(BuildContext context) {
    final qtyController = TextEditingController();
    String reason = 'স্টক সমন্বয়';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('সব পণ্যের স্টক পরিবর্তন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('সিলেক্ট করা ${_selectedIds.length}টি পণ্যের স্টক সমন্বয় করুন। যোগ করতে পজিটিভ নম্বর এবং কমাতে মাইনাস (-) নম্বর লিখুন।'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'পরিবর্তনের পরিমাণ',
                hintText: 'যেমন: ১০ বা -৫',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(labelText: 'কারণ', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'স্টক সমন্বয়', child: Text('স্টক সমন্বয়')),
                DropdownMenuItem(value: 'নতুন স্টক যোগ', child: Text('নতুন স্টক যোগ')),
                DropdownMenuItem(value: 'স্টক আউট/ক্ষতি', child: Text('স্টক আউট/ক্ষতি')),
              ],
              onChanged: (val) {
                if (val != null) reason = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(qtyController.text);
              if (amt != null) {
                ref.read(productsRepositoryProvider).bulkStockUpdate(_selectedIds.toList(), amt, reason);
                Navigator.pop(context);
                _clearSelection();
              }
            },
            child: const Text('প্রয়োগ করুন'),
          ),
        ],
      ),
    );
  }

  void _showProductFormDialog(BuildContext context, {Product? product}) {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?.name);
    final brandController = TextEditingController(text: product?.brand);
    final barcodeController = TextEditingController(text: product?.barcode);
    final buyPriceController = TextEditingController(text: product?.buyingPrice.toString());
    final sellPriceController = TextEditingController(text: product?.sellingPrice.toString());
    final stockController = TextEditingController(text: product?.currentStock.toString());
    final minStockController = TextEditingController(text: product?.minimumStock.toString());
    final descController = TextEditingController(text: product?.description);

    String selectedUnit = product?.unit ?? 'pcs';
    String? selectedCategoryId = product?.categoryId;
    String? imagePath = product?.imagePath;

    String? nameError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(categoriesControllerProvider);
            final theme = Theme.of(context);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(isEdit ? 'পণ্যের বিবরণ সংশোধন' : 'নতুন পণ্য যোগ করুন'),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Image Selector — Camera / Gallery → Crop
                          Builder(
                            builder: (pickerContext) => GestureDetector(
                              onTap: () async {
                                // Use root scaffold context to avoid dialog context going stale
                                final scaffoldCtx = context;
                                try {
                                  final File? result =
                                      await ImageUtils.pickAndCropImage(
                                          scaffoldCtx);
                                  if (result != null) {
                                    final appDir =
                                        await getApplicationDocumentsDirectory();
                                    final ext = p.extension(result.path);
                                    final filename =
                                        'prod_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
                                    final destPath =
                                        p.join(appDir.path, filename);
                                    // Only copy if the file isn't already in app docs dir
                                    final savedPath =
                                        result.path.startsWith(appDir.path)
                                            ? result.path
                                            : (await result.copy(destPath))
                                                .path;
                                    setDialogState(() {
                                      imagePath = savedPath;
                                    });
                                  }
                                } catch (e) {
                                  debugPrint('Image pick/crop error: $e');
                                  if (scaffoldCtx.mounted) {
                                    ScaffoldMessenger.of(scaffoldCtx)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'ছবি আপলোড ব্যর্থ হয়েছে: $e')),
                                    );
                                  }
                                }
                              },
                            child: Container(
                              height: 130,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: imagePath != null &&
                                      File(imagePath!).existsSync()
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.file(
                                            File(imagePath!),
                                            width: double.infinity,
                                            height: 130,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        // Remove button
                                        Positioned(
                                          right: 8,
                                          top: 8,
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black54,
                                            radius: 16,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(Icons.close,
                                                  size: 16,
                                                  color: Colors.white),
                                              onPressed: () {
                                                setDialogState(() {
                                                  imagePath = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        // Edit badge
                                        Positioned(
                                          left: 8,
                                          top: 8,
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.crop,
                                                    size: 12,
                                                    color: Colors.white),
                                                SizedBox(width: 4),
                                                Text(
                                                  'পরিবর্তন করুন',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.camera_alt_rounded,
                                              size: 28,
                                              color: theme
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.7),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 1,
                                              height: 28,
                                              color: theme
                                                  .colorScheme.outlineVariant,
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.photo_library_rounded,
                                              size: 28,
                                              color: theme
                                                  .colorScheme
                                                  .secondary
                                                  .withOpacity(0.7),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'ক্যামেরা বা গ্যালারি থেকে ছবি যোগ করুন',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.8),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ট্যাপ করলে ক্রপ করার সুযোগ পাবেন',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          ), // closes Builder

                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'পণ্যের নাম *', 
                              border: const OutlineInputBorder(),
                              errorText: nameError,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: barcodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'বারকোড (ঐচ্ছিক)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.qr_code_scanner),
                                tooltip: 'বারকোড জেনারেট',
                                onPressed: () {
                                  final randomBarcode = List.generate(12, (_) => (Uuid().v4().hashCode % 10).toString()).join();
                                  setDialogState(() {
                                    barcodeController.text = randomBarcode;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: brandController,
                                  decoration: const InputDecoration(labelText: 'ব্র্যান্ড/লেবেল (ঐচ্ছিক)', border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedUnit,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'একক', border: OutlineInputBorder()),
                                  items: const [
                                    DropdownMenuItem(value: 'pcs', child: Text('টি (pcs)')),
                                    DropdownMenuItem(value: 'kg', child: Text('কেজি (kg)')),
                                    DropdownMenuItem(value: 'pack', child: Text('প্যাকেট (pack)')),
                                    DropdownMenuItem(value: 'liter', child: Text('লিটার (liter)')),
                                    DropdownMenuItem(value: 'bag', child: Text('ব্যাগ (bag)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedUnit = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          categoriesAsync.maybeWhen(
                            data: (categories) => DropdownButtonFormField<String>(
                              value: selectedCategoryId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'ক্যাটাগরি সিলেক্ট করুন', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('ক্যাটাগরি ছাড়া')),
                                ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                              ],
                              onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: buyPriceController,
                                  decoration: const InputDecoration(labelText: 'ক্রয়মূল্য (টাকা) *', border: OutlineInputBorder(), prefixText: '৳'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: sellPriceController,
                                  decoration: const InputDecoration(labelText: 'বিক্রয়মূল্য (টাকা) *', border: OutlineInputBorder(), prefixText: '৳'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: stockController,
                                  enabled: !isEdit,
                                  decoration: InputDecoration(
                                    labelText: isEdit ? 'স্টক পরিবর্তন হবে না' : 'প্রারম্ভিক স্টক *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: minStockController,
                                  decoration: const InputDecoration(labelText: 'সর্বনিম্ন স্টক *', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'পণ্যের বিবরণ (ঐচ্ছিক)', border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('বাতিল'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          setDialogState(() {
                            nameError = 'পণ্যের নাম আবশ্যক';
                          });
                          return;
                        }
                        final buyVal = double.tryParse(buyPriceController.text) ?? 0.0;
                        final sellVal = double.tryParse(sellPriceController.text) ?? 0.0;
                        final stockVal = double.tryParse(stockController.text) ?? 0.0;
                        final minVal = double.tryParse(minStockController.text) ?? 0.0;

                        final repo = ref.read(productsRepositoryProvider);

                        if (isEdit) {
                          final comp = ProductsCompanion(
                            name: drift.Value(nameController.text.trim()),
                            barcode: drift.Value(barcodeController.text.trim().isEmpty ? null : barcodeController.text.trim()),
                            brand: drift.Value(brandController.text.trim().isEmpty ? null : brandController.text.trim()),
                            categoryId: drift.Value(selectedCategoryId),
                            unit: drift.Value(selectedUnit),
                            buyingPrice: drift.Value(buyVal),
                            sellingPrice: drift.Value(sellVal),
                            minimumStock: drift.Value(minVal),
                            imagePath: drift.Value(imagePath),
                            description: drift.Value(descController.text.trim().isEmpty ? null : descController.text.trim()),
                          );
                          repo.updateProduct(product.id, comp);
                        } else {
                          final newId = const Uuid().v4();
                          final comp = ProductsCompanion(
                            id: drift.Value(newId),
                            name: drift.Value(nameController.text.trim()),
                            barcode: drift.Value(barcodeController.text.trim().isEmpty ? null : barcodeController.text.trim()),
                            brand: drift.Value(brandController.text.trim().isEmpty ? null : brandController.text.trim()),
                            categoryId: drift.Value(selectedCategoryId),
                            unit: drift.Value(selectedUnit),
                            buyingPrice: drift.Value(buyVal),
                            sellingPrice: drift.Value(sellVal),
                            currentStock: drift.Value(stockVal),
                            minimumStock: drift.Value(minVal),
                            imagePath: drift.Value(imagePath),
                            description: drift.Value(descController.text.trim().isEmpty ? null : descController.text.trim()),
                          );
                          repo.addProduct(comp);
                        }

                        Navigator.pop(context);
                      },
                      child: const Text('সংরক্ষণ করুন'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'কোনো পণ্য পাওয়া যায়নি',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'নতুন পণ্য যোগ করতে উপরে ডানদিকের বাটনটিতে ক্লিক করুন।',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
