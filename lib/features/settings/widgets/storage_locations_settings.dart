import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/database/database.dart';
import '../settings_controller.dart';

class StorageLocationsSettings extends ConsumerWidget {
  final AppSettingsTableData settings;

  const StorageLocationsSettings({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('স্টোরেজ ও সেভ লোকেশন', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('ডিফল্ট পিডিএফ সেভ ফোল্ডার'),
                  subtitle: Text(
                    settings.pdfSavePath != null && settings.pdfSavePath!.isNotEmpty
                        ? settings.pdfSavePath!
                        : 'ডিফল্ট ডাউনলোড/ডকুমেন্টস',
                    style: TextStyle(
                      color: settings.pdfSavePath != null ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.folder_open_outlined),
                        onPressed: () async {
                          try {
                            final path = await FilePicker.platform.getDirectoryPath();
                            if (path != null) {
                              await ref.read(settingsControllerProvider.notifier).updatePdfSavePath(path);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('পিডিএফ সেভ ফোল্ডার সেট করা হয়েছে!')),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('ফোল্ডার সিলেক্ট করতে সমস্যা হয়েছে: $e')),
                              );
                            }
                          }
                        },
                      ),
                      if (settings.pdfSavePath != null && settings.pdfSavePath!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () async {
                            await ref.read(settingsControllerProvider.notifier).updatePdfSavePath(null);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('পিডিএফ সেভ ফোল্ডার রিসেট করা হয়েছে')),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('ডিফল্ট সিএসভি সেভ ফোল্ডার'),
                  subtitle: Text(
                    settings.csvSavePath != null && settings.csvSavePath!.isNotEmpty
                        ? settings.csvSavePath!
                        : 'ডিফল্ট ডাউনলোড/ডকুমেন্টস',
                    style: TextStyle(
                      color: settings.csvSavePath != null ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.folder_open_outlined),
                        onPressed: () async {
                          try {
                            final path = await FilePicker.platform.getDirectoryPath();
                            if (path != null) {
                              await ref.read(settingsControllerProvider.notifier).updateCsvSavePath(path);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('সিএসভি সেভ ফোল্ডার সেট করা হয়েছে!')),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('ফোল্ডার সিলেক্ট করতে সমস্যা হয়েছে: $e')),
                              );
                            }
                          }
                        },
                      ),
                      if (settings.csvSavePath != null && settings.csvSavePath!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () async {
                            await ref.read(settingsControllerProvider.notifier).updateCsvSavePath(null);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('সিএসভি সেভ ফোল্ডার রিসেট করা হয়েছে')),
                              );
                            }
                          },
                        ),
                      ],
                    ],
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
