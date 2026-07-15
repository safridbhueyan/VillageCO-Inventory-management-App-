import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/categories_controller.dart';
import '../../products/products_controller.dart';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  const CategoryManagementDialog({super.key});

  @override
  ConsumerState<CategoryManagementDialog> createState() => _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends ConsumerState<CategoryManagementDialog> {
  final catNameController = TextEditingController();
  String selectedIcon = 'local_cafe';
  String selectedColor = '0xFF008060';

  @override
  void dispose() {
    catNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesControllerProvider);

    return AlertDialog(
      title: const Text('ক্যাটাগরি সমূহ ম্যানেজ করুন'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                child: categoriesAsync.maybeWhen(
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text('কোনো ক্যাটাগরি তৈরি করা হয়নি।'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final cat = list[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Color(int.parse(cat.color)),
                            child: const Icon(Icons.category, color: Colors.white, size: 16),
                          ),
                          title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              ref.read(categoriesControllerProvider.notifier).deleteCategory(cat.id);
                              ref.invalidate(productsListProvider);
                            },
                          ),
                        );
                      },
                    );
                  },
                  orElse: () => const Center(child: CircularProgressIndicator()),
                ),
              ),
              const Divider(height: 24),
              const Text('নতুন ক্যাটাগরি তৈরি করুন', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: catNameController,
                decoration: const InputDecoration(
                  labelText: 'ক্যাটাগরির নাম',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('আইকন নির্বাচন করুন'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'local_cafe',
                  'fastfood',
                  'shopping_basket',
                  'grass',
                  'soap',
                  'cleaning_services',
                ].map((icName) {
                  IconData iconData;
                  switch (icName) {
                    case 'local_cafe': iconData = Icons.local_cafe; break;
                    case 'fastfood': iconData = Icons.fastfood; break;
                    case 'shopping_basket': iconData = Icons.shopping_basket; break;
                    case 'grass': iconData = Icons.grass; break;
                    case 'soap': iconData = Icons.soap; break;
                    default: iconData = Icons.cleaning_services;
                  }
                  final isSelected = selectedIcon == icName;
                  return IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                      foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    ),
                    icon: Icon(iconData, size: 18),
                    onPressed: () => setState(() => selectedIcon = icName),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('রঙ নির্বাচন করুন'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  '0xFF008060',
                  '0xFFFF8C00',
                  '0xFF4682B4',
                  '0xFFDAA520',
                  '0xFFBA55D3',
                ].map((hexStr) {
                  final isSelected = selectedColor == hexStr;
                  return InkWell(
                    onTap: () => setState(() => selectedColor = hexStr),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(int.parse(hexStr)),
                        border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = catNameController.text.trim();
                    if (name.isNotEmpty) {
                      ref.read(categoriesControllerProvider.notifier).addCategory(
                            name,
                            selectedIcon,
                            selectedColor,
                          );
                      catNameController.clear();
                    }
                  },
                  child: const Text('ক্যাটাগরি যোগ করুন'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বন্ধ করুন'),
        ),
      ],
    );
  }
}
