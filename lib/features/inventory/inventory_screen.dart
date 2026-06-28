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
        title: const Text('স্টক ও ইনভেন্টরি', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_rounded), text: 'স্টক রিপোর্ট'),
            Tab(icon: Icon(Icons.history_rounded), text: 'আদান-প্রদান লগ'),
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
        label: const Text('স্টক পরিবর্তন করুন'),
      ),
    );
  }

  Widget _buildStockStatusTab(BuildContext context, AsyncValue<List<ProductWithDetails>> productsAsync) {
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('লোড করতে ত্রুটি হয়েছে: $err')),
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('কোনো পণ্য পাওয়া যায়নি। পণ্য তালিকা থেকে পণ্য যোগ করুন।'));
        }

        return Column(
          children: [
            if (isDesktop)
              Container(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('পণ্যের নাম', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('ক্যাটাগরি', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('স্টক পরিমাণ', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('ক্রয়মূল্য', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('বিক্রয়মূল্য', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('নিট লাভ', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('অবস্থা', style: TextStyle(fontWeight: FontWeight.bold))),
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
                  final categoryName = item.category?.name ?? 'ক্যাটাগরি ছাড়া';
                  final profit = p.sellingPrice - p.buyingPrice;
                  final status = _getStockStatus(p.currentStock, p.minimumStock);

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
                          Expanded(flex: 1, child: Text(Formatters.currency(profit), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
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
                      subtitle: Text('$categoryName • কেনা: ${Formatters.currency(p.buyingPrice)} • লাভ: ${Formatters.currency(profit)}'),
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

  Widget _buildLogsTab(BuildContext context, AsyncValue<List<StockHistoryWithDetails>> logsAsync) {
    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('লগ লোড করতে ত্রুটি: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('এখনও কোনো স্টক পরিবর্তন করা হয়নি।'));
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
            final supplierText = entry.supplier != null ? ' • সরবরাহকারী: ${entry.supplier!.name}' : '';

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
    String statusText;
    switch (status) {
      case 'Healthy': 
        color = Colors.green; 
        statusText = 'পর্যাপ্ত স্টক';
        break;
      case 'Low': 
        color = Colors.orange; 
        statusText = 'কম স্টক';
        break;
      case 'Critical': 
        color = Colors.red; 
        statusText = 'খুবই কম স্টক';
        break;
      case 'OutOfStock': 
        color = Colors.grey; 
        statusText = 'স্টক খালি';
        break;
      default: 
        color = Colors.blue;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statusText,
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

  // Stock Adjustment Form Dialog (Bangla & Simplified)
  void _showStockAdjustmentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final costController = TextEditingController();
    final invoiceController = TextEditingController();

    String selectedType = 'Stock In'; // 'Stock In', 'Stock Out', 'Adjust Stock'
    String? selectedProductId;
    String? selectedSupplierId;
    String reason = 'ক্রয়';

    final productsAsync = ref.read(productsListProvider);
    final suppliersAsync = ref.read(suppliersControllerProvider);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('স্টক পরিবর্তন নথিভুক্ত করুন'),
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
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'পণ্য সিলেক্ট করুন *', border: OutlineInputBorder()),
                          items: products.map((p) {
                            return DropdownMenuItem(
                              value: p.product.id,
                              child: Text('${p.product.name} (বর্তমান: ${Formatters.number(p.product.currentStock)} ${p.product.unit})'),
                            );
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedProductId = val),
                        ),
                        orElse: () => const Text('পণ্য লোড হচ্ছে...'),
                      ),
                      const SizedBox(height: 12),
                      // Transaction Type
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'পরিবর্তনের ধরন', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Stock In', child: Text('স্টক যোগ করুন (Stock In)')),
                          DropdownMenuItem(value: 'Stock Out', child: Text('স্টক কমান (Stock Out)')),
                          DropdownMenuItem(value: 'Adjust Stock', child: Text('সরাসরি স্টক সেট করুন')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                              if (val == 'Stock In') reason = 'ক্রয়';
                              if (val == 'Stock Out') reason = 'নষ্ট/ক্ষতি';
                              if (val == 'Adjust Stock') reason = 'স্টক গণনা';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Quantity
                      TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: selectedType == 'Adjust Stock' ? 'নতুন মোট স্টক সংখ্যা *' : 'পরিমাণ *',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      // Reason Dropdown
                      DropdownButtonFormField<String>(
                        value: reason,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'কারণ', border: OutlineInputBorder()),
                        items: selectedType == 'Stock In'
                            ? const [
                                DropdownMenuItem(value: 'ক্রয়', child: Text('নতুন ক্রয়')),
                                DropdownMenuItem(value: 'ফেরত', child: Text('কাস্টমার ফেরত')),
                                DropdownMenuItem(value: 'অন্যান্য', child: Text('অন্যান্য')),
                              ]
                            : (selectedType == 'Stock Out'
                                ? const [
                                    DropdownMenuItem(value: 'নষ্ট/ক্ষতি', child: Text('নষ্ট / ভাঙা পণ্য')),
                                    DropdownMenuItem(value: 'চুরি', child: Text('চুরি / হারানো')),
                                    DropdownMenuItem(value: 'মেয়াদ শেষ', child: Text('মেয়াদোত্তীর্ণ পণ্য')),
                                  ]
                                : const [
                                    DropdownMenuItem(value: 'স্টক গণনা', child: Text('ভৌত স্টক গণনা')),
                                    DropdownMenuItem(value: 'সংশোধন', child: Text('হিসাব সংশোধন')),
                                  ]),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => reason = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      // Conditional fields for 'Stock In'
                      if (selectedType == 'Stock In') ...[
                        suppliersAsync.maybeWhen(
                          data: (suppliers) => DropdownButtonFormField<String>(
                            value: selectedSupplierId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'সরবরাহকারী (ঐচ্ছিক)', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('সরবরাহকারী ছাড়া')),
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
                                  labelText: 'ক্রয়মূল্য (ঐচ্ছিক)',
                                  prefixText: '৳',
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
                                    labelText: 'চালান নং (ঐচ্ছিক)',
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
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
                      final pList = productsAsync.value ?? [];
                      final match = pList.firstWhere((p) => p.product.id == selectedProductId);
                      diff = amt - match.product.currentStock;
                      await repo.adjustStock(selectedProductId!, diff, reason);
                    }

                    ref.invalidate(stockHistoryListProvider);
                    ref.invalidate(supplierPurchasesProvider);
                    Navigator.pop(context);
                  },
                  child: const Text('নিশ্চিত করুন'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
