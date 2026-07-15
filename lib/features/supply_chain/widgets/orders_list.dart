import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../supply_chain_controller.dart';
import 'order_card.dart';

class OrdersList extends StatelessWidget {
  final List<SupplyChainOrder> orders;
  final bool isIncoming;

  const OrdersList({super.key, required this.orders, required this.isIncoming});

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
        return OrderCard(order: order, isIncoming: isIncoming)
            .animate()
            .fadeIn(delay: (index * 50).ms)
            .slideY(begin: 0.05, delay: (index * 50).ms);
      },
    );
  }
}
