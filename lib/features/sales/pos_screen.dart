import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/permission_utils.dart';
import '../products/products_controller.dart';
import '../categories/categories_controller.dart';
import '../reports/reports_controller.dart';
import '../settings/settings_controller.dart';
import 'pos_controller.dart';
import '../../core/database/firebase_sync_service.dart';
import '../../core/widgets/product_image_widget.dart';

final posCustomersListProvider = FutureProvider<List<Customer>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.customers).get();
});

final posCategoryFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final posProductSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final posPaidAmountProvider = StateProvider.autoDispose<double>((ref) => 0.0);

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    final cart = ref.watch(posCartProvider);
    final productsAsync = ref.watch(allActiveProductsProvider);
    final categoriesAsync = ref.watch(categoriesControllerProvider);
    final customersAsync = ref.watch(posCustomersListProvider);
    final posCategoryId = ref.watch(posCategoryFilterProvider);
    final productSearchQuery = ref.watch(posProductSearchQueryProvider);
    final paidAmount = ref.watch(posPaidAmountProvider);

    final filteredProducts = productsAsync.maybeWhen(
      data: (list) {
        var result = list;
        // Filter by category first
        if (posCategoryId != null) {
          result = result.where((item) => item.product.categoryId == posCategoryId).toList();
        }
        // Filter by search query
        if (productSearchQuery.isNotEmpty) {
          final q = productSearchQuery.toLowerCase();
          result = result.where((item) {
            final p = item.product;
            return p.name.toLowerCase().contains(q) ||
                (p.barcode != null && p.barcode!.contains(q)) ||
                (p.brand != null && p.brand!.toLowerCase().contains(q));
          }).toList();
        }
        return result;
      },
      orElse: () => <ProductWithDetails>[],
    );

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'বিক্রয় কেন্দ্র (POS)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
              child: _buildCatalogPanel(
                context,
                filteredProducts,
                categoriesAsync,
              ),
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
          title: const Text(
            'বিক্রয় কেন্দ্র (POS)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: [
              const Tab(
                icon: Icon(Icons.grid_view_rounded),
                text: 'পণ্য তালিকা',
              ),
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
    final posCategoryId = ref.watch(posCategoryFilterProvider);
    final productSearchQuery = ref.watch(posProductSearchQueryProvider);

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
                suffixIcon: productSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(posProductSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : const Icon(Icons.qr_code),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                ref.read(posProductSearchQueryProvider.notifier).state = val;
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
                    ref.read(posCategoryFilterProvider.notifier).state = null;
                  },
                  backgroundColor: posCategoryId == null
                      ? theme.colorScheme.primaryContainer
                      : null,
                  labelStyle: TextStyle(
                    color: posCategoryId == null
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                ...categoriesAsync.maybeWhen(
                  data: (categories) => categories.map((cat) {
                    final isSelected = posCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(cat.name),
                        onPressed: () {
                          ref.read(posCategoryFilterProvider.notifier).state = cat.id;
                        },
                        backgroundColor: isSelected
                            ? theme.colorScheme.primaryContainer
                            : null,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                  orElse: () => [],
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('ম্যাচিং কোনো পণ্য পাওয়া যায়নি।'))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
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
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withOpacity(
                              0.5,
                            ),
                          ),
                        ),
                        child: InkWell(
                          onTap: isOut
                              ? null
                              : () {
                                  ref.read(posCartProvider.notifier).addItem(p);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${p.name} কার্টে যোগ হয়েছে',
                                      ),
                                      duration: const Duration(
                                        milliseconds: 600,
                                      ),
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
                                        color: theme.colorScheme.surfaceVariant
                                            .withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ProductImageWidget(
                                        imagePath: p.imagePath,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        borderRadius: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Formatters.currency(p.sellingPrice),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOut
                                        ? 'স্টক খালি'
                                        : '${Formatters.number(p.currentStock)} ${p.unit} অবশিষ্ট',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOut ? Colors.red : Colors.grey,
                                      fontWeight: isOut
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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
    final paidAmount = ref.watch(posPaidAmountProvider);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'চলতি কার্ট',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: cart.items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'কার্ট খালি রয়েছে',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(Formatters.currency(item.customPrice)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  ref
                                      .read(posCartProvider.notifier)
                                      .updateQuantity(
                                        item.product.id,
                                        item.quantity - 1,
                                      );
                                },
                              ),
                              Text(
                                Formatters.number(item.quantity),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  ref
                                      .read(posCartProvider.notifier)
                                      .updateQuantity(
                                        item.product.id,
                                        item.quantity + 1,
                                      );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  ref
                                      .read(posCartProvider.notifier)
                                      .removeItem(item.product.id);
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
                      value:
                          (cart.selectedCustomer != null &&
                              customers.any(
                                (c) => c.id == cart.selectedCustomer!.id,
                              ))
                          ? customers.firstWhere(
                              (c) => c.id == cart.selectedCustomer!.id,
                            )
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'কাস্টমার',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 20,
                          ),
                          tooltip: 'নতুন কাস্টমার যোগ করুন',
                          onPressed: () => _showAddCustomerDialog(context, ref),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('সাধারণ কাস্টমার'),
                        ),
                        ...customers.map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        ),
                      ],
                      onChanged: (val) {
                        ref.read(posCartProvider.notifier).setCustomer(val);
                      },
                    ),
                    orElse: () => const Text('কাস্টমার তালিকা লোড হচ্ছে...'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showDiscountDialog(context, cart),
                  icon: const Icon(Icons.percent_rounded, size: 18),
                  label: Text(
                    cart.discount > 0
                        ? 'ছাড়: ৳${Formatters.number(cart.discountAmount)}'
                        : 'ডিসকাউন্ট',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Cash',
                  label: Text('ক্যাশ'),
                  icon: Icon(Icons.money),
                ),
                ButtonSegment(
                  value: 'Mobile Banking',
                  label: Text('মোবাইল'),
                  icon: Icon(Icons.phone_iphone),
                ),
                ButtonSegment(
                  value: 'Card',
                  label: Text('কার্ড'),
                  icon: Icon(Icons.credit_card),
                ),
              ],
              selected: {cart.paymentMethod},
              onSelectionChanged: (set) {
                ref.read(posCartProvider.notifier).setPaymentMethod(set.first);
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _paidAmountController,
              decoration: const InputDecoration(
                labelText: 'পরিশোধিত টাকা (Paid Amount)',
                border: OutlineInputBorder(),
                prefixText: '৳ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (val) {
                ref.read(posPaidAmountProvider.notifier).state = double.tryParse(val) ?? 0.0;
              },
            ),
            const SizedBox(height: 12),

            Column(
              children: [
                _buildCheckoutSummaryRow(
                  'উপ-মোট বিল',
                  Formatters.currency(cart.subtotal),
                ),
                if (cart.discount > 0)
                  _buildCheckoutSummaryRow(
                    'ডিসকাউন্ট ছাড়',
                    '- ${Formatters.currency(cart.discountAmount)}',
                    color: Colors.red,
                  ),
                const Divider(height: 16),
                _buildCheckoutSummaryRow(
                  'মোট পরিশোধযোগ্য বিল',
                  Formatters.currency(cart.total),
                  isBold: true,
                  fontSize: 18,
                  color: theme.colorScheme.primary,
                ),
                if (paidAmount > 0) ...[
                  const SizedBox(height: 4),
                  _buildCheckoutSummaryRow(
                    'পরিশোধিত টাকা',
                    Formatters.currency(
                      paidAmount,
                    ),
                  ),
                  _buildCheckoutSummaryRow(
                    paidAmount >=
                            cart.total
                        ? 'ফেরতযোগ্য টাকা'
                        : 'বাকি বিল',
                    Formatters.currency(
                      (paidAmount -
                              cart.total)
                          .abs(),
                    ),
                    color:
                        paidAmount >=
                            cart.total
                        ? Colors.green
                        : Colors.orange,
                    isBold: true,
                  ),
                ],
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: cart.items.isEmpty
                    ? null
                    : () async {
                        try {
                          final cartItems = List<CartItem>.from(cart.items);
                          final customer = cart.selectedCustomer;
                          final paidVal =
                              ref.read(posPaidAmountProvider);
                          final completedSale = await ref
                              .read(posCartProvider.notifier)
                              .completeSale();
                          _paidAmountController.clear();
                          ref.read(posPaidAmountProvider.notifier).state = 0.0;
                          ref.invalidate(salesHistoryProvider);
                          ref.invalidate(dashboardMetricsProvider);

                          // Trigger background sale sync & PDF upload to Firebase
                          final settings = ref.read(settingsControllerProvider).valueOrNull;
                          if (settings != null) {
                            ref.read(firebaseSyncServiceProvider).syncSaleOnComplete(
                              sale: completedSale,
                              items: cartItems,
                              paidAmount: paidVal,
                              customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                              settings: settings,
                            ).catchError((e) {
                              debugPrint('Background sale sync failed: $e');
                            });
                          }

                          if (mounted) {
                            _showInvoiceReceiptDialog(
                              context,
                              completedSale,
                              cart,
                              paidVal,
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('বিক্রি সম্পন্ন করতে ত্রুটি: $e'),
                            ),
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
      ),
    );
  }

  Widget _buildCheckoutSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
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
    final discountController = TextEditingController(
      text: cart.discount.toString(),
    );

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
            child: const Text(
              'ডিসকাউন্ট মুছুন',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(discountController.text) ?? 0.0;
              ref
                  .read(posCartProvider.notifier)
                  .applyDiscount(amt, isPercentage: false);
              Navigator.pop(context);
            },
            child: const Text('প্রয়োগ করুন'),
          ),
        ],
      ),
    );
  }

  // Invoice Receipt dialog (Bangla)
  void _showInvoiceReceiptDialog(
    BuildContext context,
    Sale sale,
    PosCartState cartStateAtCheckout,
    double paidAmount,
  ) {
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
              const Text(
                'ভিলেজকো স্টোর',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              const Text(
                'মুদি দোকান ও পিওএস কেন্দ্র',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Text(
                'মোবাইল: +৮৮০ ১৭০০০০০০০০',
                style: TextStyle(fontSize: 10, color: Colors.grey),
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
                'ক্রেতার নাম',
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
                                '${Formatters.number(item.quantity)} ${item.product.unit}',
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
                                Formatters.currency(item.subtotal),
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
                ),
              ),
              const Divider(color: Colors.black38, thickness: 1),

              _buildReceiptFinancialRow(
                'উপ-মোট বিল',
                Formatters.currency(subtotal),
              ),
              if (discount > 0)
                _buildReceiptFinancialRow(
                  'ডিসকাউন্ট ছাড়',
                  '- ${Formatters.currency(discount)}',
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
                    Formatters.currency(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              if (paidAmount > 0) ...[
                const SizedBox(height: 4),
                _buildReceiptFinancialRow(
                  'পরিশোধিত টাকা',
                  Formatters.currency(paidAmount),
                ),
                _buildReceiptFinancialRow(
                  paidAmount >= total ? 'ফেরতযোগ্য টাকা' : 'বাকি বিল',
                  Formatters.currency((paidAmount - total).abs()),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'ভিলেজকো স্টোরে কেনাকাটার জন্য ধন্যবাদ!',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.bar_chart, size: 50, color: Colors.black54),
            ],
          ),
        ),
        actions: [
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
                            '${Formatters.number(item.quantity)} ${item.product.unit}',
                        'total': Formatters.currency(item.subtotal),
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
                  subtotal: subtotal,
                  discount: discount,
                  total: total,
                  paidAmount: paidAmount,
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
                final hasPermission = await PermissionUtils.requestStoragePermission(context);
                if (!hasPermission) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ফাইলের সুরক্ষার জন্য স্টোরেজ পারমিশন প্রয়োজন!')),
                    );
                  }
                  return;
                }

                final itemsMapped = itemsList
                    .map(
                      (item) => {
                        'name': item.product.name,
                        'qty':
                            '${Formatters.number(item.quantity)} ${item.product.unit}',
                        'total': Formatters.currency(item.subtotal),
                      },
                    )
                    .toList();

                final settings = ref.read(settingsControllerProvider).valueOrNull;
                final pdfSavePath = settings?.pdfSavePath;

                final savedPath = await PdfGenerator.generateAndSaveTextReceipt(
                  saleId: sale.id,
                  dateStr: Formatters.dateTime(sale.date),
                  paymentMethod: sale.paymentMethod == 'Cash'
                      ? 'ক্যাশ'
                      : (sale.paymentMethod == 'Card'
                            ? 'কার্ড'
                            : 'মোবাইল ব্যাংকিং'),
                  customerName: customer?.name ?? 'সাধারণ কাস্টমার',
                  items: itemsMapped,
                  subtotal: subtotal,
                  discount: discount,
                  total: total,
                  paidAmount: paidAmount,
                  customSavePath: pdfSavePath,
                );

                if (savedPath != null) {
                  if (context.mounted) {
                    DialogUtils.showSaveSuccessDialog(context, savedPath);
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF ডাউনলোড ব্যর্থ: $e')),
                  );
                }
              }
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

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নতুন কাস্টমার যোগ করুন'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'কাস্টমারের নাম (Name)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'নাম লিখুন' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'মোবাইল নাম্বার (Mobile Number)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'মোবাইল নাম্বার লিখুন'
                    : null,
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
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final id = const Uuid().v4();

                final db = ref.read(databaseProvider);
                final customer = Customer(id: id, name: name, phone: phone);

                await db.into(db.customers).insert(customer);

                // Refresh list
                ref.invalidate(posCustomersListProvider);
                triggerAutoSync(ref);

                // Select the new customer
                ref.read(posCartProvider.notifier).setCustomer(customer);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name কাস্টমার হিসেবে যোগ করা হয়েছে'),
                    ),
                  );
                }
              }
            },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }
}
