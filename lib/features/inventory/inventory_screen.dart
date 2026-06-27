import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show leftOuterJoin;
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import '../products/products_controller.dart';
import '../suppliers/suppliers_controller.dart';

// Stock History Log data class
class StockHistoryWithDetails {
  final StockHistoryData log;
  final Product product;
  final Supplier? supplier;

  StockHistoryWithDetails({
    required this.log,
    required this.product,
    this.supplier,
  });
}

// Fetch stock history logs joined with product name and supplier name
final stockHistoryListProvider = FutureProvider<List<StockHistoryWithDetails>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final query = db.select(db.stockHistory).join([
    leftOuterJoin(db.products, db.products.id.equalsExp(db.stockHistory.productId)),
    leftOuterJoin(db.suppliers, db.suppliers.id.equalsExp(db.stockHistory.supplierId)),
  ]);

  final rows = await query.get();

  final list = rows.map((row) {
    return StockHistoryWithDetails(
      log: row.readTable(db.stockHistory),
      product: row.readTable(db.products),
      supplier: row.readTableOrNull(db.suppliers),
    );
  }).toList();

  // Sort by date descending
  list.sort((a, b) => b.log.date.compareTo(a.log.date));
  return list;
});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsListProvider);
    final logsAsync = ref.watch(stockHistoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_rounded), text: 'Stock Status'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Transaction Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockStatusTab(context, productsAsync),
          _buildLogsTab(context, logsAsync),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStockAdjustmentDialog(context),
        icon: const Icon(Icons.swap_vertical_circle_outlined),
        label: const Text('Adjust Stock'),
      ),
    );
  }

  // TAB 1: Stock levels grid/list with details
  Widget _buildStockStatusTab(BuildContext context, AsyncValue<List<ProductWithDetails>> productsAsync) {
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('No products in directory. Register a product first.'));
        }

        return Column(
          children: [
            // Table Header on desktop, normal list otherwise
            if (isDesktop)
              Container(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('Stock Level', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('Buying Price', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('Unit Profit', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: isDesktop ? const EdgeInsets.all(8) : const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = products[index];
                  final p = item.product;
                  final categoryName = item.category?.name ?? 'Uncategorized';
                  final profit = p.sellingPrice - p.buyingPrice;
                  final status = _getStockStatus(p.currentStock, p.minimumStock);
                  final isOut = p.currentStock <= 0;

                  if (isDesktop) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 8, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(categoryName)),
                          Expanded(flex: 1, child: Text('${Formatters.number(p.currentStock)} ${p.unit}')),
                          Expanded(flex: 1, child: Text(Formatters.currency(p.buyingPrice))),
                          Expanded(flex: 1, child: Text(Formatters.currency(p.sellingPrice))),
                          Expanded(flex: 1, child: Text(Formatters.currency(profit), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500))),
                          Expanded(
                            flex: 1,
                            child: _buildStatusBadge(status),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$categoryName • Buying: ${Formatters.currency(p.buyingPrice)} • Profit: ${Formatters.currency(profit)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${Formatters.number(p.currentStock)} ${p.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          _buildStatusBadge(status),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // TAB 2: Chronological transaction logs
  Widget _buildLogsTab(BuildContext context, AsyncValue<List<StockHistoryWithDetails>> logsAsync) {
    final theme = Theme.of(context);
    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error loading logs: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('No stock adjustments recorded.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final entry = logs[index];
            final product = entry.product;
            final log = entry.log;
            final isAddition = log.changeAmount > 0;
            final supplierText = entry.supplier != null ? ' • Supplier: ${entry.supplier!.name}' : '';

            return ListTile(
              leading: Icon(
                isAddition ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                color: isAddition ? Colors.green : Colors.red,
                size: 28,
              ),
              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${log.reason}$supplierText\n${Formatters.dateTime(log.date)}'),
              isThreeLine: true,
              trailing: Text(
                '${isAddition ? '+' : ''}${Formatters.number(log.changeAmount)} ${product.unit}',
                style: TextStyle(
                  color: isAddition ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Healthy': color = Colors.green; break;
      case 'Low': color = Colors.orange; break;
      case 'Critical': color = Colors.red; break;
      case 'OutOfStock': color = Colors.grey; break;
      default: color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status == 'OutOfStock' ? 'Out of Stock' : status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getStockStatus(double current, double min) {
    if (current <= 0) return 'OutOfStock';
    if (current <= min * 0.5) return 'Critical';
    if (current <= min) return 'Low';
    return 'Healthy';
  }

  // Stock Adjustment Form Dialog
  void _showStockAdjustmentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final costController = TextEditingController();
    final invoiceController = TextEditingController();

    String selectedType = 'Stock In'; // 'Stock In', 'Stock Out', 'Adjust Stock'
    String? selectedProductId;
    String? selectedSupplierId;
    String reason = 'Purchase';

    final productsAsync = ref.read(productsListProvider);
    final suppliersAsync = ref.read(suppliersControllerProvider);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Record Stock Transaction'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product selector
                      productsAsync.maybeWhen(
                        data: (products) => DropdownButtonFormField<String>(
                          value: selectedProductId,
                          decoration: const InputDecoration(labelText: 'Select Product *', border: OutlineInputBorder()),
                          items: products.map((p) {
                            return DropdownMenuItem(
                              value: p.product.id,
                              child: Text('${p.product.name} (Stock: ${Formatters.number(p.product.currentStock)} ${p.product.unit})'),
                            );
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedProductId = val),
                        ),
                        orElse: () => const Text('Loading products...'),
                      ),
                      const SizedBox(height: 12),
                      // Transaction Type
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'Transaction Type', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Stock In', child: Text('Stock In (Add)')),
                          DropdownMenuItem(value: 'Stock Out', child: Text('Stock Out (Subtract)')),
                          DropdownMenuItem(value: 'Adjust Stock', child: Text('Set Stock Value')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                              if (val == 'Stock In') reason = 'Purchase';
                              if (val == 'Stock Out') reason = 'Damage';
                              if (val == 'Adjust Stock') reason = 'Physical Audit';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Quantity
                      TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: selectedType == 'Adjust Stock' ? 'New Stock Level *' : 'Quantity *',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      // Reason Text dropdown
                      DropdownButtonFormField<String>(
                        value: reason,
                        decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                        items: selectedType == 'Stock In'
                            ? const [
                                DropdownMenuItem(value: 'Purchase', child: Text('Purchase Log')),
                                DropdownMenuItem(value: 'Return', child: Text('Customer Return')),
                                DropdownMenuItem(value: 'Transfer', child: Text('Transfer In')),
                              ]
                            : (selectedType == 'Stock Out'
                                ? const [
                                    DropdownMenuItem(value: 'Damage', child: Text('Damaged / Broken')),
                                    DropdownMenuItem(value: 'Theft', child: Text('Shrinkage / Theft')),
                                    DropdownMenuItem(value: 'Expiry', child: Text('Expired Items')),
                                    DropdownMenuItem(value: 'Transfer', child: Text('Transfer Out')),
                                  ]
                                : const [
                                    DropdownMenuItem(value: 'Physical Audit', child: Text('Physical Audit')),
                                    DropdownMenuItem(value: 'Discrepancy Correction', child: Text('Correction')),
                                  ]),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => reason = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      // Conditional fields for 'Stock In' -> Suppliers integration
                      if (selectedType == 'Stock In') ...[
                        suppliersAsync.maybeWhen(
                          data: (suppliers) => DropdownButtonFormField<String>(
                            value: selectedSupplierId,
                            decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Select Supplier')),
                              ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                            ],
                            onChanged: (val) => setDialogState(() => selectedSupplierId = val),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: costController,
                                decoration: const InputDecoration(
                                  labelText: 'Cost Per Unit *',
                                  prefixText: '\$',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: invoiceController,
                                decoration: const InputDecoration(
                                  labelText: 'Invoice No.',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedProductId == null) return;
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) return;

                    final repo = ref.read(productsRepositoryProvider);
                    final db = ref.read(databaseProvider);

                    double diff = 0.0;

                    if (selectedType == 'Stock In') {
                      diff = amt;
                      // Log purchase record if supplier selected
                      if (selectedSupplierId != null) {
                        final cost = double.tryParse(costController.text) ?? 0.0;
                        await db.into(db.purchases).insert(
                          PurchasesCompanion(
                            id: drift.Value(const Uuid().v4()),
                            supplierId: drift.Value(selectedSupplierId!),
                            date: drift.Value(DateTime.now()),
                            cost: drift.Value(cost * amt),
                            quantity: drift.Value(amt),
                            invoiceNo: drift.Value(invoiceController.text.trim().isEmpty ? null : invoiceController.text.trim()),
                          ),
                        );
                      }
                      await repo.adjustStock(selectedProductId!, diff, reason, supplierId: selectedSupplierId);
                    } else if (selectedType == 'Stock Out') {
                      diff = -amt;
                      await repo.adjustStock(selectedProductId!, diff, reason);
                    } else {
                      // Adjust stock
                      final pList = productsAsync.value ?? [];
                      final match = pList.firstWhere((p) => p.product.id == selectedProductId);
                      diff = amt - match.product.currentStock;
                      await repo.adjustStock(selectedProductId!, diff, reason);
                    }

                    // Invalidate providers
                    ref.invalidate(stockHistoryListProvider);
                    ref.invalidate(supplierPurchasesProvider);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
