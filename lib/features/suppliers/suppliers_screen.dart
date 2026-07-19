import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/permission_utils.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/dialog_utils.dart';
import '../settings/settings_controller.dart';
import 'suppliers_controller.dart';
import 'widgets/supplier_form_dialog.dart';
import 'widgets/supplier_details_sheet.dart';

final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersControllerProvider);
    final balancesAsync = ref.watch(supplierBalancesProvider);
    final theme = Theme.of(context);
    final searchQuery = ref.watch(_searchQueryProvider);

    final filtered = suppliersAsync.maybeWhen(
      data: (l) => searchQuery.isEmpty ? l : l.where((s) => s.name.toLowerCase().contains(searchQuery.toLowerCase()) || s.phone.contains(searchQuery)).toList(),
      orElse: () => <Supplier>[],
    );

    final balances = balancesAsync.valueOrNull ?? {};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Suppliers Registry', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'রিপোর্ট পিডিএফ ডাউনলোড',
              onPressed: () => _generatePDFReport(context),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'সব সরবরাহকারী'),
              Tab(icon: Icon(Icons.hourglass_bottom_rounded), text: 'বকেয়া/বাকি'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search suppliers by name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) => ref.read(_searchQueryProvider.notifier).state = val,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSupplierListView(filtered, balances, false, theme),
                  _buildSupplierListView(filtered, balances, true, theme),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showDialog(context: context, builder: (context) => const SupplierFormDialog()),
          icon: const Icon(Icons.add),
          label: const Text('Add Supplier'),
        ),
      ),
    );
  }

  Widget _buildSupplierListView(
    List<Supplier> suppliers,
    Map<String, double> balances,
    bool showOnlyOutstanding,
    ThemeData theme,
  ) {
    final list = showOnlyOutstanding
        ? suppliers.where((s) => (balances[s.id] ?? 0.0) > 0.0).toList()
        : suppliers;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showOnlyOutstanding ? Icons.done_all_rounded : Icons.local_shipping_outlined,
                size: 72,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                showOnlyOutstanding ? 'কোনো বকেয়া বাকি নেই' : 'No Suppliers Registered',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                showOnlyOutstanding
                    ? 'সব সরবরাহকারীর সাথে লেনদেনের হিসাব সম্পূর্ণ পরিশোধিত।'
                    : 'Register your suppliers to log inventory restocks.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final sup = list[index];
        final due = balances[sup.id] ?? 0.0;

        return ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
            backgroundImage: sup.imagePath != null
                ? (sup.imagePath!.startsWith('http')
                    ? NetworkImage(sup.imagePath!) as ImageProvider
                    : FileImage(File(sup.imagePath!)))
                : null,
            child: sup.imagePath == null
                ? Icon(Icons.local_shipping, color: theme.colorScheme.primary)
                : null,
          ),
          title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone: ${sup.phone}${sup.email != null ? ' • ${sup.email}' : ''}'),
              if (due > 0.0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'বকেয়া: ${Formatters.currency(due)}',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => SupplierDetailsSheet(supplier: sup),
            );
          },
        );
      },
    );
  }

  void _generatePDFReport(BuildContext context) async {
    final hasPermission = await PermissionUtils.requestStoragePermission(context);
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('স্টোরেজ পারমিশন প্রয়োজন!')));
      }
      return;
    }
    if (!context.mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final db = ref.read(databaseProvider);
      final suppliers = await db.select(db.suppliers).get();
      if (suppliers.isEmpty) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('রিপোর্ট তৈরি করার জন্য কোনো সরবরাহকারী নেই।')));
        }
        return;
      }
      final allProducts = await db.select(db.products).get();
      final allOrders = await db.select(db.supplierOrders).get();
      final allDamages = await db.select(db.damagedItems).get();

      final Map<String, List<Product>> productsMap = {};
      final Map<String, List<SupplierOrder>> ordersMap = {};
      final Map<String, List<DamagedItem>> damagesMap = {};

      for (var s in suppliers) {
        productsMap[s.id] = allProducts.where((p) => p.supplierId == s.id && !p.isArchived).toList();
        ordersMap[s.id] = allOrders.where((o) => o.supplierId == s.id).toList();
        damagesMap[s.id] = allDamages.where((d) => d.supplierId == s.id).toList();
      }

      final pdfSavePath = ref.read(settingsControllerProvider).valueOrNull?.pdfSavePath;
      final savedPath = await PdfGenerator.generateAndSaveSuppliersReport(
        suppliers: suppliers, productsMap: productsMap, ordersMap: ordersMap, damagesMap: damagesMap, customSavePath: pdfSavePath,
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (savedPath != null && context.mounted) {
        DialogUtils.showSaveSuccessDialog(context, savedPath);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('রিপোর্ট তৈরিতে ত্রুটি: $e')));
      }
    }
  }
}
