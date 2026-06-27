import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/utils/formatters.dart';
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
        if (_selectedIds.isEmpty) _isMultiSelectMode = false;
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
    final productsAsync = ref.watch(productsListProvider);
    final filter = ref.watch(productsFilterProvider);
    final categoriesAsync = ref.watch(categoriesControllerProvider);
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text('${_selectedIds.length} Selected')
            : const Text('Products Directory', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: _isMultiSelectMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection)
            : null,
        actions: _isMultiSelectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.teal),
                  tooltip: 'Bulk Stock Update',
                  onPressed: () => _showBulkStockUpdateDialog(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Bulk Delete',
                  onPressed: () => _confirmBulkDelete(context),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(productsListProvider),
                ),
              ],
      ),
      body: Column(
        children: [
          // Sticky search and filter bar
          _buildSearchAndFilters(context, filter, categoriesAsync),
          
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading products: $err')),
              data: (products) {
                if (products.isEmpty) {
                  return const _EmptyProductsState();
                }

                if (isDesktop) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.8,
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
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
      floatingActionButton: _isMultiSelectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showProductFormDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
    );
  }

  // Build Filter row
  Widget _buildSearchAndFilters(
    BuildContext context,
    ProductsFilterState filter,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Search & Sort bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search product, brand, barcode...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(searchQuery: val));
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filter.sortBy,
                    icon: const Icon(Icons.sort_rounded),
                    items: const [
                      DropdownMenuItem(value: 'name_asc', child: Text('Name A-Z')),
                      DropdownMenuItem(value: 'name_desc', child: Text('Name Z-A')),
                      DropdownMenuItem(value: 'stock_asc', child: Text('Stock: Low to High')),
                      DropdownMenuItem(value: 'stock_desc', child: Text('Stock: High to Low')),
                      DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
                      DropdownMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(sortBy: val));
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Category chips & Stock status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Favorite filter
                FilterChip(
                  label: const Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Starred'),
                    ],
                  ),
                  selected: filter.favoritesOnly,
                  onSelected: (val) {
                    ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(favoritesOnly: val));
                  },
                ),
                const SizedBox(width: 8),
                // Category Filter
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
                // Stock filter chips
                ...['Healthy', 'Low', 'Critical', 'OutOfStock'].map((status) {
                  final isSelected = filter.stockStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor: _getStatusColor(status).withOpacity(0.2),
                      onSelected: (val) {
                        ref.read(productsFilterProvider.notifier).update(
                              (s) => s.copyWith(stockStatus: val ? status : null),
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

  // Grid widget (desktop)
  Widget _buildProductGridCard(BuildContext context, ProductWithDetails item, bool isSelected) {
    final theme = Theme.of(context);
    final product = item.product;
    final isLow = product.currentStock <= product.minimumStock;
    final isOut = product.currentStock <= 0;

    return Card(
      elevation: isSelected ? 4 : 0,
      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or category icon row
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
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
              // Details
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                product.brand ?? 'Generic',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
              ),
              const SizedBox(height: 6),
              // Price and stock indicator
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

  // Slidable tile (mobile list view)
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
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => _confirmSingleDelete(context, product.id, product.name),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${product.brand ?? 'Generic'} • ${Formatters.currency(product.sellingPrice)}'),
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

  // Product Details Bottom Sheet
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
                    p.brand ?? 'Brand: Generic',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(context, 'Barcode', p.barcode ?? 'None'),
                  _buildDetailRow(context, 'Category', item.category?.name ?? 'Uncategorized'),
                  _buildDetailRow(context, 'Buying Price', Formatters.currency(p.buyingPrice)),
                  _buildDetailRow(context, 'Selling Price', Formatters.currency(p.sellingPrice)),
                  _buildDetailRow(context, 'Current Stock', '${Formatters.number(p.currentStock)} ${p.unit}'),
                  _buildDetailRow(context, 'Minimum Stock', '${Formatters.number(p.minimumStock)} ${p.unit}'),
                  _buildDetailRow(context, 'Supplier', item.supplier?.name ?? 'None'),
                  _buildDetailRow(context, 'Description', p.description ?? 'No description provided.'),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ref.read(productsRepositoryProvider).duplicateProduct(p.id);
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Duplicate'),
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
                          label: const Text('Edit Details'),
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

  // Single confirmation delete
  void _confirmSingleDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "$name"? This will remove its history logs.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(productsRepositoryProvider).deleteProduct(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Bulk actions confirmation delete
  void _confirmBulkDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Products?'),
        content: Text('Are you sure you want to delete the ${_selectedIds.length} selected products?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(productsRepositoryProvider).bulkDelete(_selectedIds.toList());
              _clearSelection();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Bulk stock update dialog
  void _showBulkStockUpdateDialog(BuildContext context) {
    final qtyController = TextEditingController();
    String reason = 'Bulk Adjustment';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Stock Adjustment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Adjust stock for ${_selectedIds.length} products. Use positive numbers to add, negative numbers to subtract.'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Adjustment Amount',
                hintText: 'e.g. 10 or -5',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Bulk Adjustment', child: Text('Stock Adjustment')),
                DropdownMenuItem(value: 'Stock In', child: Text('Purchase / Stock In')),
                DropdownMenuItem(value: 'Stock Out', child: Text('Write Off / Stock Out')),
              ],
              onChanged: (val) {
                if (val != null) reason = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(qtyController.text);
              if (amt != null) {
                ref.read(productsRepositoryProvider).bulkStockUpdate(_selectedIds.toList(), amt, reason);
                Navigator.pop(context);
                _clearSelection();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // Product Add / Edit Dialog Form
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
    String? selectedSupplierId = product?.supplierId;

    String? nameError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(categoriesControllerProvider);
            final suppliersAsync = ref.watch(suppliersControllerProvider);
            
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
              title: Text(isEdit ? 'Edit Product Details' : 'Register New Product'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Product Name *', 
                          border: const OutlineInputBorder(),
                          errorText: nameError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Barcode with mock scanner icon
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barcode (Optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'Mock Barcode Scan',
                            onPressed: () {
                              // Generate a random 12-digit mock barcode
                              final randomBarcode = List.generate(12, (_) => (Uuid().v4().hashCode % 10).toString()).join();
                              setDialogState(() {
                                barcodeController.text = randomBarcode;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Brand & Unit
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: brandController,
                              decoration: const InputDecoration(labelText: 'Brand / Label', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'pcs', child: Text('Pieces (pcs)')),
                                DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                                DropdownMenuItem(value: 'pack', child: Text('Pack')),
                                DropdownMenuItem(value: 'liter', child: Text('Liter (L)')),
                                DropdownMenuItem(value: 'bag', child: Text('Bag')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Category dropdown
                      categoriesAsync.maybeWhen(
                        data: (categories) => DropdownButtonFormField<String>(
                          value: selectedCategoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Uncategorized')),
                            ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      // Buying & Selling Price
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: buyPriceController,
                              decoration: const InputDecoration(labelText: 'Buying Cost *', border: OutlineInputBorder(), prefixText: '\$'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: sellPriceController,
                              decoration: const InputDecoration(labelText: 'Selling Price *', border: OutlineInputBorder(), prefixText: '\$'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Stock Levels (Stock disabled in Edit - must go through Stock Management)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              enabled: !isEdit,
                              decoration: InputDecoration(
                                labelText: isEdit ? 'Stock (Edit in Inv)' : 'Initial Stock *',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: minStockController,
                              decoration: const InputDecoration(labelText: 'Min Stock Level *', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Supplier dropdown
                      suppliersAsync.maybeWhen(
                        data: (suppliers) => DropdownButtonFormField<String>(
                          value: selectedSupplierId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Supplier')),
                            ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (val) => setDialogState(() => selectedSupplierId = val),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      // Description
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validations
                    if (nameController.text.trim().isEmpty) {
                      setDialogState(() {
                        nameError = 'Product name is required';
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
                        supplierId: drift.Value(selectedSupplierId),
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
                        supplierId: drift.Value(selectedSupplierId),
                        description: drift.Value(descController.text.trim().isEmpty ? null : descController.text.trim()),
                      );
                      repo.addProduct(comp);
                    }

                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
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

// Reusable Empty State Widget
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
              'No Products Found',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create new categories and register items to populate the inventory directory.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
