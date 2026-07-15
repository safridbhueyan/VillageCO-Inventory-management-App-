import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../pos_controller.dart';

class PosCartItemsList extends ConsumerWidget {
  final PosCartState cart;

  const PosCartItemsList({
    super.key,
    required this.cart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('কার্ট খালি রয়েছে', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            item.product.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(Formatters.currency(item.customPrice)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  ref.read(posCartProvider.notifier).updateQuantity(
                        item.product.id,
                        item.quantity - 1,
                      );
                },
              ),
              Text(
                Formatters.number(item.quantity),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: item.quantity >= item.product.currentStock ? Colors.grey : null,
                ),
                onPressed: item.quantity >= item.product.currentStock
                    ? null
                    : () {
                        ref.read(posCartProvider.notifier).updateQuantity(
                              item.product.id,
                              item.quantity + 1,
                            );
                      },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  ref.read(posCartProvider.notifier).removeItem(item.product.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
