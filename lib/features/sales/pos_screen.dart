import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import '../products/products_controller.dart';
import '../categories/categories_controller.dart';
import '../suppliers/suppliers_controller.dart'; 
import '../reports/reports_controller.dart';
import 'pos_controller.dart';

final posCustomersListProvider = FutureProvider<List<Customer>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.customers).get();
});

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _productSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    final cart = ref.watch(posCartProvider);
    final productsAsync = ref.watch(productsListProvider);
    final categoriesAsync = ref.watch(categoriesControllerProvider);
    final customersAsync = ref.watch(posCustomersListProvider);

    final filteredProducts = productsAsync.maybeWhen(
      data: (list) {
        if (_productSearchQuery.isEmpty) return list;
        final q = _productSearchQuery.toLowerCase();
        return list.where((item) {
          final p = item.product;
          return p.name.toLowerCase().contains(q) ||
                 (p.barcode != null && p.barcode!.contains(q)) ||
                 (p.brand != null && p.brand!.toLowerCase().contains(q));
        }).toList();
      },
      orElse: () => <ProductWithDetails>[],
    );

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('বিক্রয় কেন্দ্র (POS)', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'কার্ট খালি করুন',
              onPressed: () => ref.read(posCartProvider.notifier).clearCart(),
            ),
          ],
        ),
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: _buildCatalogPanel(context, filteredProducts, categoriesAsync),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 4,
              child: _buildCheckoutPanel(context, cart, customersAsync),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('বিক্রয় কেন্দ্র (POS)', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: [
              const Tab(icon: Icon(Icons.grid_view_rounded), text: 'পণ্য তালিকা'),
              Tab(
                icon: Badge(
                  label: Text(cart.items.length.toString()),
                  isLabelVisible: cart.items.isNotEmpty,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                text: 'কার্ট',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCatalogPanel(context, filteredProducts, categoriesAsync),
            _buildCheckoutPanel(context, cart, customersAsync),
          ],
        ),
      );
    }
  }

  // Panel 1: Product Selector
  Widget _buildCatalogPanel(
    BuildContext context,
    List<ProductWithDetails> products,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    final theme = Theme.of(context);
    final filter = ref.watch(productsFilterProvider);

    return Container(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'নাম বা বারকোড দিয়ে পণ্য খুঁজুন...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _productSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _productSearchQuery = '');
                        },
                      )
                    : const Icon(Icons.qr_code),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                setState(() => _productSearchQuery = val);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
            child: Row(
              children: [
                ActionChip(
                  label: const Text('সব পণ্য'),
                  onPressed: () {
                    ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(categoryId: null));
                  },
                  backgroundColor: filter.categoryId == null ? theme.colorScheme.primaryContainer : null,
                  labelStyle: TextStyle(color: filter.categoryId == null ? theme.colorScheme.primary : null),
                ),
                const SizedBox(width: 8),
                categoriesAsync.maybeWhen(
                  data: (categories) => Row(
                    children: categories.map((cat) {
                      final isSelected = filter.categoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          label: Text(cat.name),
                          onPressed: () {
                            ref.read(productsFilterProvider.notifier).update((s) => s.copyWith(categoryId: cat.id));
                          },
                          backgroundColor: isSelected ? theme.colorScheme.primaryContainer : null,
                          labelStyle: TextStyle(color: isSelected ? theme.colorScheme.primary : null),
                        ),
                      );
                    }).toList(),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('ম্যাচিং কোনো পণ্য পাওয়া যায়নি।'))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final item = products[index];
                      final p = item.product;
                      final isOut = p.currentStock <= 0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: InkWell(
                          onTap: isOut
                              ? null
                              : () {
                                  ref.read(posCartProvider.notifier).addItem(p);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${p.name} কার্টে যোগ হয়েছে'),
                                      duration: const Duration(milliseconds: 600),
                                    ),
                                  );
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Opacity(
                            opacity: isOut ? 0.5 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: p.imagePath != null && File(p.imagePath!).existsSync()
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                File(p.imagePath!),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            )
                                          : Icon(
                                              Icons.shopping_bag_outlined,
                                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Formatters.currency(p.sellingPrice),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOut ? 'স্টক খালি' : '${Formatters.number(p.currentStock)} ${p.unit} অবশিষ্ট',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOut ? Colors.red : Colors.grey,
                                      fontWeight: isOut ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Panel 2: Cart & Checkout (Simplified flat Taka discounts)
  Widget _buildCheckoutPanel(
    BuildContext context,
    PosCartState cart,
    AsyncValue<List<Customer>> customersAsync,
  ) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'চলতি কার্ট',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cart.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('কার্ট খালি রয়েছে', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(Formatters.currency(item.customPrice)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                ref.read(posCartProvider.notifier).updateQuantity(
                                      item.product.id,
                                      item.quantity - 1,
                                    );
                              },
                            ),
                            Text(
                              Formatters.number(item.quantity),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                ref.read(posCartProvider.notifier).updateQuantity(
                                      item.product.id,
                                      item.quantity + 1,
                                    );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                ref.read(posCartProvider.notifier).removeItem(item.product.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: customersAsync.maybeWhen(
                  data: (customers) => DropdownButtonFormField<Customer?>(
                    value: cart.selectedCustomer,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'কাস্টমার', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('সাধারণ কাস্টমার')),
                      ...customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                    ],
                    onChanged: (val) {
                      ref.read(posCartProvider.notifier).setCustomer(val);
                    },
                  ),
                  orElse: () => const Text('কাস্টমার তালিকা লোড হচ্ছে...'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showDiscountDialog(context, cart),
                icon: const Icon(Icons.percent_rounded, size: 18),
                label: Text(cart.discount > 0 ? 'ছাড়: ৳${Formatters.number(cart.discountAmount)}' : 'ডিসকাউন্ট'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Cash', label: Text('ক্যাশ'), icon: Icon(Icons.money)),
              ButtonSegment(value: 'Mobile Banking', label: Text('মোবাইল ব্যাংকিং'), icon: Icon(Icons.phone_iphone)),
              ButtonSegment(value: 'Card', label: Text('কার্ড'), icon: Icon(Icons.credit_card)),
            ],
            selected: {cart.paymentMethod},
            onSelectionChanged: (set) {
              ref.read(posCartProvider.notifier).setPaymentMethod(set.first);
            },
          ),
          
          const SizedBox(height: 16),

          Column(
            children: [
              _buildCheckoutSummaryRow('উপ-মোট বিল', Formatters.currency(cart.subtotal)),
              if (cart.discount > 0)
                _buildCheckoutSummaryRow('ডিসকাউন্ট ছাড়', '- ${Formatters.currency(cart.discountAmount)}', color: Colors.red),
              const Divider(height: 16),
              _buildCheckoutSummaryRow(
                'মোট পরিশোধযোগ্য বিল',
                Formatters.currency(cart.total),
                isBold: true,
                fontSize: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: cart.items.isEmpty
                  ? null
                  : () async {
                      try {
                        final completedSale = await ref.read(posCartProvider.notifier).completeSale();
                        ref.invalidate(salesHistoryProvider);
                        ref.invalidate(dashboardMetricsProvider);
                        if (mounted) {
                          _showInvoiceReceiptDialog(context, completedSale, cart);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('বিক্রি সম্পন্ন করতে ত্রুটি: $e')),
                        );
                      }
                    },
              child: const Text(
                'বিক্রি সম্পন্ন করুন',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummaryRow(String label, String value, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: color != null && !isBold ? color : null,
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
      ),
    );
  }

  // Simplified Taka Discount Dialog
  void _showDiscountDialog(BuildContext context, PosCartState cart) {
    final discountController = TextEditingController(text: cart.discount.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('অর্ডার ডিসকাউন্ট (টাকা)'),
        content: TextField(
          controller: discountController,
          decoration: const InputDecoration(
            labelText: 'ডিসকাউন্টের পরিমাণ (৳)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () {
              discountController.clear();
              ref.read(posCartProvider.notifier).applyDiscount(0.0);
              Navigator.pop(context);
            },
            child: const Text('ডিসকাউন্ট মুছুন', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(discountController.text) ?? 0.0;
              ref.read(posCartProvider.notifier).applyDiscount(amt, isPercentage: false);
              Navigator.pop(context);
            },
            child: const Text('প্রয়োগ করুন'),
          ),
        ],
      ),
    );
  }

  // Invoice Receipt dialog (Bangla)
  void _showInvoiceReceiptDialog(BuildContext context, Sale sale, PosCartState cartStateAtCheckout) {
    final theme = Theme.of(context);
    final itemsList = cartStateAtCheckout.items;
    final discount = cartStateAtCheckout.discountAmount;
    final subtotal = cartStateAtCheckout.subtotal;
    final total = cartStateAtCheckout.total;
    final customer = cartStateAtCheckout.selectedCustomer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ভিলেজকো স্টোর', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              const Text('মুদি দোকান ও পিওএস কেন্দ্র', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const Text('মোবাইল: +৮৮০ ১৭০০০০০০০০', style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 12),
              const Divider(color: Colors.black38, thickness: 1),
              
              _buildReceiptMetaRow('রশিদ নং', sale.id.substring(0, 8).toUpperCase()),
              _buildReceiptMetaRow('তারিখ ও সময়', Formatters.dateTime(sale.date)),
              _buildReceiptMetaRow('পেমেন্ট পদ্ধতি', sale.paymentMethod == 'Cash' ? 'ক্যাশ' : (sale.paymentMethod == 'Card' ? 'কার্ড' : 'মোবাইল ব্যাংকিং')),
              _buildReceiptMetaRow('ক্রেতার নাম', customer?.name ?? 'সাধারণ কাস্টমার'),
              const Divider(color: Colors.black38, thickness: 1),
              
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 3, child: Text('পণ্যের বিবরণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                  Expanded(flex: 1, child: Text('পরিমাণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('মোট টাকা', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.right)),
                ],
              ),
              const SizedBox(height: 6),
              
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: itemsList.map((item) {
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
                                '${Formatters.number(item.quantity)} ${item.product.unit}',
                                style: const TextStyle(fontSize: 11, color: Colors.black),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                Formatters.currency(item.subtotal),
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

              _buildReceiptFinancialRow('উপ-মোট বিল', Formatters.currency(subtotal)),
              if (discount > 0)
                _buildReceiptFinancialRow('ডিসকাউন্ট ছাড়', '- ${Formatters.currency(discount)}'),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('পরিশোধযোগ্য মোট বিল', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                  Text(Formatters.currency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('ভিলেজকো স্টোরে কেনাকাটার জন্য ধন্যবাদ!', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.black)),
              const SizedBox(height: 8),
              const Icon(Icons.bar_chart, size: 50, color: Colors.black54),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('রশিদ প্রিন্ট করুন'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('থার্মাল প্রিন্টারের সাথে সংযোগ করা হচ্ছে...')),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('নতুন অর্ডার'),
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
}
