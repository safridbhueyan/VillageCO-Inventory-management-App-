import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/pdf_generator.dart';
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

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _historyReceiptKey = GlobalKey();
  final GlobalKey _profitLossKey = GlobalKey();

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
        title: const Text(
          'হিসাব ও রিপোর্ট',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'লাভ-ক্ষতি হিসাব'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'বিক্রির খাতা'),
            Tab(icon: Icon(Icons.money_off_rounded), text: 'খরচের খাতা'),
            Tab(
              icon: Icon(Icons.auto_graph_rounded),
              text: 'বিক্রিত পণ্য বিশ্লেষণ',
            ),
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

  // TAB 1: Financial Summaries
  Widget _buildFinancialsTab(
    BuildContext context,
    AsyncValue<DashboardMetrics> metricsAsync,
  ) {
    final theme = Theme.of(context);

    return metricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('হিসাব লোড ব্যর্থ: $err')),
      data: (metrics) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'লাভ-ক্ষতি বিবরণী',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              RepaintBoundary(
                key: _profitLossKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'লাভ-ক্ষতি বিবরণী (Profit & Loss Statement)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'তারিখ: ${Formatters.dateTime(DateTime.now())}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                          const Divider(height: 24, color: Colors.black38),
                          _buildPlRow(
                            'আজকের বিক্রির পরিমাণ',
                            Formatters.currency(metrics.todaySales),
                            isPositive: true,
                          ),
                          const SizedBox(height: 10),
                          _buildPlRow(
                            'মজুদ পণ্যের মূল্য',
                            Formatters.currency(metrics.inventoryValue),
                          ),
                          const SizedBox(height: 10),
                          _buildPlRow(
                            'মোট খরচের পরিমাণ',
                            '- ${Formatters.currency(metrics.totalExpenses)}',
                            isNegative: true,
                          ),
                          const Divider(height: 24, color: Colors.black38),
                          _buildPlRow(
                            'আজকের নিট লাভ',
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
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'রিপোর্ট এক্সপোর্ট ও প্রিন্ট করুন',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _exportProfitLossCsv(metrics),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('CSV শীট'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _exportProfitLossPdf(metrics),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _printProfitLoss(metrics),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('প্রিন্ট'),
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

  Widget _buildPlRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    bool isPositive = false,
    bool isNegative = false,
  }) {
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

  // TAB 2: Sales Log
  Widget _buildSalesLogTab(
    BuildContext context,
    AsyncValue<List<SaleWithDetails>> salesHistoryAsync,
  ) {
    final filter = ref.watch(salesFilterProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'রশিদ আইডি বা কাস্টমারের নাম দিয়ে খুঁজুন...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    ref
                        .read(salesFilterProvider.notifier)
                        .update((s) => s.copyWith(searchQuery: val));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: filter.paymentMethod,
                    hint: const Text('পদ্ধতি'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('সব')),
                      DropdownMenuItem(value: 'Cash', child: Text('ক্যাশ')),
                      DropdownMenuItem(
                        value: 'Mobile Banking',
                        child: Text('মোবাইল'),
                      ),
                      DropdownMenuItem(value: 'Card', child: Text('কার্ড')),
                    ],
                    onChanged: (val) {
                      ref
                          .read(salesFilterProvider.notifier)
                          .update((s) => s.copyWith(paymentMethod: val));
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
            error: (err, st) =>
                Center(child: Text('বিক্রি লগ লোড ব্যর্থ: $err')),
            data: (sales) {
              if (sales.isEmpty) {
                return const Center(
                  child: Text('ম্যাচিং কোনো বিক্রির রেকর্ড পাওয়া যায়নি।'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sales.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final saleWithDetails = sales[index];
                  final sale = saleWithDetails.sale;
                  final customer =
                      saleWithDetails.customer?.name ?? 'সাধারণ কাস্টমার';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      customer,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'রশিদ: ${sale.id.substring(0, 8).toUpperCase()} • ${Formatters.dateTime(sale.date)} • ${sale.paymentMethod == "Cash" ? "ক্যাশ" : (sale.paymentMethod == "Card" ? "কার্ড" : "মোবাইল")}',
                    ),
                    trailing: Text(
                      Formatters.currency(sale.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () =>
                        _showInvoiceReceiptDetails(context, saleWithDetails),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // TAB 3: Expenses
  Widget _buildExpensesTab(
    BuildContext context,
    AsyncValue<List<Expense>> expensesAsync,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'দোকানের আনুষঙ্গিক খরচ সমূহ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('খরচ লিখুন'),
              ),
            ],
          ),
        ),
        Expanded(
          child: expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) =>
                Center(child: Text('খরচ তালিকা লোড ব্যর্থ: $err')),
            data: (expenses) {
              if (expenses.isEmpty) {
                return const Center(child: Text('কোনো খরচের বিবরণ নেই।'));
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
                    title: Text(
                      ex.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_translateCategory(ex.category)} • ${Formatters.date(ex.date)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '- ${Formatters.currency(ex.amount)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            ref
                                .read(expensesControllerProvider.notifier)
                                .deleteExpense(ex.id);
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

  String _translateCategory(String category) {
    switch (category) {
      case 'Rent':
        return 'দোকান ভাড়া';
      case 'Electricity':
        return 'বিদ্যুৎ বিল';
      case 'Internet':
        return 'ইন্টারনেট বিল';
      case 'Transport':
        return 'পরিবহন ভাড়া';
      case 'Salary':
        return 'কর্মচারী বেতন';
      default:
        return 'অন্যান্য খরচ';
    }
  }

  // TAB 4: Product Insights
  Widget _buildProductInsightsTab(
    BuildContext context,
    AsyncValue<List<ProductSaleAggregation>> topSellingAsync,
  ) {
    final theme = Theme.of(context);
    return topSellingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('বিশ্লেষণ লোড ব্যর্থ: $err')),
      data: (insights) {
        if (insights.isEmpty) {
          return const Center(
            child: Text('বিশ্লেষণ দেখতে পিওএস থেকে পণ্য বিক্রি করুন।'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'সবচেয়ে বেশি বিক্রি হওয়া পণ্যসমূহ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.take(5).map((e) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(e.product.name.substring(0, 1)),
                ),
                title: Text(
                  e.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'বিক্রিত মোট মূল্য: ${Formatters.currency(e.totalRevenue)}',
                ),
                trailing: Text(
                  '${Formatters.number(e.quantitySold)} টি বিক্রিত',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
              title: const Text('নতুন খরচ লিখুন'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'খরচের নাম/খাত *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'খরচের পরিমাণ (টাকা) *',
                        prefixText: '৳',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'ক্যাটাগরি',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Rent',
                          child: Text('দোকান ভাড়া'),
                        ),
                        DropdownMenuItem(
                          value: 'Electricity',
                          child: Text('বিদ্যুৎ বিল'),
                        ),
                        DropdownMenuItem(
                          value: 'Internet',
                          child: Text('ইন্টারনেট বিল'),
                        ),
                        DropdownMenuItem(
                          value: 'Transport',
                          child: Text('পরিবহন ভাড়া'),
                        ),
                        DropdownMenuItem(
                          value: 'Salary',
                          child: Text('কর্মচারী বেতন'),
                        ),
                        DropdownMenuItem(
                          value: 'Misc',
                          child: Text('অন্যান্য খরচ'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('খরচের তারিখ'),
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
                          if (dt != null)
                            setDialogState(() => selectedDate = dt);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'বিবরণ (ঐচ্ছিক)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('বাতিল'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (name.isEmpty || amt <= 0) return;

                    ref
                        .read(expensesControllerProvider.notifier)
                        .addExpense(
                          name,
                          amt,
                          selectedCategory,
                          selectedDate,
                          descController.text.trim().isEmpty
                              ? null
                              : descController.text.trim(),
                        );
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
  }

  void _showInvoiceReceiptDetails(
    BuildContext context,
    SaleWithDetails saleWithDetails,
  ) {
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
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
            child: RepaintBoundary(
              key: _historyReceiptKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ভিলেজকো স্টোর',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      'বিক্রির রশিদের কপি',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.black38, thickness: 1),
                    _buildReceiptMetaRow(
                      'রশিদ নং',
                      sale.id.substring(0, 8).toUpperCase(),
                    ),
                    _buildReceiptMetaRow(
                      'তারিখ ও সময়',
                      Formatters.dateTime(sale.date),
                    ),
                    _buildReceiptMetaRow(
                      'পেমেন্ট পদ্ধতি',
                      sale.paymentMethod == 'Cash'
                          ? 'ক্যাশ'
                          : (sale.paymentMethod == 'Card'
                                ? 'কার্ড'
                                : 'মোবাইল ব্যাংকিং'),
                    ),
                    _buildReceiptMetaRow(
                      'ক্রেতা',
                      customer?.name ?? 'সাধারণ কাস্টমার',
                    ),
                    const Divider(color: Colors.black38, thickness: 1),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'পণ্যের বিবরণ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'পরিমাণ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'মোট টাকা',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Column(
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${Formatters.number(item.item.quantity)} ${item.product.unit}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Formatters.currency(subtotal),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(color: Colors.black38, thickness: 1),
                    _buildReceiptFinancialRow(
                      'উপ-মোট বিল',
                      Formatters.currency(sale.subtotal),
                    ),
                    _buildReceiptFinancialRow(
                      'ডিসকাউন্ট ছাড়',
                      '- ${Formatters.currency(sale.discount)}',
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'পরিশোধযোগ্য মোট বিল',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          Formatters.currency(sale.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('প্রিন্ট'),
            onPressed: () async {
              try {
                final itemsMapped = itemsList
                    .map(
                      (item) => {
                        'name': item.product.name,
                        'qty':
                            '${Formatters.number(item.item.quantity)} ${item.product.unit}',
                        'total': Formatters.currency(
                          item.item.price * item.item.quantity,
                        ),
                      },
                    )
                    .toList();

                await PdfGenerator.printTextReceipt(
                  saleId: sale.id,
                  dateStr: Formatters.dateTime(sale.date),
                  paymentMethod: sale.paymentMethod == 'Cash'
                      ? 'ক্যাশ'
                      : (sale.paymentMethod == 'Card'
                            ? 'কার্ড'
                            : 'মোবাইল ব্যাংকিং'),
                  customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                  items: itemsMapped,
                  subtotal: sale.subtotal,
                  discount: sale.discount,
                  total: sale.total,
                  paidAmount: sale
                      .total, // Assume paid amount is total for historic receipt print
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('প্রিন্ট ব্যর্থ হয়েছে: $e')),
                  );
                }
              }
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('PDF রসিদ'),
            onPressed: () async {
              try {
                final itemsMapped = itemsList
                    .map(
                      (item) => {
                        'name': item.product.name,
                        'qty':
                            '${Formatters.number(item.item.quantity)} ${item.product.unit}',
                        'total': Formatters.currency(
                          item.item.price * item.item.quantity,
                        ),
                      },
                    )
                    .toList();

                await PdfGenerator.generateAndSaveTextReceipt(
                  saleId: sale.id,
                  dateStr: Formatters.dateTime(sale.date),
                  paymentMethod: sale.paymentMethod == 'Cash'
                      ? 'ক্যাশ'
                      : (sale.paymentMethod == 'Card'
                            ? 'কার্ড'
                            : 'মোবাইল ব্যাংকিং'),
                  customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                  items: itemsMapped,
                  subtotal: sale.subtotal,
                  discount: sale.discount,
                  total: sale.total,
                  paidAmount: sale.total,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('রসিদটি সফলভাবে ডাউনলোড করা হয়েছে'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF তৈরি করতে ব্যর্থ: $e')),
                  );
                }
              }
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Export Sales History
  Future<void> _exportCsvData() async {
    final list = ref.read(salesHistoryProvider).value ?? [];
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ডাউনলোড করার মতো কোনো বিক্রির রেকর্ড নেই।'),
        ),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln(
        'Invoice ID,Date,Customer,Subtotal,Discount,Total,Payment Method',
      );

      for (final item in list) {
        final s = item.sale;
        final c = item.customer?.name ?? 'Walk-in';
        buffer.writeln(
          '${s.id},${s.date.toIso8601String()},$c,${s.subtotal},${s.discount},${s.total},${s.paymentMethod}',
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(
        dir.path,
        'villageco_sales_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      final file = File(path);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV ফাইল এখানে ডাউনলোড হয়েছে: $path'),
            action: SnackBarAction(label: 'ঠিক আছে', onPressed: () {}),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ডাউনলোড ব্যর্থ হয়েছে: $e')));
      }
    }
  }

  Future<void> _exportProfitLossCsv(DashboardMetrics metrics) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('বিবরণ,টাকা');
      buffer.writeln('আজকের বিক্রির পরিমাণ,${metrics.todaySales}');
      buffer.writeln('মজুদ পণ্যের মূল্য,${metrics.inventoryValue}');
      buffer.writeln('মোট খরচের পরিমাণ,-${metrics.totalExpenses}');
      buffer.writeln('আজকের নিট লাভ,${metrics.netProfit}');

      final downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getDownloadsDirectory();

      final targetDir =
          downloadsDir ?? await getApplicationDocumentsDirectory();
      final file = File(
        '${targetDir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'লাভ-ক্ষতি বিবরণী CSV-তে ডাউনলোড হয়েছে: ${file.path}',
            ),
          ),
        );
      }
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Profit & Loss CSV Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV রপ্তানি ব্যর্থ: $e')));
      }
    }
  }

  Future<void> _exportProfitLossPdf(DashboardMetrics metrics) async {
    try {
      await PdfGenerator.generateAndSaveTextProfitLoss(
        todaySales: metrics.todaySales,
        inventoryValue: metrics.inventoryValue,
        totalExpenses: metrics.totalExpenses,
        netProfit: metrics.netProfit,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('লাভ-ক্ষতি PDF রিপোর্ট ডাউনলোড সম্পন্ন হয়েছে'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF তৈরি করতে ব্যর্থ: $e')));
      }
    }
  }

  Future<void> _printProfitLoss(DashboardMetrics metrics) async {
    try {
      await PdfGenerator.printTextProfitLoss(
        todaySales: metrics.todaySales,
        inventoryValue: metrics.inventoryValue,
        totalExpenses: metrics.totalExpenses,
        netProfit: metrics.netProfit,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('প্রিন্ট ব্যর্থ হয়েছে: $e')));
      }
    }
  }
}
