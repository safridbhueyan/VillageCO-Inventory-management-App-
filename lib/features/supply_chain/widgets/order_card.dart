import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_generator.dart';
import '../supply_chain_controller.dart';
import 'order_details_dialog.dart';

class OrderCard extends ConsumerWidget {
  final SupplyChainOrder order;
  final bool isIncoming;

  const OrderCard({super.key, required this.order, required this.isIncoming});

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
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => OrderDetailsDialog(
              order: order,
              getStatusText: _getStatusText,
              getPaymentStatusText: _getPaymentStatusText,
            ),
          );
        },
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
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => UpdatePaymentDialog(order: order),
                            );
                          },
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
}
