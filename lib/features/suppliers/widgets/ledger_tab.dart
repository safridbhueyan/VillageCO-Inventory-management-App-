import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../settings/settings_controller.dart';
import '../../products/products_controller.dart';
import '../suppliers_controller.dart';
import 'update_order_dialog.dart';

class LedgerTab extends ConsumerWidget {
  final String supplierId;
  final bool showOnlyOutstanding;

  const LedgerTab({
    super.key,
    required this.supplierId,
    this.showOnlyOutstanding = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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

        final displayOrders = showOnlyOutstanding
            ? orders.where((o) => o.totalCost > o.amountPaid).toList()
            : orders;

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
              if (!showOnlyOutstanding) ...[
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _buildMetricCard('মোট মূল্য', Formatters.currency(totalCost), Icons.calculate_outlined, Colors.purple),
                    _buildMetricCard('পরিশোধিত', Formatters.currency(totalPaid), Icons.done_all_rounded, Colors.green),
                    _buildMetricCard('বকেয়া পাওনা', Formatters.currency(totalDue), Icons.hourglass_empty_rounded, totalDue > 0 ? Colors.red : Colors.grey),
                    _buildMetricCard('অর্ডার পণ্য', '${Formatters.number(quantityOrdered)} units', Icons.local_shipping_outlined, Colors.blue),
                    _buildMetricCard('রিসিভড পণ্য', '${Formatters.number(quantityReceived)} units', Icons.download_done_rounded, Colors.teal),
                    _buildMetricCard('বাকি পণ্য', '${Formatters.number(quantityPending > 0 ? quantityPending : 0.0)} units', Icons.pending_actions_rounded, quantityPending > 0 ? Colors.amber : Colors.grey),
                  ],
                ),
                const Divider(height: 32),
              ],
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      showOnlyOutstanding ? 'বকেয়া অর্ডারসমূহ (Outstanding Orders)' : 'অর্ডার হিস্ট্রি (Orders History)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!showOnlyOutstanding)
                    ElevatedButton.icon(
                      onPressed: () => _generateLedgerPDF(context, ref, orders, productNames),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('লেজার PDF', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (displayOrders.isEmpty)
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
                  itemCount: displayOrders.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final order = displayOrders[index];
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
                           if (order.chalanPic != null)
                            IconButton(
                              icon: const Icon(Icons.image_outlined, color: Colors.green),
                              tooltip: 'চালান ছবি দেখুন',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AppBar(
                                          title: const Text('চালান ছবি (Chalan Pic)'),
                                          automaticallyImplyLeading: false,
                                          actions: [
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () => Navigator.pop(context),
                                            ),
                                          ],
                                        ),
                                        Flexible(
                                          child: InteractiveViewer(
                                            child: order.chalanPic!.startsWith('http')
                                                ? Image.network(order.chalanPic!)
                                                : Image.file(File(order.chalanPic!)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                            tooltip: 'হালনাগাদ',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => UpdateOrderDialog(order: order, supplierId: supplierId),
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            tooltip: 'পিডিএফ ও অন্যান্য অপশন',
                            onSelected: (value) async {
                              final settings = ref.read(settingsControllerProvider).valueOrNull;
                              final pdfSavePath = settings?.pdfSavePath;
                              
                              final supplierList = ref.read(suppliersControllerProvider).valueOrNull ?? [];
                              final supplier = supplierList.cast<Supplier?>().firstWhere((s) => s?.id == supplierId, orElse: () => null);
                              
                              final productList = productsAsync.valueOrNull ?? [];
                              final product = productList.cast<ProductWithDetails?>().firstWhere((p) => p?.product.id == order.productId, orElse: () => null)?.product;

                              if (supplier == null || product == null) return;

                              if (value == 'download') {
                                try {
                                  final savedPath = await PdfGenerator.generateAndSaveSupplierOrderPdf(
                                    order: order,
                                    supplier: supplier,
                                    product: product,
                                    customSavePath: pdfSavePath,
                                  );
                                  if (savedPath != null && context.mounted) {
                                    DialogUtils.showSaveSuccessDialog(context, savedPath);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('PDF তৈরি করতে ব্যর্থ: $e')),
                                    );
                                  }
                                }
                              } else if (value == 'print') {
                                try {
                                  await PdfGenerator.printSupplierOrder(
                                    order: order,
                                    supplier: supplier,
                                    product: product,
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('প্রিন্ট ব্যর্থ: $e')),
                                    );
                                  }
                                }
                              } else if (value == 'view_online') {
                                if (order.pdfUrl != null) {
                                  await Share.share('অর্ডার পিডিএফ লিংক: ${order.pdfUrl!}', subject: 'Supplier Order PDF Link');
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'download',
                                child: Row(
                                  children: [
                                    Icon(Icons.download_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('মেমো ডাউনলোড করুন'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'print',
                                child: Row(
                                  children: [
                                    Icon(Icons.print_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('প্রিন্ট করুন'),
                                  ],
                                ),
                              ),
                              if (order.pdfUrl != null)
                                const PopupMenuItem(
                                  value: 'view_online',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('অনলাইন পিডিএফ শেয়ার'),
                                    ],
                                  ),
                                ),
                            ],
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
  }

  Future<void> _generateLedgerPDF(
    BuildContext context,
    WidgetRef ref,
    List<SupplierOrder> orders,
    Map<String, String> productNames,
  ) async {
    // 1. Pick start date (optional)
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'লেজারের শুরুর তারিখ নির্বাচন করুন (ঐচ্ছিক)',
      cancelText: 'সকল তারিখ',
      confirmText: 'বাছাই করুন',
    );

    if (!context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supplierList = ref.read(suppliersControllerProvider).valueOrNull ?? [];
      final supplier = supplierList.firstWhere((s) => s.id == supplierId);
      final payments = await ref.read(supplierPaymentsProvider(supplierId).future);
      final settings = ref.read(settingsControllerProvider).valueOrNull;

      final savedPath = await PdfGenerator.generateAndSaveSupplierLedgerPdf(
        supplier: supplier,
        orders: orders,
        payments: payments,
        productNames: productNames,
        startDate: pickedDate,
        customSavePath: settings?.pdfSavePath,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        if (savedPath != null) {
          DialogUtils.showSaveSuccessDialog(context, savedPath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('লেজার PDF তৈরিতে ত্রুটি: $e')),
        );
      }
    }
  }

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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
