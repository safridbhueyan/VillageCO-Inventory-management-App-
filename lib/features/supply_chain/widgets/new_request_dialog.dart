import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../settings/settings_controller.dart';
import '../supply_chain_controller.dart';

class NewRequestDialog extends ConsumerStatefulWidget {
  const NewRequestDialog({super.key});

  @override
  ConsumerState<NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends ConsumerState<NewRequestDialog> {
  final _qtyController = TextEditingController();
  final _searchController = TextEditingController();
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
    final dialogState = ref.watch(newRequestControllerProvider);
    final selectedBranchDocId = dialogState.selectedBranchDocId;
    final selectedBranchName = dialogState.selectedBranchName;
    final selectedProduct = dialogState.selectedProduct;
    final productSearchQuery = dialogState.productSearchQuery;

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
                    value: selectedBranchDocId.isEmpty ? null : selectedBranchDocId,
                    items: branches.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['storeDocId'],
                        child: Text(b['shopName']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final selected = branches.firstWhere((b) => b['storeDocId'] == val);
                        ref.read(newRequestControllerProvider.notifier).selectBranch(val, selected['shopName']);
                      }
                    },
                  );
                },
              ),
              if (selectedBranchDocId.isNotEmpty) ...[
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
                    ref.read(newRequestControllerProvider.notifier).updateSearchQuery(val);
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final productsAsync = ref.watch(branchProductsProvider(selectedBranchDocId));
                      return productsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Text('পণ্য লোড করতে ব্যর্থ: $e'),
                        data: (products) {
                          final filtered = products.where((p) {
                            final name = p['name'].toString().toLowerCase();
                            final barcode = p['barcode'].toString().toLowerCase();
                            return name.contains(productSearchQuery) || barcode.contains(productSearchQuery);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('কোনো পণ্য পাওয়া যায়নি'));
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              final isSelected = selectedProduct?['id'] == p['id'];
                              return ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                selected: isSelected,
                                selectedTileColor: theme.colorScheme.primary.withOpacity(0.08),
                                title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('স্টক: ${p['currentStock']} ${p['unit']} | মূল্য: ${Formatters.currency(p['sellingPrice'])}'),
                                trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                                onTap: () {
                                  ref.read(newRequestControllerProvider.notifier).selectProduct(p);
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
              if (selectedProduct != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: InputDecoration(
                      labelText: 'অনুরোধকৃত পরিমাণ (${selectedProduct['unit']})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'পরিমাণ দিন';
                      final qty = double.tryParse(val);
                      if (qty == null) return 'সঠিক সংখ্যা দিন';
                      if (qty <= 0) return 'পরিমাণ ০ থেকে বেশি হতে হবে';
                      final available = (selectedProduct['currentStock'] as num).toDouble();
                      if (qty > available) {
                        return 'দুঃখিত, ওই ব্রাঞ্চে মাত্র $available ${selectedProduct['unit']} আছে';
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
          onPressed: selectedProduct == null
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
                            targetBranchDocId: selectedBranchDocId,
                            targetBranchName: selectedBranchName,
                            productData: selectedProduct,
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
