import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class BottomNavBar extends StatelessWidget {
  final String currentLocation;

  const BottomNavBar({super.key, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    int getIndex() {
      if (currentLocation.startsWith('/products')) return 1;
      if (currentLocation.startsWith('/pos')) return 2;
      if (currentLocation.startsWith('/reports')) return 3;
      if (currentLocation.startsWith('/settings')) return 4;
      return 0; // dashboard
    }

    final selectedIndex = getIndex();

    final items = [
      _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'ড্যাশবোর্ড', '/dashboard'),
      _NavItem(Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'পণ্য', '/products'),
      _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'বিক্রি', '/pos'),
      _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'রিপোর্ট', '/reports'),
      _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'সেটিংস', '/settings'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == selectedIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => context.go(item.route),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            key: ValueKey(isSelected),
                            size: isSelected ? 23 : 21,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: isSelected ? 10 : 9.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            letterSpacing: 0.1,
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _NavItem(this.icon, this.selectedIcon, this.label, this.route);
}
