import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/database/firebase_sync_service.dart';
import '../settings/settings_controller.dart';
import '../super_admin/admin_controller.dart';
import 'widgets/sidebar.dart';
import 'widgets/bottom_nav_bar.dart';

class HomeScreen extends ConsumerWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  String _getCurrentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '/dashboard';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;
    final impersonationState = ref.watch(adminImpersonationProvider);

    Widget mainBody = isDesktop
        ? Row(
            children: [
              const Sidebar(),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: ClipRect(
                  child: child
                      .animate(key: ValueKey(child.hashCode))
                      .fadeIn(duration: 250.ms)
                      .slideX(
                        begin: 0.05,
                        end: 0,
                        duration: 250.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ),
              ),
            ],
          )
        : ClipRect(
            child: child
                .animate(key: ValueKey(child.hashCode))
                .fadeIn(duration: 200.ms)
                .slideY(
                  begin: 0.02,
                  end: 0,
                  duration: 200.ms,
                  curve: Curves.easeOutCubic,
                ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text(
                      'প্যানেলে ফিরুন',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      try {
                        final settings = ref
                            .read(settingsControllerProvider)
                            .valueOrNull;
                        if (settings != null) {
                          await ref
                              .read(firebaseSyncServiceProvider)
                              .syncAllData(settings);
                        }
                      } catch (syncError) {
                        debugPrint(
                          'Firebase Sync failed during exit: $syncError',
                        );
                      }

                      try {
                        await ref
                            .read(adminRepositoryProvider)
                            .clearLocalDatabase();
                        ref
                            .read(adminImpersonationProvider.notifier)
                            .stopImpersonation();

                        if (context.mounted) {
                          Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pop(); // dismiss loading dialog
                          context.go('/super_admin');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
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
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavBar(currentLocation: _getCurrentPath(context)),
    );
  }
}
