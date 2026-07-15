import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../settings/settings_controller.dart';
import '../../products/products_controller.dart';
import '../suppliers_controller.dart';
import 'update_damage_dialog.dart';

class DamagesTab extends ConsumerWidget {
  final String supplierId;

  const DamagesTab({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final damagesAsync = ref.watch(supplierDamagesProvider(supplierId));
    final productsAsync = ref.watch(productsListProvider);

    return damagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error loading damages: $err')),
      data: (damages) {
        final productNames = productsAsync.maybeWhen(
          data: (list) => {for (var p in list) p.product.id: p.product.name},
          orElse: () => <String, String>{},
        );

        double totalDamagedQty = damages.fold(0.0, (sum, d) => sum + d.quantity);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricCard(
                'মোট ক্ষতিগ্রস্ত পণ্য',
                '${Formatters.number(totalDamagedQty)} items',
                Icons.broken_image_outlined,
                totalDamagedQty > 0 ? Colors.red : Colors.grey,
              ),
              const Divider(height: 32),
              
              Text('ক্ষতিগ্রস্ত পণ্যের বিবরণ (Damaged Records)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              if (damages.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('কোনো ক্ষতিগ্রস্ত পণ্য রেকর্ড করা নেই।', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: damages.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final dmg = damages[index];
                    final prodName = productNames[dmg.productId] ?? 'Unknown Product';
                    
                    Color statusColor = Colors.grey;
                    if (dmg.status == 'Replaced' || dmg.status == 'Refunded') statusColor = Colors.green;
                    if (dmg.status == 'Pending Replacement') statusColor = Colors.amber;
                    if (dmg.status == 'Pending Refund') statusColor = Colors.orange;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(prodName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('রেকর্ড তারিখ: ${Formatters.date(dmg.date)}'),
                          Text('পরিমাণ: ${Formatters.number(dmg.quantity)} units'),
                          if (dmg.notes != null && dmg.notes!.isNotEmpty)
                            Text('নোট: ${dmg.notes}'),
                          if (dmg.resolutionDate != null)
                            Text('মীমাংসা: ${Formatters.date(dmg.resolutionDate!)}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dmg.status,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                            tooltip: 'স্ট্যাটাস বদলুন',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => UpdateDamageDialog(damage: dmg, supplierId: supplierId),
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            tooltip: 'পিডিএফ ও অন্যান্য অপশন',
                            onSelected: (value) async {
                              final settings = ref.read(settingsControllerProvider).valueOrNull;
                              final pdfSavePath = settings?.pdfSavePath;
                              
                              final supplierList = ref.read(suppliersControllerProvider).valueOrNull ?? [];
                              final supplier = supplierList.cast<Supplier?>().firstWhere((s) => s?.id == supplierId, orElse: () => null);
                              
                              final productList = productsAsync.valueOrNull ?? [];
                              final product = productList.cast<ProductWithDetails?>().firstWhere((p) => p?.product.id == dmg.productId, orElse: () => null)?.product;

                              if (supplier == null || product == null) return;

                              if (value == 'download') {
                                try {
                                  final savedPath = await PdfGenerator.generateAndSaveDamagedItemPdf(
                                    damage: dmg,
                                    supplier: supplier,
                                    product: product,
                                    customSavePath: pdfSavePath,
                                  );
                                  if (savedPath != null && context.mounted) {
                                    DialogUtils.showSaveSuccessDialog(context, savedPath);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('PDF তৈরি করতে ব্যর্থ: $e')),
                                    );
                                  }
                                }
                              } else if (value == 'print') {
                                try {
                                  await PdfGenerator.printDamagedItem(
                                    damage: dmg,
                                    supplier: supplier,
                                    product: product,
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('প্রিন্ট ব্যর্থ: $e')),
                                    );
                                  }
                                }
                              } else if (value == 'view_online') {
                                if (dmg.pdfUrl != null) {
                                  await Share.share('ক্ষতিগ্রস্ত পণ্য পিডিএফ লিংক: ${dmg.pdfUrl!}', subject: 'Damaged Item PDF Link');
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'download',
                                child: Row(
                                  children: [
                                    Icon(Icons.download_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('বিবরণী ডাউনলোড করুন'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'print',
                                child: Row(
                                  children: [
                                    Icon(Icons.print_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('প্রিন্ট করুন'),
                                  ],
                                ),
                              ),
                              if (dmg.pdfUrl != null)
                                const PopupMenuItem(
                                  value: 'view_online',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('অনলাইন পিডিএফ শেয়ার'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
