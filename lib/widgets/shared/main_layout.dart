import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                const _Sidebar(),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: ClipRect(
                    child: child.animate(key: ValueKey(child.hashCode))
                        .fadeIn(duration: 250.ms)
                        .slideX(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOutCubic),
                  ),
                ),
              ],
            )
          : ClipRect(
              child: child.animate(key: ValueKey(child.hashCode))
                  .fadeIn(duration: 200.ms)
                  .slideY(begin: 0.02, end: 0, duration: 200.ms, curve: Curves.easeOutCubic),
            ),
      bottomNavigationBar: isDesktop ? null : _BottomNavBar(currentLocation: _getCurrentPath(context)),
    );
  }

  String _getCurrentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '/dashboard';
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final currentPath = _getCurrentPath(context);
    final theme = Theme.of(context);

    return Container(
      width: 250,
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header (Bangla Brand)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ভিলেজকো',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'স্টোর ও পিওএস',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Navigation Items (Bangla Labels)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: 'ড্যাশবোর্ড',
                    path: '/dashboard',
                    currentPath: currentPath,
                  ),
                  _SidebarItem(
                    icon: Icons.shopping_bag_outlined,
                    activeIcon: Icons.shopping_bag,
                    label: 'পণ্য তালিকা',
                    path: '/products',
                    currentPath: currentPath,
                  ),
                  _SidebarItem(
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2,
                    label: 'স্টক ও ইনভেন্টরি',
                    path: '/inventory',
                    currentPath: currentPath,
                  ),
                  _SidebarItem(
                    icon: Icons.point_of_sale_outlined,
                    activeIcon: Icons.point_of_sale,
                    label: 'বিক্রয় কেন্দ্র (POS)',
                    path: '/pos',
                    currentPath: currentPath,
                  ),
                  _SidebarItem(
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart,
                    label: 'রিপোর্ট ও লাভ-ক্ষতি',
                    path: '/reports',
                    currentPath: currentPath,
                  ),
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: 'সেটিংস',
                    path: '/settings',
                    currentPath: currentPath,
                  ),
                ],
              ),
            ),
            // Footer (Bangla Info)
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      'অ্যাড',
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'অ্যাডমিনিস্ট্রেটর',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'চলতি সেশন',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_open_outlined),
                    tooltip: 'লক সেশন',
                    onPressed: () {
                      context.go('/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '/dashboard';
    }
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String currentPath;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = currentPath.startsWith(path);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: InkWell(
        onTap: () {
          if (!isActive) {
            context.go(path);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? theme.colorScheme.primary.withOpacity(0.12) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final String currentLocation;

  const _BottomNavBar({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    int getIndex() {
      if (currentLocation.startsWith('/products')) return 1;
      if (currentLocation.startsWith('/pos')) return 2;
      if (currentLocation.startsWith('/reports')) return 3;
      if (currentLocation.startsWith('/settings')) return 4;
      return 0; // dashboard
    }

    return NavigationBar(
      selectedIndex: getIndex(),
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/dashboard');
            break;
          case 1:
            context.go('/products');
            break;
          case 2:
            context.go('/pos');
            break;
          case 3:
            context.go('/reports');
            break;
          case 4:
            context.go('/settings');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'ড্যাশবোর্ড',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag),
          label: 'পণ্য',
        ),
        NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          label: 'বিক্রি',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'রিপোর্ট',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'সেটিংস',
        ),
      ],
    );
  }
}
