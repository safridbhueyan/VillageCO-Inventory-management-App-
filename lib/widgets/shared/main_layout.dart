import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/reports/reports_controller.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/dialog_utils.dart';
import '../../features/settings/settings_controller.dart';
import '../../core/database/firebase_sync_service.dart';
import '../../features/super_admin/admin_controller.dart';

Future<void> logoutAndGenerateClosingReport(BuildContext context, WidgetRef ref) async {
  final isImpersonating = ref.read(adminImpersonationProvider).isImpersonating;
  if (isImpersonating) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'ডাটাবেস ও রিপোর্ট সার্ভারে সিঙ্ক হচ্ছে...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      if (settings != null) {
        await ref.read(firebaseSyncServiceProvider).syncAllData(settings);
      }
    } catch (syncError) {
      debugPrint('Firebase Sync failed during impersonation logout: $syncError');
    }

    try {
      await ref.read(adminRepositoryProvider).clearLocalDatabase();
      ref.read(adminImpersonationProvider.notifier).stopImpersonation();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.go('/super_admin');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e')),
        );
      }
    }
    return;
  }

  // Show a loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'ডাটাবেস ও রিপোর্ট সার্ভারে সিঙ্ক হচ্ছে...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    // 1. Fetch the data
    final metrics = await ref.read(dashboardMetricsProvider.future);
    final sales = await ref.read(salesHistoryProvider.future);

    // 2. Filter sales to get only today's transactions
    final now = DateTime.now();
    final todaySalesList = sales.where((s) {
      final date = s.sale.date;
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).map((s) {
      return {
        'id': s.sale.id,
        'time': Formatters.dateTime(s.sale.date).split(" ").last,
        'customer': s.customer?.name ?? 'সাধারণ কাস্টমার',
        'payment': s.sale.paymentMethod == 'Cash'
            ? 'ক্যাশ'
            : (s.sale.paymentMethod == 'Card'
                ? 'কার্ড'
                : 'মোবাইল'),
        'amount': s.sale.total.toStringAsFixed(2),
      };
    }).toList();

    final settings = ref.read(settingsControllerProvider).valueOrNull;
    final pdfSavePath = settings?.pdfSavePath;

    // 3. Generate daily transaction PDF report and save it
    final reportPath = await PdfGenerator.generateAndSaveDailyTransactionReport(
      todaySales: metrics.todaySales,
      totalExpenses: metrics.totalExpenses,
      netProfit: metrics.netProfit,
      totalTransactionsCount: todaySalesList.length,
      todaySalesList: todaySalesList,
      customSavePath: pdfSavePath,
    );

    // 4. Sync all database data & upload report PDF to Firebase (Firestore + Storage)
    if (settings != null) {
      try {
        final syncService = ref.read(firebaseSyncServiceProvider);
        final docInfo = await syncService.getStoreDocIdAndShopID(settings.shopName);
        final storeDocId = docInfo['storeDocId']!;
        
        // Sync local SQLite tables to Cloud Firestore
        await syncService.syncAllData(settings);
        
        // Upload report PDF and save report metadata
        if (reportPath != null) {
          final pdfUrl = await syncService.uploadReportPdf(storeDocId, reportPath);
          await syncService.saveReportMetadata(
            storeDocId,
            todaySales: metrics.todaySales,
            totalExpenses: metrics.totalExpenses,
            netProfit: metrics.netProfit,
            totalTransactionsCount: todaySalesList.length,
            pdfUrl: pdfUrl,
            reportPath: reportPath,
          );
        }
      } catch (syncError) {
        debugPrint('Firebase Sync failed during logout: $syncError');
        // Let the logout continue so the user is not locked out of the offline app
      }
    }

    // Dismiss loading dialog before success dialog/redirect to prevent route lock
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (reportPath != null) {
      if (context.mounted) {
        DialogUtils.showSaveSuccessDialog(context, reportPath);
      }
    }

    // 5. Log out
    if (context.mounted) {
      context.go('/login');
    }
  } catch (e) {
    // Dismiss loading dialog if open
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
    
    debugPrint('Error generating closing report: $e');
    // If error occurs, still log out but warn user
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ক্লোজিং রিপোর্ট তৈরিতে সমস্যা হয়েছে: $e. লগআউট সম্পন্ন হচ্ছে...')),
      );
      context.go('/login');
    }
  }
}

class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;
    final impersonationState = ref.watch(adminImpersonationProvider);

    Widget mainBody = isDesktop
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
          );

    if (impersonationState.isImpersonating) {
      mainBody = Column(
        children: [
          Container(
            color: Colors.amber.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(
              bottom: false,
              top: true,
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'অ্যাডমিন মোড: "${impersonationState.currentShopName}" পরিচালনা করা হচ্ছে',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.amber.shade900,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('প্যানেলে ফিরুন', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'ডাটাবেস সিঙ্ক ও প্যানেলে ফিরে যাওয়া হচ্ছে...',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      try {
                        final settings = ref.read(settingsControllerProvider).valueOrNull;
                        if (settings != null) {
                          await ref.read(firebaseSyncServiceProvider).syncAllData(settings);
                        }
                      } catch (syncError) {
                        debugPrint('Firebase Sync failed during exit: $syncError');
                      }

                      try {
                        await ref.read(adminRepositoryProvider).clearLocalDatabase();
                        ref.read(adminImpersonationProvider.notifier).stopImpersonation();
                        
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
                          context.go('/super_admin');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ত্রুটি: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: mainBody),
        ],
      );
    }

    return Scaffold(
      body: mainBody,
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

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    icon: Icons.local_shipping_outlined,
                    activeIcon: Icons.local_shipping,
                    label: 'সরবরাহকারী রেজিস্ট্রি',
                    path: '/suppliers',
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
                    onPressed: () => logoutAndGenerateClosingReport(context, ref),
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
