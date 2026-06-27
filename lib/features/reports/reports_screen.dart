import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fl_chart/fl_chart.dart';

import '../../core/database/database.dart';
import '../../core/utils/formatters.dart';
import 'reports_controller.dart';
import '../products/products_controller.dart';
import '../sales/pos_controller.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final salesHistoryAsync = ref.watch(salesHistoryProvider);
    final expensesAsync = ref.watch(expensesControllerProvider);
    final topSellingAsync = ref.watch(topSellingProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Financials'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Sales Log'),
            Tab(icon: Icon(Icons.money_off_rounded), text: 'Expenses'),
            Tab(icon: Icon(Icons.auto_graph_rounded), text: 'Product Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFinancialsTab(context, metricsAsync),
          _buildSalesLogTab(context, salesHistoryAsync),
          _buildExpensesTab(context, expensesAsync),
          _buildProductInsightsTab(context, topSellingAsync),
        ],
      ),
    );
  }

  // TAB 1: Financial Summaries and download actions
  Widget _buildFinancialsTab(BuildContext context, AsyncValue<DashboardMetrics> metricsAsync) {
    final theme = Theme.of(context);
    
    return metricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
      data: (metrics) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profit & Loss Statements', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // Profit cards
              Card(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildPlRow('Gross Sales Revenue', Formatters.currency(metrics.todaySales + metrics.monthlySales), isPositive: true),
                      const SizedBox(height: 10),
                      _buildPlRow('Inventory Valuation', Formatters.currency(metrics.inventoryValue)),
                      const SizedBox(height: 10),
                      _buildPlRow('Total Expenses Logged', '- ${Formatters.currency(metrics.totalExpenses)}', isNegative: true),
                      const Divider(height: 24),
                      _buildPlRow(
                        'Net Profit Margin',
                        Formatters.currency(metrics.netProfit),
                        isBold: true,
                        fontSize: 16,
                        isPositive: metrics.netProfit >= 0,
                        isNegative: metrics.netProfit < 0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Download CSV and PDF
              Text('Export Reports Data', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _exportCsvData(),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Export CSV Sheet'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Generating PDF Report format...')),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Download PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlRow(String label, String value, {bool isBold = false, double fontSize = 14, bool isPositive = false, bool isNegative = false}) {
    Color? color;
    if (isPositive) color = Colors.green;
    if (isNegative) color = Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
            color: color,
          ),
        ),
      ],
    );
  }

  // TAB 2: Sales log history with date range filtering
  Widget _buildSalesLogTab(BuildContext context, AsyncValue<List<SaleWithDetails>> salesHistoryAsync) {
    final filter = ref.watch(salesFilterProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search sales by ID, product, customer...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    ref.read(salesFilterProvider.notifier).update((s) => s.copyWith(searchQuery: val));
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Payment method filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: filter.paymentMethod,
                    hint: const Text('Payment'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Mobile Banking', child: Text('Mobile')),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                    ],
                    onChanged: (val) {
                      ref.read(salesFilterProvider.notifier).update((s) => s.copyWith(paymentMethod: val));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: salesHistoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('Error: $err')),
            data: (sales) {
              if (sales.isEmpty) {
                return const Center(child: Text('No matching sales transactions.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sales.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final saleWithDetails = sales[index];
                  final sale = saleWithDetails.sale;
                  final customer = saleWithDetails.customer?.name ?? 'Walk-in Customer';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(customer, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${sale.id.substring(0, 8).toUpperCase()} • ${Formatters.dateTime(sale.date)} • ${sale.paymentMethod}'),
                    trailing: Text(Formatters.currency(sale.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onTap: () => _showInvoiceReceiptDetails(context, saleWithDetails),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // TAB 3: Expenses log and add dialog
  Widget _buildExpensesTab(BuildContext context, AsyncValue<List<Expense>> expensesAsync) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Business Expenses Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              ),
            ],
          ),
        ),
        Expanded(
          child: expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('Error: $err')),
            data: (expenses) {
              if (expenses.isEmpty) {
                return const Center(child: Text('No expenses logged.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: expenses.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final ex = expenses[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.money_off, color: Colors.white),
                    ),
                    title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${ex.category} • ${Formatters.date(ex.date)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('- ${Formatters.currency(ex.amount)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () {
                            ref.read(expensesControllerProvider.notifier).deleteExpense(ex.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // TAB 4: Top/worst items analytics list
  Widget _buildProductInsightsTab(BuildContext context, AsyncValue<List<ProductSaleAggregation>> topSellingAsync) {
    final theme = Theme.of(context);
    return topSellingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
      data: (insights) {
        if (insights.isEmpty) {
          return const Center(child: Text('Generate sales in POS to view product analytics.'));
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Top Selling Products (Quantity)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...insights.take(5).map((e) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(e.product.name.substring(0, 1))),
                title: Text(e.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Revenue Generated: ${Formatters.currency(e.totalRevenue)}'),
                trailing: Text('${Formatters.number(e.quantitySold)} units', style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }),
          ],
        );
      },
    );
  }

  // Dialog to Add Expense
  void _showAddExpenseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Rent';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log Business Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Expense Name *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount Spent *', prefixText: '\$', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                        DropdownMenuItem(value: 'Electricity', child: Text('Electricity')),
                        DropdownMenuItem(value: 'Internet', child: Text('Internet')),
                        DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                        DropdownMenuItem(value: 'Salary', child: Text('Salary')),
                        DropdownMenuItem(value: 'Misc', child: Text('Misc. Overhead')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Transaction Date'),
                      subtitle: Text(Formatters.date(selectedDate)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final dt = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (dt != null) setDialogState(() => selectedDate = dt);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (name.isEmpty || amt <= 0) return;

                    ref.read(expensesControllerProvider.notifier).addExpense(
                          name,
                          amt,
                          selectedCategory,
                          selectedDate,
                          descController.text.trim().isEmpty ? null : descController.text.trim(),
                        );
                    Navigator.pop(context);
                  },
                  child: const Text('Log Expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Invoice detailed dialog from log click
  void _showInvoiceReceiptDetails(BuildContext context, SaleWithDetails saleWithDetails) {
    final sale = saleWithDetails.sale;
    final customer = saleWithDetails.customer;
    final itemsList = saleWithDetails.items;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('VILLAGECO INVENTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              const Text('Sales History Duplicate Invoice', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 12),
              const Divider(color: Colors.black38, thickness: 1),
              _buildReceiptMetaRow('Invoice ID', sale.id.substring(0, 8).toUpperCase()),
              _buildReceiptMetaRow('Date/Time', Formatters.dateTime(sale.date)),
              _buildReceiptMetaRow('Payment Method', sale.paymentMethod),
              _buildReceiptMetaRow('Customer', customer?.name ?? 'Walk-in'),
              const Divider(color: Colors.black38, thickness: 1),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 3, child: Text('Item Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                  Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.right)),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: itemsList.map((item) {
                      final subtotal = item.item.price * item.item.quantity;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.product.name,
                                style: const TextStyle(fontSize: 11, color: Colors.black),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${Formatters.number(item.item.quantity)} ${item.product.unit}',
                                style: const TextStyle(fontSize: 11, color: Colors.black),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                Formatters.currency(subtotal),
                                style: const TextStyle(fontSize: 11, color: Colors.black),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(color: Colors.black38, thickness: 1),
              _buildReceiptFinancialRow('Subtotal', Formatters.currency(sale.subtotal)),
              _buildReceiptFinancialRow('Discount Applied', '- ${Formatters.currency(sale.discount)}'),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                  Text(Formatters.currency(sale.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Re-Print'),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Re-sending print jobs...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReceiptFinancialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Export Sales History to real CSV file
  Future<void> _exportCsvData() async {
    final list = ref.read(salesHistoryProvider).value ?? [];
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sales records to export.')),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Invoice ID,Date,Customer,Subtotal,Discount,Total,Payment Method');
      
      for (final item in list) {
        final s = item.sale;
        final c = item.customer?.name ?? 'Walk-in';
        buffer.writeln('${s.id},${s.date.toIso8601String()},$c,${s.subtotal},${s.discount},${s.total},${s.paymentMethod}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'villageco_sales_${DateTime.now().millisecondsSinceEpoch}.csv');
      final file = File(path);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV file exported to: $path'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
