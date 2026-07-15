import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/firebase_sync_service.dart';
import '../products/products_controller.dart';
import '../categories/categories_controller.dart';
import '../settings/settings_controller.dart';
import 'pos_controller.dart';
import 'widgets/pos_catalog_panel.dart';
import 'widgets/pos_checkout_panel.dart';

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

class _PosScreenState extends ConsumerState<PosScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _handleRefresh(BuildContext context) async {
    try {
      ref.invalidate(allActiveProductsProvider);
      ref.invalidate(productsListProvider);
      ref.invalidate(categoriesControllerProvider);
      ref.invalidate(posCustomersListProvider);

      final settings = ref.read(settingsControllerProvider).valueOrNull;
      if (settings != null) {
        final syncService = ref.read(firebaseSyncServiceProvider);
        await syncService.pullAndUpsertCatalog(settings);
      }

      await ref.read(allActiveProductsProvider.future);
      await ref.read(categoriesControllerProvider.future);
      await ref.read(posCustomersListProvider.future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('পণ্য ও ক্যাটাগরি তালিকা রিফ্রেশ করা হয়েছে'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('রিফ্রেশ করতে সমস্যা হয়েছে: $e')),
        );
      }
    }
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

    final filteredProducts = productsAsync.maybeWhen(
      data: (list) {
        var result = list;
        if (posCategoryId != null) {
          result = result.where((item) => item.product.categoryId == posCategoryId).toList();
        }
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
          title: const Text('বিক্রয় কেন্দ্র (POS)', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'রিফ্রেশ করুন',
              onPressed: () => _handleRefresh(context),
            ),
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
              child: PosCatalogPanel(
                products: filteredProducts,
                categoriesAsync: categoriesAsync,
                searchController: _searchController,
                onRefresh: () => _handleRefresh(context),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 4,
              child: PosCheckoutPanel(
                cart: cart,
                customersAsync: customersAsync,
                paidAmountController: _paidAmountController,
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('বিক্রয় কেন্দ্র (POS)', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'রিফ্রেশ করুন',
              onPressed: () => _handleRefresh(context),
            ),
          ],
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
            PosCatalogPanel(
              products: filteredProducts,
              categoriesAsync: categoriesAsync,
              searchController: _searchController,
              onRefresh: () => _handleRefresh(context),
            ),
            PosCheckoutPanel(
              cart: cart,
              customersAsync: customersAsync,
              paidAmountController: _paidAmountController,
            ),
          ],
        ),
      );
    }
  }
}
