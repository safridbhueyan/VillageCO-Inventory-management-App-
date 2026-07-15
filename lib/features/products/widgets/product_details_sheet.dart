import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/product_image_widget.dart';
import '../../../core/utils/formatters.dart';
import '../products_controller.dart';

class ProductDetailsSheet extends ConsumerWidget {
  final ProductWithDetails item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductDetailsSheet({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = item.product;

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
              
              if (p.imagePath != null && p.imagePath!.isNotEmpty && (p.imagePath!.startsWith('http') || File(p.imagePath!).existsSync())) ...[
                ProductImageWidget(
                  imagePath: p.imagePath,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  borderRadius: 16,
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(p.isFavorite ? Icons.star : Icons.star_border, color: Colors.orange),
                    onPressed: () {
                      ref.read(productsRepositoryProvider).toggleFavorite(p.id, !p.isFavorite);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              Text(
                p.brand ?? 'ব্র্যান্ড: ব্র্যান্ড ছাড়া',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
              ),
              const Divider(height: 32),
              _buildDetailRow(context, 'বারকোড', p.barcode ?? 'নেই'),
              _buildDetailRow(context, 'ক্যাটাগরি', item.category?.name ?? 'ক্যাটাগরি ছাড়া'),
              _buildDetailRow(context, 'ক্রয়মূল্য', Formatters.currency(p.buyingPrice)),
              _buildDetailRow(context, 'বিক্রয়মূল্য', Formatters.currency(p.sellingPrice)),
              _buildDetailRow(context, 'বর্তমান স্টক', '${Formatters.number(p.currentStock)} ${p.unit}'),
              _buildDetailRow(context, 'সর্বনিম্ন স্টক', '${Formatters.number(p.minimumStock)} ${p.unit}'),
              _buildDetailRow(context, 'ব্যাচ নম্বর', p.batchNumber ?? 'নেই'),
              _buildDetailRow(
                context, 
                'মেয়াদোত্তীর্ণের তারিখ', 
                p.expiryDate == null 
                    ? 'নেই' 
                    : '${Formatters.date(p.expiryDate!)}${p.expiryDate!.isBefore(DateTime.now()) ? " (মেয়াদোত্তীর্ণ!)" : (p.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30))) ? " (মেয়াদ শেষ হচ্ছে শীঘ্রই!)" : "")}',
                valueColor: p.expiryDate == null 
                    ? null 
                    : (p.expiryDate!.isBefore(DateTime.now()) ? Colors.red : (p.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30))) ? Colors.orange : null)),
              ),
              _buildDetailRow(context, 'বিবরণ', p.description ?? 'কোনো বিবরণ দেওয়া হয়নি।'),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onEdit();
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('তথ্য সংশোধন'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
