import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/utils/formatters.dart';
import '../../features/settings/settings_controller.dart';
import 'admin_controller.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'সুপার অ্যাডমিন ড্যাশবোর্ড',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'লগআউট',
            onPressed: () {
              context.go('/login');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showShopFormDialog(context),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('নতুন শপ তৈরি করুন'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.04),
              theme.colorScheme.background,
            ],
          ),
        ),
        child: Column(
          children: [
            // Search Bar & Stats Header
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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

            // Shops List
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
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Text('ত্রুটি: $error'),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (snapshot) {
                  final docs = snapshot.docs;
                  final filteredDocs = docs.where((doc) {
                    final name = (doc.data()['shopName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final id = doc.id.toLowerCase();
                    final shopID = (doc.data()['shopID'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(searchQuery) ||
                        id.contains(searchQuery) ||
                        shopID.contains(searchQuery);
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
                                  Icon(
                                    Icons.store_outlined,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'কোনো দোকান পাওয়া যায়নি।',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
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
                        final taxRate =
                            (data['taxRate'] as num?)?.toDouble() ?? 0.0;

                        return _ShopCard(
                              storeDocId: storeDocId,
                              shopName: shopName,
                              pin: pin,
                              currency: currency,
                              taxRate: taxRate,
                              docRef: doc.reference,
                            )
                            .animate()
                            .fadeIn(delay: (50 * index).ms)
                            .scale(delay: (50 * index).ms);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShopFormDialog(
    BuildContext context, {
    String? storeDocId,
    String? currentName,
    String? currentPin,
    String? currentCurrency,
    double? currentTax,
  }) {
    final nameController = TextEditingController(text: currentName);
    final pinController = TextEditingController(text: currentPin);
    final taxController = TextEditingController(
      text: currentTax?.toString() ?? '0.0',
    );
    ref.read(superAdminDialogCurrencyProvider.notifier).state = currentCurrency ?? 'BDT';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            storeDocId == null ? 'নতুন শপ তৈরি করুন' : 'শপ এডিট করুন',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'দোকানের নাম',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'নাম খালি হতে পারে না'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pinController,
                    decoration: const InputDecoration(
                      labelText: 'অ্যাডমিন পিন (৪ সংখ্যা)',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null ||
                            v.trim().length != 4 ||
                            int.tryParse(v) == null
                        ? 'সঠিক ৪ সংখ্যার পিন দিন'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: ref.watch(superAdminDialogCurrencyProvider),
                    decoration: const InputDecoration(
                      labelText: 'কারেন্সি',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BDT', child: Text('BDT (৳)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                    ],
                    onChanged: (val) {
                      if (val != null) ref.read(superAdminDialogCurrencyProvider.notifier).state = val;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: taxController,
                    decoration: const InputDecoration(
                      labelText: 'ভ্যাট হার (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || double.tryParse(v) == null
                        ? 'সঠিক সংখ্যা লিখুন'
                        : null,
                  ),
                ],
              ),
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
                  final pin = pinController.text.trim();
                  final tax = double.parse(taxController.text);

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final adminRepo = ref.read(adminRepositoryProvider);
                    if (storeDocId == null) {
                      await adminRepo.createShop(
                        name: name,
                        pin: pin,
                        currency: ref.read(superAdminDialogCurrencyProvider),
                        taxRate: tax,
                      );
                    } else {
                      await adminRepo.editShop(
                        storeDocId: storeDocId,
                        newName: name,
                        newPin: pin,
                        currency: ref.read(superAdminDialogCurrencyProvider),
                        taxRate: tax,
                      );
                    }
                    if (context.mounted) {
                      Navigator.pop(context); // loading
                      Navigator.pop(context); // dialog
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
                    }
                  }
                }
              },
              child: const Text('সংরক্ষণ করুন'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends ConsumerWidget {
  final String storeDocId;
  final String shopName;
  final String pin;
  final String currency;
  final double taxRate;
  final DocumentReference<Map<String, dynamic>> docRef;

  const _ShopCard({
    required this.storeDocId,
    required this.shopName,
    required this.pin,
    required this.currency,
    required this.taxRate,
    required this.docRef,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: $storeDocId',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditDialog(context, ref);
                    } else if (val == 'delete') {
                      _showDeleteConfirmation(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('সম্পাদনা করুন'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'মুছে ফেলুন',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),

            // Shop Stats Row (Products Count, Sales Count)
            Expanded(
              child: FutureBuilder<List<int>>(
                future: Future.wait([
                  docRef
                      .collection('products')
                      .count()
                      .get()
                      .then((v) => v.count ?? 0),
                  docRef
                      .collection('sales')
                      .count()
                      .get()
                      .then((v) => v.count ?? 0),
                ]),
                builder: (context, snapshot) {
                  final int productCount = snapshot.data?[0] ?? 0;
                  final int salesCount = snapshot.data?[1] ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(
                        theme,
                        Icons.shopping_bag_outlined,
                        '$productCount টি',
                        'মোট পণ্য',
                      ),
                      _buildMiniStat(
                        theme,
                        Icons.receipt_long_outlined,
                        '$salesCount টি',
                        'মোট লেনদেন',
                      ),
                      _buildMiniStat(
                        theme,
                        Icons.vpn_key_outlined,
                        pin,
                        'পিন কোড',
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.bar_chart_rounded, size: 16),
                    label: const Text(
                      'রিপোর্ট',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () => _showStatsBottomSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                    label: const Text(
                      'ম্যানেজ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () => _manageShop(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final state = context.findAncestorStateOfType<_SuperAdminScreenState>();
    state?._showShopFormDialog(
      context,
      storeDocId: storeDocId,
      currentName: shopName,
      currentPin: pin,
      currentCurrency: currency,
      currentTax: taxRate,
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'শপ মুছে ফেলবেন?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'আপনি কি নিশ্চিত যে "$shopName" শপটি মুছে ফেলতে চান? এর ফলে শপের সমস্ত পণ্য ও বেচা-বিক্রির রিপোর্ট চিরতরে মুছে যাবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                await ref.read(adminRepositoryProvider).deleteShop(storeDocId);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('মুছে ফেলতে সমস্যা হয়েছে: $e')),
                  );
                }
              }
            },
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
  }

  void _manageShop(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'শপের ডেটা সিঙ্ক ও লোড হচ্ছে...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final originalSettings = ref.read(settingsControllerProvider).valueOrNull;
      final originalShopName =
          originalSettings?.shopName ?? 'VillageCO Inventory';
      final originalPin = originalSettings?.adminPin ?? '1234';

      // Pull database data from firestore
      await ref.read(adminRepositoryProvider).pullShopData(storeDocId);

      // Start Impersonation
      ref
          .read(adminImpersonationProvider.notifier)
          .startImpersonation(
            shopDocId: storeDocId,
            shopName: shopName,
            originalShopName: originalShopName,
            originalAdminPin: originalPin,
          );

      if (context.mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // dismiss loading dialog
        context.go('/dashboard');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('শপ লোড করতে ত্রুটি: $e')));
      }
    }
  }

  void _showStatsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = currency == 'BDT'
        ? '৳'
        : (currency == 'USD' ? '\$' : '€');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: docRef.collection('sales').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final salesDocs = snapshot.data?.docs ?? [];
          double totalSalesVal = 0.0;
          double todaySalesVal = 0.0;
          double monthlySalesVal = 0.0;

          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final monthStart = DateTime(now.year, now.month, 1);

          for (var doc in salesDocs) {
            final data = doc.data();
            final total = (data['total'] as num?)?.toDouble() ?? 0.0;
            totalSalesVal += total;

            DateTime saleDate = DateTime.now();
            if (data['date'] != null) {
              if (data['date'] is Timestamp) {
                saleDate = (data['date'] as Timestamp).toDate();
              } else if (data['date'] is String) {
                saleDate = DateTime.tryParse(data['date']) ?? DateTime.now();
              }
            }

            if (saleDate.isAfter(todayStart)) {
              todaySalesVal += total;
            }
            if (saleDate.isAfter(monthStart)) {
              monthlySalesVal += total;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$shopName - বেচা-বিক্রি রিপোর্ট',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildReportRow(
                  context,
                  'আজকের মোট বিক্রি:',
                  Formatters.currency(todaySalesVal, symbol: currencySymbol),
                ),
                const SizedBox(height: 12),
                _buildReportRow(
                  context,
                  'চলতি মাসের বিক্রি:',
                  Formatters.currency(monthlySalesVal, symbol: currencySymbol),
                ),
                const SizedBox(height: 12),
                _buildReportRow(
                  context,
                  'সর্বমোট বিক্রি:',
                  Formatters.currency(totalSalesVal, symbol: currencySymbol),
                ),
                const SizedBox(height: 12),
                _buildReportRow(
                  context,
                  'মোট মেমো সংখ্যা:',
                  '${salesDocs.length} টি',
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
