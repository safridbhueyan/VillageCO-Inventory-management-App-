import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/widgets/product_image_widget.dart';
import '../../../core/utils/formatters.dart';
import '../products_controller.dart';

class ProductSlidableTile extends ConsumerWidget {
  final ProductWithDetails item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductSlidableTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
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

    return Slidable(
      key: ValueKey(product.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'সংশোধন',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'মুছুন',
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isSelected ? 4 : 0,
        color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ListTile(
          onLongPress: onLongPress,
          onTap: onTap,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ProductImageWidget(
              imagePath: product.imagePath,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              borderRadius: 10,
              placeholder: Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${product.brand ?? "ব্র্যান্ড ছাড়া"} • ${Formatters.currency(product.sellingPrice)}'),
              if (isExpired)
                const Text(
                  'মেয়াদোত্তীর্ণ!',
                  style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                )
              else if (isExpiringSoon)
                const Text(
                  'মেয়াদ শেষ হচ্ছে শীঘ্রই!',
                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOut
                      ? Colors.red.withOpacity(0.1)
                      : (isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${Formatters.number(product.currentStock)} ${product.unit}',
                  style: TextStyle(
                    color: isOut ? Colors.red : (isLow ? Colors.orange : Colors.green),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                product.isFavorite ? Icons.star : Icons.star_border,
                color: product.isFavorite ? Colors.orange : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
