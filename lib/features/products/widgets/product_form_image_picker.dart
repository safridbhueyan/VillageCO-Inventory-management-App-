import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/product_image_widget.dart';

class ProductFormImagePicker extends StatelessWidget {
  final String? imagePath;
  final ValueChanged<String?> onImageSelected;

  const ProductFormImagePicker({
    super.key,
    required this.imagePath,
    required this.onImageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Builder(
      builder: (pickerContext) => GestureDetector(
        onTap: () async {
          final scaffoldCtx = context;
          try {
            final File? result = await ImageUtils.pickAndCropImage(scaffoldCtx);
            if (result != null) {
              final appDir = await getApplicationDocumentsDirectory();
              final ext = p.extension(result.path);
              final filename = 'prod_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
              final destPath = p.join(appDir.path, filename);
              final savedPath = result.path.startsWith(appDir.path)
                  ? result.path
                  : (await result.copy(destPath)).path;
              onImageSelected(savedPath);
            }
          } catch (e) {
            debugPrint('Image pick/crop error: $e');
            if (scaffoldCtx.mounted) {
              ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
                SnackBar(content: Text('ছবি আপলোড ব্যর্থ হয়েছে: $e')),
              );
            }
          }
        },
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: imagePath != null && (imagePath!.startsWith('http') || File(imagePath!).existsSync())
              ? Stack(
                  children: [
                    ProductImageWidget(
                      imagePath: imagePath,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      borderRadius: 12,
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 16,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 16, color: Colors.white),
                          onPressed: () => onImageSelected(null),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crop, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'পরিবর্তন করুন',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 24,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 1,
                          height: 24,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.photo_library_rounded,
                          size: 24,
                          color: theme.colorScheme.secondary.withOpacity(0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ক্যামেরা বা গ্যালারি থেকে ছবি যোগ করুন',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
