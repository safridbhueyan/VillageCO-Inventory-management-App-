import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'quick_action_card.dart';

class QuickActionsPanel extends StatelessWidget {
  const QuickActionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'দ্রুত অ্যাক্সেস',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              QuickActionCard(
                label: 'নতুন বিক্রি',
                icon: Icons.point_of_sale_rounded,
                color: theme.colorScheme.primary,
                onTap: () => context.go('/pos'),
              ),
              const SizedBox(width: 14),
              QuickActionCard(
                label: 'পণ্য যোগ',
                icon: Icons.add_circle_outline_rounded,
                color: Colors.blue,
                onTap: () => context.go('/products'),
              ),
              const SizedBox(width: 14),
              QuickActionCard(
                label: 'স্টক আপডেট',
                icon: Icons.call_received_rounded,
                color: Colors.teal,
                onTap: () => context.go('/inventory'),
              ),
              const SizedBox(width: 14),
              QuickActionCard(
                label: 'লাভ-ক্ষতি রিপোর্ট',
                icon: Icons.bar_chart_rounded,
                color: Colors.purple,
                onTap: () => context.go('/reports'),
              ),
              const SizedBox(width: 14),
              QuickActionCard(
                label: 'সাপ্লায়ার রেজিস্ট্রি',
                icon: Icons.local_shipping_rounded,
                color: Colors.orange,
                onTap: () => context.go('/suppliers'),
              ),
              const SizedBox(width: 14),
              QuickActionCard(
                label: 'সাপ্লাই চেইন',
                icon: Icons.hub_rounded,
                color: Colors.indigo,
                onTap: () => context.go('/supply_chain'),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }
}
