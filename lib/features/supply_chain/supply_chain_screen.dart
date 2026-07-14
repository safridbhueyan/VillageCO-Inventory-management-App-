import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pdf_generator.dart';
import '../settings/settings_controller.dart';
import 'supply_chain_controller.dart';

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
        onPressed: () => _showNewRequestDialog(context),
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
                  _OrdersList(orders: requestedOrders, isIncoming: false),
                  _OrdersList(orders: suppliedOrders, isIncoming: true),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showNewRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _NewRequestDialog(),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<SupplyChainOrder> orders;
  final bool isIncoming;

  const _OrdersList({required this.orders, required this.isIncoming});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isIncoming ? 'কোনো আগত অনুরোধ নেই' : 'কোনো প্রেরিত অনুরোধ নেই',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(order: order, isIncoming: isIncoming)
            .animate()
            .fadeIn(delay: (index * 50).ms)
            .slideY(begin: 0.05, delay: (index * 50).ms);
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final SupplyChainOrder order;
  final bool isIncoming;

  const _OrderCard({required this.order, required this.isIncoming});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending Approval':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Approved':
        return 'অনুমোদিত';
      case 'Rejected':
        return 'প্রত্যাখ্যাত';
      case 'Pending Approval':
      default:
        return 'অনুমোদনের অপেক্ষায়';
    }
  }

  Color _getPaymentStatusColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'Paid':
        return Colors.blue;
      case 'Partially Paid':
        return Colors.purple;
      case 'Unpaid':
      default:
        return Colors.red;
    }
  }

  String _getPaymentStatusText(String paymentStatus) {
    switch (paymentStatus) {
      case 'Paid':
        return 'পরিশোধিত';
      case 'Partially Paid':
        return 'আংশিক পরিশোধিত';
      case 'Unpaid':
      default:
        return 'অপরিশোধিত';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(order.status);
    final paymentStatusColor = _getPaymentStatusColor(order.paymentStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrderDetails(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'অর্ডার আইডি: #${order.id.substring(0, 6).toUpperCase()}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('বারকোড: ${order.productBarcode.isNotEmpty ? order.productBarcode : "N/A"}', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(
                          isIncoming ? 'অনুরোধ করেছে: ${order.fromStoreName}' : 'সরবরাহকারী: ${order.toStoreName}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'পরিমাণ: ${order.quantityRequested} ${order.productUnit}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (order.approvedByAdmin) ...[
                        const SizedBox(height: 2),
                        Text(
                          'গৃহীত: ${order.quantityReceived} ${order.productUnit}',
                          style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        Formatters.currency(order.totalPrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: paymentStatusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getPaymentStatusText(order.paymentStatus),
                          style: TextStyle(color: paymentStatusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'বকেয়া: ${Formatters.currency(order.paymentDue)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                        tooltip: 'ইনভয়েস ডাউনলোড',
                        onPressed: () => PdfGenerator.printSupplyChainOrder(order),
                      ),
                      if (!isIncoming && order.approvedByAdmin)
                        IconButton(
                          icon: const Icon(Icons.payment_rounded, color: Colors.blue),
                          tooltip: 'পেমেন্ট আপডেট',
                          onPressed: () => _showUpdatePaymentDialog(context, ref),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('অর্ডার বিবরণী', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('অর্ডার আইডি', order.id),
              _detailRow('তারিখ', Formatters.dateTime(order.createdAt)),
              _detailRow('স্ট্যাটাস', _getStatusText(order.status)),
              _detailRow('অনুরোধকারী', order.fromStoreName),
              _detailRow('সরবরাহকারী', order.toStoreName),
              const Divider(height: 20),
              _detailRow('পণ্য', order.productName),
              _detailRow('বারকোড', order.productBarcode.isNotEmpty ? order.productBarcode : 'N/A'),
              _detailRow('একক মূল্য', Formatters.currency(order.productSellingPrice)),
              _detailRow('অনুরোধকৃত পরিমাণ', '${order.quantityRequested} ${order.productUnit}'),
              if (order.approvedByAdmin) ...[
                _detailRow('প্রেরিত পরিমাণ', '${order.quantitySent} ${order.productUnit}'),
                _detailRow('গৃহীত পরিমাণ', '${order.quantityReceived} ${order.productUnit}'),
              ],
              const Divider(height: 20),
              _detailRow('মোট মূল্য', Formatters.currency(order.totalPrice)),
              _detailRow('পরিশোধিত', Formatters.currency(order.amountPaid)),
              _detailRow('বকেয়া', Formatters.currency(order.paymentDue), isBold: true),
              _detailRow('পেমেন্ট অবস্থা', _getPaymentStatusText(order.paymentStatus)),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text('ইনভয়েস প্রিন্ট'),
            onPressed: () {
              Navigator.pop(context);
              PdfGenerator.printSupplyChainOrder(order);
            },
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdatePaymentDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: order.amountPaid.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('পেমেন্ট আপডেট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('মোট মূল্য: ${Formatters.currency(order.totalPrice)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'পরিশোধিত পরিমাণ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'পরিমাণ লিখুন';
                  final amount = double.tryParse(val);
                  if (amount == null) return 'সঠিক সংখ্যা দিন';
                  if (amount < 0) return 'পরিমাণ ০ এর কম হতে পারবে না';
                  if (amount > order.totalPrice) return 'পরিমাণ মোট মূল্যের বেশি হতে পারবে না';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final amount = double.parse(controller.text);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                try {
                  await ref.read(supplyChainServiceProvider).updatePayment(order.id, amount);
                  if (context.mounted) {
                    Navigator.pop(context); // dismiss loading
                    Navigator.pop(context); // dismiss update dialog
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('পেমেন্ট আপডেট ব্যর্থ: $e')));
                  }
                }
              }
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }
}

class _NewRequestDialog extends ConsumerStatefulWidget {
  const _NewRequestDialog();

  @override
  ConsumerState<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends ConsumerState<_NewRequestDialog> {
  String _selectedBranchDocId = '';
  String _selectedBranchName = '';
  Map<String, dynamic>? _selectedProduct;
  final _qtyController = TextEditingController();
  final _searchController = TextEditingController();
  String _productSearchQuery = '';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _qtyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(otherBranchesProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('নতুন অনুরোধ পাঠান', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              branchesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('ব্রাঞ্চ লোডিং ত্রুটি: $e'),
                data: (branches) {
                  if (branches.isEmpty) {
                    return const Text('অনুরোধ করার মতো অন্য কোনো ব্রাঞ্চ পাওয়া যায়নি।');
                  }
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'সরবরাহকারী ব্রাঞ্চ নির্বাচন করুন',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedBranchDocId.isEmpty ? null : _selectedBranchDocId,
                    items: branches.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['storeDocId'],
                        child: Text(b['shopName']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final selected = branches.firstWhere((b) => b['storeDocId'] == val);
                        setState(() {
                          _selectedBranchDocId = val;
                          _selectedBranchName = selected['shopName'];
                          _selectedProduct = null;
                        });
                      }
                    },
                  );
                },
              ),
              if (_selectedBranchDocId.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('পণ্য নির্বাচন করুন:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'পণ্য খুঁজুন...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _productSearchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final productsAsync = ref.watch(branchProductsProvider(_selectedBranchDocId));
                      return productsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Text('পণ্য লোড করতে ব্যর্থ: $e'),
                        data: (products) {
                          final filtered = products.where((p) {
                            final name = p['name'].toString().toLowerCase();
                            final barcode = p['barcode'].toString().toLowerCase();
                            return name.contains(_productSearchQuery) || barcode.contains(_productSearchQuery);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('কোনো পণ্য পাওয়া যায়নি'));
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              final isSelected = _selectedProduct?['id'] == p['id'];
                              return ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                selected: isSelected,
                                selectedTileColor: theme.colorScheme.primary.withOpacity(0.08),
                                title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('স্টক: ${p['currentStock']} ${p['unit']} | মূল্য: ${Formatters.currency(p['sellingPrice'])}'),
                                trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedProduct = p;
                                  });
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
              if (_selectedProduct != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: InputDecoration(
                      labelText: 'অনুরোধকৃত পরিমাণ (${_selectedProduct!['unit']})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'পরিমাণ দিন';
                      final qty = double.tryParse(val);
                      if (qty == null) return 'সঠিক সংখ্যা দিন';
                      if (qty <= 0) return 'পরিমাণ ০ থেকে বেশি হতে হবে';
                      final available = (_selectedProduct!['currentStock'] as num).toDouble();
                      if (qty > available) {
                        return 'দুঃখিত, ওই ব্রাঞ্চে মাত্র $available ${_selectedProduct!['unit']} আছে';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: _selectedProduct == null
              ? null
              : () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    final qty = double.parse(_qtyController.text);
                    final settingsAsync = ref.read(settingsControllerProvider).valueOrNull;
                    final currentBranchInfoAsync = ref.read(currentBranchInfoProvider).valueOrNull;

                    if (settingsAsync == null || currentBranchInfoAsync == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ত্রুটি: লোকাল ব্রাঞ্চ কনফিগারেশন পাওয়া যায়নি।')),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      await ref.read(supplyChainServiceProvider).createRequest(
                            currentBranchInfo: currentBranchInfoAsync,
                            currentBranchName: settingsAsync.shopName,
                            targetBranchDocId: _selectedBranchDocId,
                            targetBranchName: _selectedBranchName,
                            productData: _selectedProduct!,
                            quantityRequested: qty,
                          );
                      if (context.mounted) {
                        Navigator.pop(context); // dismiss loading
                        Navigator.pop(context); // dismiss dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('অর্ডার অনুরোধ সফলভাবে পাঠানো হয়েছে')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('অনুরোধ ব্যর্থ হয়েছে: $e')),
                        );
                      }
                    }
                  }
                },
          child: const Text('অনুরোধ করুন'),
        ),
      ],
    );
  }
}
