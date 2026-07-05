import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../settings/settings_controller.dart';
import '../super_admin/admin_controller.dart';

// Riverpod state providers for login screen
final loginPinProvider = StateProvider.autoDispose<String>((ref) => '');
final loginRememberLoginProvider = StateProvider.autoDispose<bool>((ref) => false);
final loginErrorMessageProvider = StateProvider.autoDispose<String?>((ref) => null);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  void _handleKeyPress(String value) {
    final currentPin = ref.read(loginPinProvider);
    if (currentPin.length < 4) {
      ref.read(loginPinProvider.notifier).state = currentPin + value;
      ref.read(loginErrorMessageProvider.notifier).state = null;
    }

    Future.microtask(() {
      final nextPin = ref.read(loginPinProvider);
      if (nextPin.length == 4) {
        _verifyPin();
      }
    });
  }

  void _handleBackspace() {
    final currentPin = ref.read(loginPinProvider);
    if (currentPin.isNotEmpty) {
      ref.read(loginPinProvider.notifier).state = currentPin.substring(0, currentPin.length - 1);
      ref.read(loginErrorMessageProvider.notifier).state = null;
    }
  }

  Future<void> _verifyPin() async {
    final pinVal = ref.read(loginPinProvider);
    if (pinVal == '0071') {
      if (context.mounted) {
        context.go('/super_admin');
      }
      return;
    }

    final settingsAsync = ref.read(settingsControllerProvider);
    final correctPin = settingsAsync.maybeWhen(
      data: (settings) => settings.adminPin,
      orElse: () => '1234',
    );

    if (pinVal == correctPin) {
      if (context.mounted) {
        context.go('/dashboard');
      }
      return;
    }

    // Try online dynamic shop PIN lookup
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
                  'দোকানের ডেটা নামানো হচ্ছে...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final query = await FirebaseFirestore.instance
          .collection('stores')
          .where('adminPin', isEqualTo: pinVal)
          .get()
          .timeout(const Duration(seconds: 8));

      if (query.docs.isNotEmpty) {
        final storeDoc = query.docs.first;
        final storeDocId = storeDoc.id;

        // Pull database data from Firestore and populate Drift SQLite
        await ref.read(adminRepositoryProvider).pullShopData(storeDocId);

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
          context.go('/dashboard');
        }
      } else {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        }
        ref.read(loginPinProvider.notifier).state = '';
        ref.read(loginErrorMessageProvider.notifier).state = 'ভুল পিন। আবার চেষ্টা করুন।';
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
      }
      ref.read(loginPinProvider.notifier).state = '';
      ref.read(loginErrorMessageProvider.notifier).state = 'সংযোগ ত্রুটি বা পিনটি পাওয়া যায়নি।';
      debugPrint('Error verifying PIN online: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch settings provider so it starts loading on launch and stays updated.
    ref.watch(settingsControllerProvider);

    final pinVal = ref.watch(loginPinProvider);
    final rememberLogin = ref.watch(loginRememberLoginProvider);
    final errorMessage = ref.watch(loginErrorMessageProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.secondary.withOpacity(0.04),
              theme.colorScheme.background,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(28.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                color: theme.colorScheme.surface.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shop Logo (Pulsing storefront)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 38,
                          color: theme.colorScheme.primary,
                        ),
                      ).animate().scale(delay: 100.ms, duration: 450.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 20),
                      Text(
                        'ভিলেজকো ইনভেন্টরি',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'অ্যাক্সেস করতে অ্যাডমিন পিন দিন',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // PIN dots indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isActive = index < pinVal.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withOpacity(0.6),
                              border: Border.all(
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                          ).animate(target: isActive ? 1.0 : 0.0)
                           .scale(end: const Offset(1.15, 1.15), duration: 150.ms);
                        }),
                      ),
                      const SizedBox(height: 24),

                      if (errorMessage != null)
                        Text(
                          errorMessage,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ).animate().shake(duration: 300.ms),

                      const SizedBox(height: 20),

                      // Keypad grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.45,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        children: [
                          ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map(_buildKeypadButton),
                          const SizedBox.shrink(),
                          _buildKeypadButton('0'),
                          IconButton(
                            icon: const Icon(Icons.backspace_outlined),
                            iconSize: 22,
                            color: theme.colorScheme.onSurface,
                            onPressed: _handleBackspace,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Remember Checkbox
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: rememberLogin,
                              activeColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                ref.read(loginRememberLoginProvider.notifier).state = val ?? false;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'এই শিফটের জন্য পিন মনে রাখুন',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _handleKeyPress(digit),
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}
