import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../suppliers_controller.dart';
import 'ledger_tab.dart';
import 'inventory_tab.dart';
import 'damages_tab.dart';
import 'supplier_form_dialog.dart';
import 'add_order_dialog.dart';
import 'add_damage_dialog.dart';

class SupplierDetailsSheet extends ConsumerWidget {
  final Supplier supplier;

  const SupplierDetailsSheet({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      height: MediaQuery.of(context).size.height * 0.85,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    radius: 24,
                    child: Icon(Icons.local_shipping_rounded, color: theme.colorScheme.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Phone: ${supplier.phone}${supplier.email != null ? ' | ${supplier.email!}' : ''}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        if (supplier.address != null)
                          Text('Address: ${supplier.address}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => SupplierFormDialog(supplier: supplier),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmSupplierDelete(context, ref, supplier.id, supplier.name);
                    },
                  ),
                ],
              ),
            ),
            
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.receipt_long_rounded), text: 'লেনদেন'),
                Tab(icon: Icon(Icons.inventory_2_outlined), text: 'পণ্য ও স্টক'),
                Tab(icon: Icon(Icons.broken_image_outlined), text: 'ক্ষতিগ্রস্ত'),
              ],
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  LedgerTab(supplierId: supplier.id),
                  InventoryTab(supplierId: supplier.id),
                  DamagesTab(supplierId: supplier.id),
                ],
              ),
            ),
            
            _buildActionButtons(context, supplier.id),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String supplierId) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('নতুন অর্ডার'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AddOrderDialog(supplierId: supplierId),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.broken_image_outlined),
              label: const Text('ক্ষতিগ্রস্ত পণ্য'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AddDamageDialog(supplierId: supplierId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSupplierDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier?'),
        content: Text('Are you sure you want to delete "$name"? Products supplied by this contact will have their supplier set to null.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(suppliersControllerProvider.notifier).deleteSupplier(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
