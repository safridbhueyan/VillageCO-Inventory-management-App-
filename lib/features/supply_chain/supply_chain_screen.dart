import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supply_chain_controller.dart';
import 'widgets/orders_list.dart';
import 'widgets/new_request_dialog.dart';

class SupplyChainScreen extends ConsumerStatefulWidget {
  const SupplyChainScreen({super.key});

  @override
  ConsumerState<SupplyChainScreen> createState() => _SupplyChainScreenState();
}

class _SupplyChainScreenState extends ConsumerState<SupplyChainScreen> with SingleTickerProviderStateMixin {
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
    final ordersAsync = ref.watch(supplyChainOrdersProvider);
    final currentBranchAsync = ref.watch(currentBranchInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('সাপ্লাই চেইন পরিচালনা', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'প্রেরিত অনুরোধ (Requested)'),
            Tab(text: 'আগত অনুরোধ (Supplied to us)'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const NewRequestDialog(),
          );
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('নতুন অনুরোধ'),
      ),
      body: currentBranchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('লোডিং ত্রুটি: $err')),
        data: (branchInfo) {
          final currentDocId = branchInfo['storeDocId'] ?? '';
          if (currentDocId.isEmpty) {
            return const Center(child: Text('দোকান কনফিগার করা নেই। অনুগ্রহ করে অ্যাডমিন মোড বা পিন চেক করুন।'));
          }

          return ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('অনুরোধ তালিকা লোড করতে সমস্যা: $err')),
            data: (orders) {
              final requestedOrders = orders.where((o) => o.fromStoreId == currentDocId).toList();
              final suppliedOrders = orders.where((o) => o.toStoreId == currentDocId).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  OrdersList(orders: requestedOrders, isIncoming: false),
                  OrdersList(orders: suppliedOrders, isIncoming: true),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
