import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../supply_chain/supply_chain_controller.dart';
import 'transfer_action_panel.dart';

class AdminOrderApprovalCard extends StatelessWidget {
  final SupplyChainOrder order;

  const AdminOrderApprovalCard({super.key, required this.order});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      case 'Pending Approval':
      default: return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Approved': return 'অনুমোদিত';
      case 'Rejected': return 'প্রত্যাখ্যাত';
      case 'Pending Approval':
      default: return 'অনুমোদনের অপেক্ষায়';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(order.status);
    final isPending = order.status == 'Pending Approval';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'অনুরোধ আইডি: #${order.id.substring(0, 8).toUpperCase()}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_getStatusText(order.status), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('অনুরোধকারী শাখা', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(order.fromStoreName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('সরবরাহকারী শাখা', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(order.toStoreName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.productName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('বারকোড: ${order.productBarcode.isNotEmpty ? order.productBarcode : "N/A"}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('একক মূল্য', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(Formatters.currency(order.productSellingPrice), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('অনুরোধকৃত পরিমাণ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text('${order.quantityRequested} ${order.productUnit}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ],
                      ),
                    ],
                  ),
                  if (!isPending) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('প্রেরিত পরিমাণ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text('${order.quantitySent} ${order.productUnit}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('গৃহীত পরিমাণ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text('${order.quantityReceived} ${order.productUnit}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('মোট মূল্য', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(Formatters.currency(order.totalPrice), style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('পরিশোধিত / বকেয়া', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(Formatters.currency(order.amountPaid), style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                                const Text(' / ', style: TextStyle(fontSize: 13)),
                                Text(
                                  Formatters.currency(order.paymentDue),
                                  style: TextStyle(color: order.paymentDue > 0 ? Colors.red.shade700 : theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isPending)
              TransferActionPanel(order: order)
            else ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                    label: const Text('ইনভয়েস প্রিন্ট', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => PdfGenerator.printSupplyChainOrder(order),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
