import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/utils/formatters.dart';
import 'suppliers_controller.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersControllerProvider);
    final theme = Theme.of(context);

    // Filter suppliers in memory
    final filteredSuppliers = suppliersAsync.maybeWhen(
      data: (list) {
        if (_searchQuery.isEmpty) return list;
        final q = _searchQuery.toLowerCase();
        return list.where((s) => s.name.toLowerCase().contains(q) || s.phone.contains(q)).toList();
      },
      orElse: () => <Supplier>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers Registry', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search suppliers by name or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          
          Expanded(
            child: suppliersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
              data: (suppliers) {
                if (filteredSuppliers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text('No Suppliers Registered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          const Text('Register your suppliers to log resting inventory and keep track of purchases.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSuppliers.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final sup = filteredSuppliers[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.4),
                        child: Icon(Icons.local_shipping, color: theme.colorScheme.primary),
                      ),
                      title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Phone: ${sup.phone}${sup.email != null ? ' • ${sup.email}' : ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showSupplierDetailsSheet(context, sup),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierFormDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
      ),
    );
  }

  // Details Bottom Sheet showing supplier metadata & restocks logs
  void _showSupplierDetailsSheet(BuildContext context, Supplier supplier) {
    final theme = Theme.of(context);
    final purchasesAsync = ref.read(supplierPurchasesProvider(supplier.id));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          supplier.name,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            onPressed: () {
                              Navigator.pop(context);
                              _showSupplierFormDialog(context, supplier: supplier);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmSupplierDelete(context, supplier.id, supplier.name);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSupplierDetailRow('Phone Number', supplier.phone),
                  _buildSupplierDetailRow('Email Address', supplier.email ?? 'Not provided'),
                  _buildSupplierDetailRow('Office Address', supplier.address ?? 'Not provided'),
                  const Divider(height: 32),
                  Text('Purchase & Restock Logs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  // Nested Purchase restocks list
                  Consumer(
                    builder: (context, ref, _) {
                      final purchases = ref.watch(supplierPurchasesProvider(supplier.id));
                      return purchases.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, st) => Text('Error loading restock details: $err'),
                        data: (list) {
                          if (list.isEmpty) {
                            return const Center(child: Text('No restocks logged from this supplier.', style: TextStyle(color: Colors.grey)));
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final pur = list[index];
                              final invoiceText = pur.invoiceNo != null ? 'Invoice #${pur.invoiceNo}' : 'Direct Intake';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(invoiceText, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('Logged on: ${Formatters.date(pur.date)} • Quantity: ${Formatters.number(pur.quantity)} units'),
                                trailing: Text(Formatters.currency(pur.cost), style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSupplierDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // Delete supplier dialog
  void _confirmSupplierDelete(BuildContext context, String id, String name) {
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

  // Add/Edit supplier Form Dialog
  void _showSupplierFormDialog(BuildContext context, {Supplier? supplier}) {
    final isEdit = supplier != null;
    final nameController = TextEditingController(text: supplier?.name);
    final phoneController = TextEditingController(text: supplier?.phone);
    final emailController = TextEditingController(text: supplier?.email);
    final addressController = TextEditingController(text: supplier?.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Update Supplier Details' : 'Register Supplier Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Supplier Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Office Address', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) return;

              final notifier = ref.read(suppliersControllerProvider.notifier);
              if (isEdit) {
                notifier.updateSupplier(supplier.id, name, phone, emailController.text.trim().isEmpty ? null : emailController.text.trim(), addressController.text.trim().isEmpty ? null : addressController.text.trim());
              } else {
                notifier.addSupplier(name, phone, emailController.text.trim().isEmpty ? null : emailController.text.trim(), addressController.text.trim().isEmpty ? null : addressController.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
