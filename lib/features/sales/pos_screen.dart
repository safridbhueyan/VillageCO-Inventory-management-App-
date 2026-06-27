import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import '../products/products_controller.dart';
import '../categories/categories_controller.dart';
import '../suppliers/suppliers_controller.dart'; // We can use suppliers or customers provider if any
import '../reports/reports_controller.dart';
import 'pos_controller.dart';

// Fetch customer lists for POS selector
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

    // Apply inline POS search query filter to product list
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
          title: const Text('POS terminal', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Cart',
              onPressed: () => ref.read(posCartProvider.notifier).clearCart(),
            ),
          ],
        ),
        body: Row(
          children: [
            // Left Workspace: Catalog
            Expanded(
              flex: 5,
              child: _buildCatalogPanel(context, filteredProducts, categoriesAsync),
            ),
            const VerticalDivider(width: 1),
            // Right Workspace: Cart & Checkout
            Expanded(
              flex: 4,
              child: _buildCheckoutPanel(context, cart, customersAsync),
            ),
          ],
        ),
      );
    } else {
      // Mobile screen: Tabbed Workspace
      return Scaffold(
        appBar: AppBar(
          title: const Text('POS Terminal', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: [
              const Tab(icon: Icon(Icons.grid_view_rounded), text: 'Catalog'),
              Tab(
                icon: Badge(
                  label: Text(cart.items.length.toString()),
                  isLabelVisible: cart.items.isNotEmpty,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                text: 'Cart',
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

  // PANEL 1: Product Selector Catalog
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
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search catalog by name or barcode...',
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
          // Categories horizontal list
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
            child: Row(
              children: [
                ActionChip(
                  label: const Text('All Categories'),
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
          // Product Grid
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No matching products found.'))
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
                                      content: Text('${p.name} added to cart'),
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
                                      child: Icon(
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
                                    isOut ? 'Out of Stock' : '${Formatters.number(p.currentStock)} ${p.unit} left',
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

  // PANEL 2: Active Cart & Checkout details
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
            'Active Cart',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Cart Items List
          Expanded(
            child: cart.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Cart is empty', style: TextStyle(color: Colors.grey)),
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
          
          // Customer & Discount controls
          Row(
            children: [
              // Customer selection dropdown
              Expanded(
                child: customersAsync.maybeWhen(
                  data: (customers) => DropdownButtonFormField<Customer?>(
                    value: cart.selectedCustomer,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Anonymous Customer')),
                      ...customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                    ],
                    onChanged: (val) {
                      ref.read(posCartProvider.notifier).setCustomer(val);
                    },
                  ),
                  orElse: () => const Text('Loading customers...'),
                ),
              ),
              const SizedBox(width: 12),
              // Discount button
              OutlinedButton.icon(
                onPressed: () => _showDiscountDialog(context, cart),
                icon: const Icon(Icons.percent_rounded, size: 18),
                label: Text(cart.discount > 0 ? 'Disc: \$${Formatters.number(cart.discountAmount)}' : 'Discount'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment Methods Segmented Button
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Cash', label: Text('Cash'), icon: Icon(Icons.money)),
              ButtonSegment(value: 'Mobile Banking', label: Text('Mobile'), icon: Icon(Icons.phone_iphone)),
              ButtonSegment(value: 'Card', label: Text('Card'), icon: Icon(Icons.credit_card)),
            ],
            selected: {cart.paymentMethod},
            onSelectionChanged: (set) {
              ref.read(posCartProvider.notifier).setPaymentMethod(set.first);
            },
          ),
          
          const SizedBox(height: 16),

          // Invoice Summaries
          Column(
            children: [
              _buildCheckoutSummaryRow('Subtotal', Formatters.currency(cart.subtotal)),
              if (cart.discount > 0)
                _buildCheckoutSummaryRow('Discount', '- ${Formatters.currency(cart.discountAmount)}', color: Colors.red),
              const Divider(height: 16),
              _buildCheckoutSummaryRow(
                'Total Bill',
                Formatters.currency(cart.total),
                isBold: true,
                fontSize: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Checkout CTA button
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
                        // complete sale in DB and get sale log back
                        final completedSale = await ref.read(posCartProvider.notifier).completeSale();
                        // reload history
                        ref.invalidate(salesHistoryProvider);
                        ref.invalidate(dashboardMetricsProvider);
                        // show receipt invoice popup dialog
                        if (mounted) {
                          _showInvoiceReceiptDialog(context, completedSale, cart);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Checkout failed: $e')),
                        );
                      }
                    },
              child: const Text(
                'Complete Checkout',
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

  // Discount configuration dialog
  void _showDiscountDialog(BuildContext context, PosCartState cart) {
    final discountController = TextEditingController(text: cart.discount.toString());
    bool isPercent = cart.isPercentageDiscount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Order Discount'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: discountController,
                  decoration: InputDecoration(
                    labelText: 'Discount Rate',
                    prefixText: isPercent ? null : '\$',
                    suffixText: isPercent ? '%' : null,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                 Wrap(
                   spacing: 12,
                   runSpacing: 8,
                   alignment: WrapAlignment.center,
                   children: [
                     ChoiceChip(
                       label: const Text('Flat Discount'),
                       selected: !isPercent,
                       onSelected: (val) => setDialogState(() => isPercent = false),
                     ),
                     ChoiceChip(
                       label: const Text('Percentage (%)'),
                       selected: isPercent,
                       onSelected: (val) => setDialogState(() => isPercent = true),
                     ),
                   ],
                 ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              discountController.clear();
              ref.read(posCartProvider.notifier).applyDiscount(0.0);
              Navigator.pop(context);
            },
            child: const Text('Remove Discount', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(discountController.text) ?? 0.0;
              ref.read(posCartProvider.notifier).applyDiscount(amt, isPercentage: isPercent);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // Printable Invoice Receipt popup
  void _showInvoiceReceiptDialog(BuildContext context, Sale sale, PosCartState cartStateAtCheckout) {
    final theme = Theme.of(context);
    final itemsList = cartStateAtCheckout.items; // snapshot of items checked out
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
              // Header
              const Text('VILLAGECO INVENTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              const Text('Retail Grocery Store & POS Terminal', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const Text('Phone: +1 555-0199', style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 12),
              const Divider(color: Colors.black38, thickness: 1),
              
              // Metadata
              _buildReceiptMetaRow('Invoice ID', sale.id.substring(0, 8).toUpperCase()),
              _buildReceiptMetaRow('Date/Time', Formatters.dateTime(sale.date)),
              _buildReceiptMetaRow('Payment Method', sale.paymentMethod),
              _buildReceiptMetaRow('Customer', customer?.name ?? 'Walk-in'),
              const Divider(color: Colors.black38, thickness: 1),
              
              // Column headers
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 3, child: Text('Item Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                  Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.right)),
                ],
              ),
              const SizedBox(height: 6),
              
              // Items List
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

              // Total block
              _buildReceiptFinancialRow('Subtotal', Formatters.currency(subtotal)),
              if (discount > 0)
                _buildReceiptFinancialRow('Discount Applied', '- ${Formatters.currency(discount)}'),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                  Text(Formatters.currency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Thank You for Shopping at VillageCO!', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.black)),
              const SizedBox(height: 8),
              // Barcode mock
              const Icon(Icons.bar_chart, size: 50, color: Colors.black54),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connecting to thermal receipt printer...')),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('New Order'),
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
