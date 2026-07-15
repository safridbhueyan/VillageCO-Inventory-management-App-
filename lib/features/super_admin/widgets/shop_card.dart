import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../settings/settings_controller.dart';
import '../admin_controller.dart';
import 'shop_form_dialog.dart';
import 'shop_stats_sheet.dart';

class ShopCard extends ConsumerWidget {
  final String storeDocId;
  final String shopName;
  final String pin;
  final String currency;
  final double taxRate;
  final DocumentReference<Map<String, dynamic>> docRef;

  const ShopCard({
    super.key,
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
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shopName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('ID: $storeDocId', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditDialog(context);
                    } else if (val == 'delete') {
                      _showDeleteConfirmation(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('সম্পাদনা করুন')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('মুছে ফেলুন', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: FutureBuilder<List<int>>(
                future: Future.wait([
                  docRef.collection('products').count().get().then((v) => v.count ?? 0),
                  docRef.collection('sales').count().get().then((v) => v.count ?? 0),
                ]),
                builder: (context, snapshot) {
                  final int productCount = snapshot.data?[0] ?? 0;
                  final int salesCount = snapshot.data?[1] ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(theme, Icons.shopping_bag_outlined, '$productCount টি', 'মোট পণ্য'),
                      _buildMiniStat(theme, Icons.receipt_long_outlined, '$salesCount টি', 'মোট লেনদেন'),
                      _buildMiniStat(theme, Icons.vpn_key_outlined, pin, 'পিন কোড'),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.bar_chart_rounded, size: 16),
                    label: const Text('রিপোর্ট', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (context) => ShopStatsSheet(shopName: shopName, currency: currency, docRef: docRef),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                    label: const Text('ম্যানেজ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildMiniStat(ThemeData theme, IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
      ],
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ShopFormDialog(
        storeDocId: storeDocId,
        currentName: shopName,
        currentPin: pin,
        currentCurrency: currency,
        currentTax: taxRate,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('শপ মুছে ফেলবেন?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('আপনি কি নিশ্চিত যে "$shopName" শপটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              try {
                await ref.read(adminRepositoryProvider).deleteShop(storeDocId);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
              } finally {
                if (context.mounted) Navigator.pop(context);
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
      builder: (_) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('শপের ডেটা লোড হচ্ছে...')])))),
    );
    try {
      final s = ref.read(settingsControllerProvider).valueOrNull;
      await ref.read(adminRepositoryProvider).pullShopData(storeDocId);
      ref.read(adminImpersonationProvider.notifier).startImpersonation(
        shopDocId: storeDocId,
        shopName: shopName,
        originalShopName: s?.shopName ?? 'VillageCO Inventory',
        originalAdminPin: s?.adminPin ?? '1234',
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.go('/dashboard');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
  }
}
