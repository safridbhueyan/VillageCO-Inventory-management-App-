import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Requests storage permissions on Android. Returns true if granted (or if not on Android).
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Check if either manageExternalStorage or storage permission is already granted
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;

    // Show a beautiful, localized in-app explanation dialog before requesting
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.folder_shared_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'স্টোরেজ পারমিশন প্রয়োজন',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'পিডিএফ রশিদ এবং সিএসভি রিপোর্ট সংরক্ষণ করতে আপনার ডিভাইসের স্টোরেজ পারমিশন প্রয়োজন।',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'পারমিশন দিতে "ঠিক আছে" বোতামে চাপুন। এটি আপনাকে সেটিংস পেজে নিয়ে যেতে পারে, যেখানে আপনাকে "Allow access to manage all files" বা "Storage" পারমিশন চালু করতে হবে।',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'বাতিল করুন',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );

    if (proceed != true) return false;

    // Request MANAGE_EXTERNAL_STORAGE first (Android 11+)
    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    // Fallback to requesting standard storage permission (Android 10 and below)
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }
}
