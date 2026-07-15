import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavBar extends StatelessWidget {
  final String currentLocation;

  const BottomNavBar({super.key, required this.currentLocation});

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
