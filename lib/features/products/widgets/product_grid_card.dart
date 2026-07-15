import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/product_image_widget.dart';
import '../../../core/utils/formatters.dart';
import '../products_controller.dart';

class ProductGridCard extends ConsumerWidget {
  final ProductWithDetails item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ProductGridCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final product = item.product;
    final isLow = product.currentStock <= product.minimumStock;
    final isOut = product.currentStock <= 0;

    final bool hasExpiry = product.expiryDate != null;
    final bool isExpired = hasExpiry && product.expiryDate!.isBefore(DateTime.now());
    final bool isExpiringSoon = hasExpiry && 
        !isExpired && 
        product.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));

    return Card(
      elevation: isSelected ? 4 : 0,
      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ProductImageWidget(
                        imagePath: product.imagePath,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        borderRadius: 14,
                        placeholder: Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: Icon(
                          product.isFavorite ? Icons.star : Icons.star_border,
                          color: product.isFavorite ? Colors.orange : Colors.grey,
                        ),
                        onPressed: () {
                          ref.read(productsRepositoryProvider).toggleFavorite(product.id, !product.isFavorite);
                        },
                      ),
                    ),
                    if (isExpired)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'মেয়াদোত্তীর্ণ',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else if (isExpiringSoon)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'মেয়াদ শেষ হচ্ছে',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                product.brand ?? 'ব্র্যান্ড ছাড়া',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.currency(product.sellingPrice),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOut
                          ? Colors.red.withOpacity(0.1)
                          : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${Formatters.number(product.currentStock)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOut ? Colors.red : (isLow ? Colors.orange : Colors.green),
                      ),
                    ),
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
