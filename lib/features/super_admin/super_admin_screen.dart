import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'admin_controller.dart';
import 'widgets/shop_card.dart';
import 'widgets/shop_form_dialog.dart';
import 'widgets/admin_supply_chain_tab.dart';

final superAdminSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final superAdminDialogCurrencyProvider = StateProvider.autoDispose<String>((ref) => 'BDT');

final superAdminShopsStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return adminRepo.getShopsStream();
});

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shopsAsync = ref.watch(superAdminShopsStreamProvider);
    final searchQuery = ref.watch(superAdminSearchQueryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('সুপার অ্যাডমিন ড্যাশবোর্ড', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'লগআউট',
              onPressed: () => context.go('/login'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.store_rounded), text: 'শপসমূহ'),
              Tab(icon: Icon(Icons.hub_rounded), text: 'সাপ্লাই চেইন অনুরোধ'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const ShopFormDialog(),
            );
          },
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('নতুন শপ তৈরি করুন'),
        ),
        body: TabBarView(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [theme.colorScheme.primary.withOpacity(0.04), theme.colorScheme.background],
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'দোকান খুঁজুন...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(superAdminSearchQueryProvider.notifier).state = '';
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                            ),
                            onChanged: (val) {
                              ref.read(superAdminSearchQueryProvider.notifier).state = val.trim().toLowerCase();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: shopsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(superAdminShopsStreamProvider);
                          try {
                            await ref.read(superAdminShopsStreamProvider.future);
                          } catch (_) {}
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: Center(child: Text('ত্রুটি: $error')))],
                        ),
                      ),
                      data: (snapshot) {
                        final docs = snapshot.docs;
                        final filteredDocs = docs.where((doc) {
                          final name = (doc.data()['shopName'] ?? '').toString().toLowerCase();
                          final id = doc.id.toLowerCase();
                          final shopID = (doc.data()['shopID'] ?? '').toString().toLowerCase();
                          return name.contains(searchQuery) || id.contains(searchQuery) || shopID.contains(searchQuery);
                        }).toList();

                        if (filteredDocs.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(superAdminShopsStreamProvider);
                              try {
                                await ref.read(superAdminShopsStreamProvider.future);
                              } catch (_) {}
                            },
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.store_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                                        const SizedBox(height: 16),
                                        Text('কোনো দোকান পাওয়া যায়নি।', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(superAdminShopsStreamProvider);
                            try {
                              await ref.read(superAdminShopsStreamProvider.future);
                            } catch (_) {}
                          },
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              mainAxisSpacing: 18,
                              crossAxisSpacing: 18,
                              childAspectRatio: 1.25,
                            ),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data();
                              final shopName = data['shopName'] ?? 'Unnamed Shop';
                              final storeDocId = doc.id;
                              final pin = data['adminPin'] ?? '';
                              final currency = data['currency'] ?? 'BDT';
                              final taxRate = (data['taxRate'] as num?)?.toDouble() ?? 0.0;

                              return ShopCard(
                                storeDocId: storeDocId,
                                shopName: shopName,
                                pin: pin,
                                currency: currency,
                                taxRate: taxRate,
                                docRef: doc.reference,
                              ).animate().fadeIn(delay: (50 * index).ms).scale(delay: (50 * index).ms);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const AdminSupplyChainTab(),
          ],
        ),
      ),
    );
  }
}
