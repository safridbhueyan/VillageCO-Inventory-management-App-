import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../supply_chain/supply_chain_controller.dart';
import 'admin_order_approval_card.dart';

class AdminSupplyChainTab extends ConsumerWidget {
  const AdminSupplyChainTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allSupplyChainOrdersProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withOpacity(0.04),
            theme.colorScheme.background,
          ],
        ),
      ),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('অনুরোধ লোড করতে ব্যর্থ: $err')),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hub_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'কোনো সাপ্লাই চেইন অনুরোধ পাওয়া যায়নি।',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: orders.length + 1,
            itemBuilder: (context, index) {
              if (index == orders.length) {
                return const SizedBox(height: 200);
              }
              final order = orders[index];
              return AdminOrderApprovalCard(order: order)
                  .animate()
                  .fadeIn(delay: (index * 50).ms)
                  .slideY(begin: 0.05, delay: (index * 50).ms);
            },
          );
        },
      ),
    );
  }
}
