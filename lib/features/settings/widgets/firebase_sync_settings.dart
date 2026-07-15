import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/firebase_sync_service.dart';
import '../../../core/utils/formatters.dart';
import '../settings_screen.dart';

class FirebaseSyncSettings extends ConsumerStatefulWidget {
  final AppSettingsTableData settings;

  const FirebaseSyncSettings({
    super.key,
    required this.settings,
  });

  @override
  ConsumerState<FirebaseSyncSettings> createState() => _FirebaseSyncSettingsState();
}

class _FirebaseSyncSettingsState extends ConsumerState<FirebaseSyncSettings> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ফায়ারবেস ক্লাউড সিঙ্ক', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ফায়ারবেস ডাটাবেস সিঙ্ক',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'আপনার অফলাইন ডাটাবেস ক্লাউডে সিঙ্ক করুন',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'স্টোর আইডি (Firestore Collection ID):',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<Map<String, String>>(
                      future: ref.read(firebaseSyncServiceProvider).getStoreDocIdAndShopID(widget.settings.shopName),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return Text(
                          snapshot.data?['storeDocId'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'সর্বশেষ সিঙ্ক:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ref.watch(settingsLastSyncTimeProvider) != null
                            ? Formatters.dateTime(ref.watch(settingsLastSyncTimeProvider)!)
                            : 'এখনো সিঙ্ক করা হয়নি',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: ref.watch(settingsIsSyncingProvider)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(ref.watch(settingsIsSyncingProvider) ? 'সিঙ্ক হচ্ছে...' : 'এখনই সিঙ্ক করুন'),
                    onPressed: ref.watch(settingsIsSyncingProvider)
                        ? null
                        : () async {
                            ref.read(settingsIsSyncingProvider.notifier).state = true;
                            try {
                              final syncService = ref.read(firebaseSyncServiceProvider);
                              await syncService.syncAllData(widget.settings);
                              ref.read(settingsLastSyncTimeProvider.notifier).state = DateTime.now();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('ডাটাবেস সফলভাবে ফায়ারবেসে সিঙ্ক করা হয়েছে!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('সিঙ্ক করতে সমস্যা হয়েছে: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              ref.read(settingsIsSyncingProvider.notifier).state = false;
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
