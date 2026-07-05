import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/permission_utils.dart';
import '../../core/utils/dialog_utils.dart';
import '../products/products_controller.dart';
import '../settings/settings_controller.dart';
import 'suppliers_controller.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersControllerProvider);
    final theme = Theme.of(context);

    // Filter suppliers in memory
    final filteredSuppliers = suppliersAsync.maybeWhen(
      data: (list) {
        if (_searchQuery.isEmpty) return list;
        final q = _searchQuery.toLowerCase();
        return list.where((s) => s.name.toLowerCase().contains(q) || s.phone.contains(q)).toList();
      },
      orElse: () => <Supplier>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers Registry', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'রিপোর্ট পিডিএফ ডাউনলোড',
            onPressed: () => _generatePDFReport(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search suppliers by name or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          
          Expanded(
            child: suppliersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
              data: (suppliers) {
                if (filteredSuppliers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text('No Suppliers Registered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          const Text('Register your suppliers to log resting inventory and keep track of purchases.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSuppliers.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final sup = filteredSuppliers[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
                        child: Icon(Icons.local_shipping, color: theme.colorScheme.primary),
                      ),
                      title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Phone: ${sup.phone}${sup.email != null ? ' • ${sup.email}' : ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showSupplierDetailsSheet(context, sup),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierFormDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
      ),
    );
  }

  void _generatePDFReport(BuildContext context) async {
    final hasPermission = await PermissionUtils.requestStoragePermission(context);
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('স্টোরেজ পারমিশন প্রয়োজন!')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    bool loaderShowing = true;

    try {
      final db = ref.read(databaseProvider);
      final suppliers = await db.select(db.suppliers).get();
      if (suppliers.isEmpty) {
        if (context.mounted && loaderShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          loaderShowing = false;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('রিপোর্ট তৈরি করার জন্য কোনো সরবরাহকারী নেই।')),
          );
        }
        return;
      }

      final allProducts = await db.select(db.products).get();
      final allOrders = await db.select(db.supplierOrders).get();
      final allDamages = await db.select(db.damagedItems).get();

      final Map<String, List<Product>> productsMap = {};
      final Map<String, List<SupplierOrder>> ordersMap = {};
      final Map<String, List<DamagedItem>> damagesMap = {};

      for (var s in suppliers) {
        productsMap[s.id] = allProducts.where((p) => p.supplierId == s.id && !p.isArchived).toList();
        ordersMap[s.id] = allOrders.where((o) => o.supplierId == s.id).toList();
        damagesMap[s.id] = allDamages.where((d) => d.supplierId == s.id).toList();
      }

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final pdfSavePath = settings?.pdfSavePath;

      if (context.mounted) {
        final savedPath = await PdfGenerator.generateAndSaveSuppliersReport(
          suppliers: suppliers,
          productsMap: productsMap,
          ordersMap: ordersMap,
          damagesMap: damagesMap,
          customSavePath: pdfSavePath,
        );

        if (loaderShowing && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
          loaderShowing = false;
        }

        if (savedPath != null && context.mounted) {
          DialogUtils.showSaveSuccessDialog(context, savedPath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        if (loaderShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          loaderShowing = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('রিপোর্ট তৈরিতে ত্রুটি: $e')),
        );
      }
    }
  }

  // Details Bottom Sheet showing supplier metadata & ledger tabs
  void _showSupplierDetailsSheet(BuildContext context, Supplier supplier) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          height: MediaQuery.of(context).size.height * 0.85,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                
                // Header Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
                        radius: 24,
                        child: Icon(Icons.local_shipping_rounded, color: theme.colorScheme.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplier.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('Phone: ${supplier.phone}${supplier.email != null ? ' | ${supplier.email!}' : ''}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            if (supplier.address != null)
                              Text('Address: ${supplier.address}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(context);
                          _showSupplierFormDialog(context, supplier: supplier);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmSupplierDelete(context, supplier.id, supplier.name);
                        },
                      ),
                    ],
                  ),
                ),
                
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: theme.colorScheme.primary,
                  tabs: const [
                    Tab(icon: Icon(Icons.receipt_long_rounded), text: 'লেনদেন'),
                    Tab(icon: Icon(Icons.inventory_2_outlined), text: 'পণ্য ও স্টক'),
                    Tab(icon: Icon(Icons.broken_image_outlined), text: 'ক্ষতিগ্রস্ত'),
                  ],
                ),
                
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildLedgerTab(context, supplier.id),
                      _buildInventoryTab(context, supplier.id),
                      _buildDamagesTab(context, supplier.id),
                    ],
                  ),
                ),
                
                _buildActionButtons(context, supplier.id),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tab 1: Ledger & Orders
  Widget _buildLedgerTab(BuildContext context, String supplierId) {
    final theme = Theme.of(context);
    
    return Consumer(
      builder: (context, ref, _) {
        final ordersAsync = ref.watch(supplierOrdersProvider(supplierId));
        final productsAsync = ref.watch(productsListProvider);
        
        return ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error loading ledger: $err')),
          data: (orders) {
            final productNames = productsAsync.maybeWhen(
              data: (list) => {for (var p in list) p.product.id: p.product.name},
              orElse: () => <String, String>{},
            );

            // Calculations
            double totalCost = 0.0;
            double totalPaid = 0.0;
            double quantityOrdered = 0.0;
            double quantityReceived = 0.0;

            for (var o in orders) {
              totalCost += o.totalCost;
              totalPaid += o.amountPaid;
              quantityOrdered += o.quantityOrdered;
              quantityReceived += o.quantityReceived;
            }
            double totalDue = totalCost - totalPaid;
            double quantityPending = quantityOrdered - quantityReceived;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _buildMetricCard(
                        'মোট মূল্য',
                        Formatters.currency(totalCost),
                        Icons.calculate_outlined,
                        Colors.purple,
                      ),
                      _buildMetricCard(
                        'পরিশোধিত',
                        Formatters.currency(totalPaid),
                        Icons.done_all_rounded,
                        Colors.green,
                      ),
                      _buildMetricCard(
                        'বকেয়া পাওনা',
                        Formatters.currency(totalDue),
                        Icons.hourglass_empty_rounded,
                        totalDue > 0 ? Colors.red : Colors.grey,
                      ),
                      _buildMetricCard(
                        'অর্ডার পণ্য',
                        '${Formatters.number(quantityOrdered)} units',
                        Icons.local_shipping_outlined,
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'রিসিভড পণ্য',
                        '${Formatters.number(quantityReceived)} units',
                        Icons.download_done_rounded,
                        Colors.teal,
                      ),
                      _buildMetricCard(
                        'বাকি পণ্য',
                        '${Formatters.number(quantityPending > 0 ? quantityPending : 0.0)} units',
                        Icons.pending_actions_rounded,
                        quantityPending > 0 ? Colors.amber : Colors.grey,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  Text('অর্ডার হিস্ট্রি (Orders History)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  if (orders.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('এই সরবরাহকারীর কোনো অর্ডার তথ্য নেই।', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final prodName = productNames[order.productId] ?? 'Unknown Product';

                        Color statusColor = Colors.grey;
                        if (order.status == 'Received') statusColor = Colors.green;
                        if (order.status == 'Partially Received') statusColor = Colors.orange;
                        if (order.status == 'Pending') statusColor = Colors.red;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(prodName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('অর্ডার তারিখ: ${Formatters.date(order.date)}'),
                              Text('অর্ডার: ${Formatters.number(order.quantityOrdered)} • রিসিভড: ${Formatters.number(order.quantityReceived)} (${order.status})'),
                              Text('পরিশোধিত: ${Formatters.currency(order.amountPaid)} / মোট: ${Formatters.currency(order.totalCost)}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order.status,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                tooltip: 'হালনাগাদ',
                                onPressed: () => _showUpdateOrderDialog(context, order, supplierId),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Tab 2: Products & Requisition recommendations
  Widget _buildInventoryTab(BuildContext context, String supplierId) {
    final theme = Theme.of(context);
    
    return Consumer(
      builder: (context, ref, _) {
        final productsAsync = ref.watch(productsBySupplierProvider(supplierId));
        
        return productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error loading products: $err')),
          data: (products) {
            final lowStockProducts = products.where((p) => p.currentStock <= p.minimumStock).toList();
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Requisition Alert
                  if (lowStockProducts.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'রিকুইজিশন প্রয়োজন! (Requisition Alert)',
                                  style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'নিম্নোক্ত পণ্যগুলোর স্টক ফুরিয়ে যাচ্ছে: ${lowStockProducts.map((p) => p.name).join(', ')}',
                                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  Text('সাপ্লাইড পণ্য ও স্টক (${products.length}টি)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  if (products.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('এই সরবরাহকারীর অধীনে কোনো পণ্য তালিকাভুক্ত নেই।', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        final isLow = p.currentStock <= p.minimumStock;
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: p.imagePath != null && File(p.imagePath!).existsSync()
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(File(p.imagePath!), width: 44, height: 44, fit: BoxFit.cover),
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                                ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${p.brand ?? 'No Brand'} • Unit: ${p.unit}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${Formatters.number(p.currentStock)} stock',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isLow ? Colors.red : Colors.green,
                                ),
                              ),
                              if (isLow)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('নিম্ন স্টক', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Tab 3: Damages
  Widget _buildDamagesTab(BuildContext context, String supplierId) {
    final theme = Theme.of(context);
    
    return Consumer(
      builder: (context, ref, _) {
        final damagesAsync = ref.watch(supplierDamagesProvider(supplierId));
        final productsAsync = ref.watch(productsListProvider);
        
        return damagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error loading damages: $err')),
          data: (damages) {
            final productNames = productsAsync.maybeWhen(
              data: (list) => {for (var p in list) p.product.id: p.product.name},
              orElse: () => <String, String>{},
            );

            double totalDamagedQty = damages.fold(0.0, (sum, d) => sum + d.quantity);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricCard(
                    'মোট ক্ষতিগ্রস্ত পণ্য',
                    '${Formatters.number(totalDamagedQty)} items',
                    Icons.broken_image_outlined,
                    totalDamagedQty > 0 ? Colors.red : Colors.grey,
                  ),
                  const Divider(height: 32),
                  
                  Text('ক্ষতিগ্রস্ত পণ্যের বিবরণ (Damaged Records)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  if (damages.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('কোনো ক্ষতিগ্রস্ত পণ্য রেকর্ড করা নেই।', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: damages.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final dmg = damages[index];
                        final prodName = productNames[dmg.productId] ?? 'Unknown Product';
                        
                        Color statusColor = Colors.grey;
                        if (dmg.status == 'Replaced' || dmg.status == 'Refunded') statusColor = Colors.green;
                        if (dmg.status == 'Pending Replacement') statusColor = Colors.amber;
                        if (dmg.status == 'Pending Refund') statusColor = Colors.orange;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(prodName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('রেকর্ড তারিখ: ${Formatters.date(dmg.date)}'),
                              Text('পরিমাণ: ${Formatters.number(dmg.quantity)} units'),
                              if (dmg.notes != null && dmg.notes!.isNotEmpty)
                                Text('নোট: ${dmg.notes}'),
                              if (dmg.resolutionDate != null)
                                Text('মীমাংসা: ${Formatters.date(dmg.resolutionDate!)}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dmg.status,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                tooltip: 'স্ট্যাটাস বদলুন',
                                onPressed: () => _showUpdateDamageDialog(context, dmg, supplierId),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Dashboard Cards UI Helper
  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Bottom action buttons inside details sheet
  Widget _buildActionButtons(BuildContext context, String supplierId) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('নতুন অর্ডার'),
              onPressed: () => _showAddOrderDialog(context, supplierId),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.broken_image_outlined),
              label: const Text('ক্ষতিগ্রস্ত পণ্য'),
              onPressed: () => _showAddDamageDialog(context, supplierId),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog 1: Add Order
  void _showAddOrderDialog(BuildContext context, String supplierId) {
    final qtyController = TextEditingController();
    final costController = TextEditingController();
    final paidController = TextEditingController();
    
    String? selectedProdId;
    String status = 'Pending';
    
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final productsAsync = ref.watch(productsBySupplierProvider(supplierId));
          
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
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedProdId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'পণ্য সিলেক্ট করুন *', border: OutlineInputBorder()),
                            items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                            onChanged: (val) => setDlgState(() => selectedProdId = val),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: qtyController,
                            decoration: const InputDecoration(labelText: 'অর্ডার পরিমাণ (Quantity) *', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
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
                  if (qty <= 0 || cost <= 0) return;

                  final qtyReceived = status == 'Received' ? qty : 0.0;

                  ref.read(suppliersControllerProvider.notifier).addSupplierOrder(
                    supplierId: supplierId,
                    productId: selectedProdId!,
                    qtyOrdered: qty,
                    qtyReceived: qtyReceived,
                    totalCost: cost,
                    amtPaid: paid,
                    date: DateTime.now(),
                    status: status,
                  );
                  Navigator.pop(context);
                },
                child: const Text('সংরক্ষণ করুন'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog 2: Update Order
  void _showUpdateOrderDialog(BuildContext context, SupplierOrder order, String supplierId) {
    final addQtyController = TextEditingController();
    final addPaidController = TextEditingController();
    String status = order.status;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('অর্ডার তথ্য আপডেট করুন'),
        content: StatefulBuilder(
          builder: (context, setDlgState) {
            final due = order.totalCost - order.amountPaid;
            final pending = order.quantityOrdered - order.quantityReceived;

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
                orderId: order.id,
                supplierId: supplierId,
                addedReceived: addedReceived,
                addedPaid: addedPaid,
                status: status,
              );
              Navigator.pop(context);
            },
            child: const Text('আপডেট'),
          ),
        ],
      ),
    );
  }

  // Dialog 3: Add Damage
  void _showAddDamageDialog(BuildContext context, String supplierId) {
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedProdId;
    String status = 'Pending Replacement';

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final productsAsync = ref.watch(productsBySupplierProvider(supplierId));
          
          return AlertDialog(
            title: const Text('ক্ষতিগ্রস্ত পণ্য রেকর্ড লোগ করুন'),
            content: productsAsync.when(
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (err, st) => Text('Error loading products: $err'),
              data: (products) {
                if (products.isEmpty) {
                  return const Text('ক্ষতিগ্রস্ত পণ্য রেকর্ড করতে প্রথমে এই সরবরাহকারীর অধীনে পণ্য যুক্ত করুন।');
                }

                return StatefulBuilder(
                  builder: (context, setDlgState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedProdId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'পণ্য সিলেক্ট করুন *', border: OutlineInputBorder()),
                          items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                          onChanged: (val) => setDlgState(() => selectedProdId = val),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: qtyController,
                          decoration: const InputDecoration(labelText: 'ক্ষতিগ্রস্ত সংখ্যা *', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'মীমাংসা স্ট্যাটাস', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Pending Replacement', child: Text('Pending Replacement (প্রতিস্থাপন অপেক্ষমান)')),
                            DropdownMenuItem(value: 'Replaced', child: Text('Replaced (প্রতিস্থাপিত)')),
                            DropdownMenuItem(value: 'Pending Refund', child: Text('Pending Refund (ফেরত অপেক্ষমান)')),
                            DropdownMenuItem(value: 'Refunded', child: Text('Refunded (ফেরতকৃত)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => status = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          decoration: const InputDecoration(labelText: 'অতিরিক্ত নোট (ঐচ্ছিক)', border: OutlineInputBorder()),
                        ),
                      ],
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
                  if (qty <= 0) return;

                  ref.read(suppliersControllerProvider.notifier).addDamagedItem(
                    supplierId: supplierId,
                    productId: selectedProdId!,
                    quantity: qty,
                    status: status,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                child: const Text('রেকর্ড করুন'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog 4: Update Damage Status
  void _showUpdateDamageDialog(BuildContext context, DamagedItem damage, String supplierId) {
    String status = damage.status;
    final notesController = TextEditingController(text: damage.notes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ক্ষতিগ্রস্ত পণ্য মীমাংসা স্ট্যাটাস'),
        content: StatefulBuilder(
          builder: (context, setDlgState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'স্ট্যাটাস বদলুন', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Pending Replacement', child: Text('Pending Replacement (প্রতিস্থাপন অপেক্ষমান)')),
                    DropdownMenuItem(value: 'Replaced', child: Text('Replaced (প্রতিস্থাপিত)')),
                    DropdownMenuItem(value: 'Pending Refund', child: Text('Pending Refund (ফেরত অপেক্ষমান)')),
                    DropdownMenuItem(value: 'Refunded', child: Text('Refunded (ফেরতকৃত)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => status = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'মীমাংসা নোট', border: OutlineInputBorder()),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              final isResolved = status == 'Replaced' || status == 'Refunded';
              
              ref.read(suppliersControllerProvider.notifier).updateDamagedItemStatus(
                id: damage.id,
                supplierId: supplierId,
                status: status,
                resolutionDate: isResolved ? DateTime.now() : null,
                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('মীমাংসা করুন'),
          ),
        ],
      ),
    );
  }



  // Delete supplier dialog
  void _confirmSupplierDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier?'),
        content: Text('Are you sure you want to delete "$name"? Products supplied by this contact will have their supplier set to null.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(suppliersControllerProvider.notifier).deleteSupplier(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Add/Edit supplier Form Dialog
  void _showSupplierFormDialog(BuildContext context, {Supplier? supplier}) {
    final isEdit = supplier != null;
    final nameController = TextEditingController(text: supplier?.name);
    final phoneController = TextEditingController(text: supplier?.phone);
    final emailController = TextEditingController(text: supplier?.email);
    final addressController = TextEditingController(text: supplier?.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Update Supplier Details' : 'Register Supplier Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Supplier Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Office Address', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) return;

              final notifier = ref.read(suppliersControllerProvider.notifier);
              if (isEdit) {
                notifier.updateSupplier(supplier.id, name, phone, emailController.text.trim().isEmpty ? null : emailController.text.trim(), addressController.text.trim().isEmpty ? null : addressController.text.trim());
              } else {
                notifier.addSupplier(name, phone, emailController.text.trim().isEmpty ? null : emailController.text.trim(), addressController.text.trim().isEmpty ? null : addressController.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
