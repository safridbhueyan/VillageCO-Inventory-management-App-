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
        Row(
          children: [
            Icon(
              Icons.flash_on_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'দ্রুত অ্যাক্সেস',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              QuickActionCard(
                label: 'নতুন বিক্রি',
                icon: Icons.point_of_sale_rounded,
                color: theme.colorScheme.primary,
                onTap: () => context.go('/pos'),
                animationIndex: 0,
              ),
              const SizedBox(width: 12),
              QuickActionCard(
                label: 'পণ্য যোগ',
                icon: Icons.add_circle_outline_rounded,
                color: const Color(0xFF0284C7),
                onTap: () => context.go('/products'),
                animationIndex: 1,
              ),
              const SizedBox(width: 12),
              QuickActionCard(
                label: 'স্টক আপডেট',
                icon: Icons.call_received_rounded,
                color: const Color(0xFF0D9488),
                onTap: () => context.go('/inventory'),
                animationIndex: 2,
              ),
              const SizedBox(width: 12),
              QuickActionCard(
                label: 'লাভ-ক্ষতি রিপোর্ট',
                icon: Icons.bar_chart_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => context.go('/reports'),
                animationIndex: 3,
              ),
              const SizedBox(width: 12),
              QuickActionCard(
                label: 'সাপ্লায়ার রেজিস্ট্রি',
                icon: Icons.local_shipping_rounded,
                color: const Color(0xFFD97706),
                onTap: () => context.go('/suppliers'),
                animationIndex: 4,
              ),
              const SizedBox(width: 12),
              QuickActionCard(
                label: 'সাপ্লাই চেইন',
                icon: Icons.hub_rounded,
                color: const Color(0xFF4F46E5),
                onTap: () => context.go('/supply_chain'),
                animationIndex: 5,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms, duration: 350.ms);
  }
}
