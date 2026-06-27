import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/utils/formatters.dart';
import 'settings_controller.dart';
import '../categories/categories_controller.dart';
import '../products/products_controller.dart';
import '../reports/reports_controller.dart';
import '../suppliers/suppliers_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedCurrency = 'USD';

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings & Backups', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error loading settings: $err')),
        data: (settings) {
          // Initialize controllers if empty
          if (_shopNameController.text.isEmpty) {
            _shopNameController.text = settings.shopName;
            _taxRateController.text = settings.taxRate.toString();
            _selectedCurrency = settings.currency;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme settings section
                Text('Display & Themes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark Theme Mode'),
                    subtitle: const Text('Toggle between dark and light workspace styling'),
                    trailing: Switch(
                      value: settings.isDarkMode,
                      onChanged: (val) {
                        ref.read(settingsControllerProvider.notifier).setDarkMode(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Shop settings section
                Text('Shop Profile Metadata', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        TextField(
                          controller: _shopNameController,
                          decoration: const InputDecoration(labelText: 'Shop Name', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCurrency,
                                decoration: const InputDecoration(labelText: 'Currency Symbol', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                                  DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                                  DropdownMenuItem(value: 'BDT', child: Text('BDT (৳)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCurrency = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _taxRateController,
                                decoration: const InputDecoration(
                                  labelText: 'Tax Rate (%)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = _shopNameController.text.trim();
                              final tax = double.tryParse(_taxRateController.text) ?? 0.0;
                              if (name.isNotEmpty) {
                                await ref.read(settingsControllerProvider.notifier).updateShopDetails(
                                      name,
                                      tax,
                                      _selectedCurrency,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Shop settings updated!')),
                                  );
                                }
                              }
                            },
                            child: const Text('Update Profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Category management shortcuts
                Text('Catalog Categories', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Manage Catalog Categories'),
                    subtitle: const Text('Add, edit, or delete classifications for products'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _showCategoryManagementDialog(context),
                  ),
                ),
                const SizedBox(height: 24),

                // Security admin lock code
                Text('Security & Admin Access', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        const Text('Change Admin Terminal PIN (4-Digits)', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _pinController,
                                decoration: const InputDecoration(
                                  labelText: 'New 4-Digit PIN',
                                  border: OutlineInputBorder(),
                                  counterText: '',
                                ),
                                maxLength: 4,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                              onPressed: () async {
                                final pin = _pinController.text.trim();
                                if (pin.length == 4 && int.tryParse(pin) != null) {
                                  await ref.read(settingsControllerProvider.notifier).setAdminPin(pin);
                                  _pinController.clear();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Admin PIN code changed successfully!')),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('PIN must be exactly 4 digits.')),
                                  );
                                }
                              },
                              child: const Text('Change PIN'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Backup settings section
                Text('Backup & Database Restore', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                          title: const Text('Export JSON Database'),
                          subtitle: const Text('Downloads SQLite data tables structure to a JSON backup file'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.cloud_upload_outlined),
                            onPressed: () => _exportDatabaseBackup(context),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Import JSON Database'),
                          subtitle: const Text('Select a previously exported JSON backup to override local database tables'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.cloud_download_outlined),
                            onPressed: () => _importDatabaseBackup(context),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Load Demo Conveniences Data'),
                          subtitle: const Text('Overwrites database tables with high-fidelity sample grocery items and category structures'),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.insights),
                            onPressed: () => _loadDemoStoreData(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Dialog to CRUD Categories
  void _showCategoryManagementDialog(BuildContext context) {
    final theme = Theme.of(context);
    final catNameController = TextEditingController();
    String selectedIcon = 'local_cafe';
    String selectedColor = '0xFF008060'; // Hex string

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categoriesAsync = ref.watch(categoriesControllerProvider);

            return AlertDialog(
              title: const Text('Manage Categories'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Categories list
                    Flexible(
                      child: categoriesAsync.maybeWhen(
                        data: (list) {
                          if (list.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('No categories created.'));
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final cat = list[index];
                              return ListTile(
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
                        orElse: () => const CircularProgressIndicator(),
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Create New Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: catNameController,
                      decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    // Icon Select Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                          onPressed: () => setDialogState(() => selectedIcon = icName),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    // Color Select Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        '0xFF008060', // Soft Green
                        '0xFFFF8C00', // Dark Orange
                        '0xFF4682B4', // Steel Blue
                        '0xFFDAA520', // Goldenrod
                        '0xFFBA55D3', // Medium Orchid
                      ].map((hexStr) {
                        final isSelected = selectedColor == hexStr;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedColor = hexStr),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(int.parse(hexStr)),
                              border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
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
                        child: const Text('Add Category'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  // Backup database json file export
  Future<void> _exportDatabaseBackup(BuildContext context) async {
    try {
      final jsonStr = await ref.read(settingsControllerProvider.notifier).exportToJson();
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'villageco_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      final file = File(path);
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database exported to: $path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  // Import local database from JSON file selector dialog input
  void _importDatabaseBackup(BuildContext context) {
    final inputController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database from Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste the JSON content of your previously exported database backup below to restore all tables.'),
            const SizedBox(height: 12),
            TextField(
              controller: inputController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste backup JSON here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final json = inputController.text.trim();
              if (json.isEmpty) return;

              try {
                await ref.read(settingsControllerProvider.notifier).importFromJson(json);
                // invalidate providers to reload UI
                ref.invalidate(productsListProvider);
                ref.invalidate(categoriesControllerProvider);
                ref.invalidate(suppliersControllerProvider);
                ref.invalidate(salesHistoryProvider);
                ref.invalidate(dashboardMetricsProvider);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Database restored successfully!')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to parse backup JSON: $e')),
                );
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  // Load sample convenio store data
  Future<void> _loadDemoStoreData(BuildContext context) async {
    const demoJson = '''
    {
      "categories": [
        {"id": "c1", "name": "Drinks & Sodas", "icon": "local_cafe", "color": "0xFF008060"},
        {"id": "c2", "name": "Snacks & Chips", "icon": "fastfood", "color": "0xFFFF8C00"},
        {"id": "c3", "name": "Grocery Essentials", "icon": "shopping_basket", "color": "0xFF4682B4"},
        {"id": "c4", "name": "Rice & Flour", "icon": "grass", "color": "0xFFDAA520"}
      ],
      "suppliers": [
        {"id": "s1", "name": "Metro Distribution Ltd", "phone": "01711223344", "email": "info@metro.com", "address": "Tejgaon Industrial Area, Dhaka"},
        {"id": "s2", "name": "Green Valley Traders", "phone": "01999998888", "email": "sales@greenvalley.com", "address": "Khatungonj, Chittagong"}
      ],
      "customers": [
        {"id": "cust1", "name": "Kamal Uddin", "phone": "01671112222", "email": "kamal@gmail.com", "address": "Mirpur, Dhaka"},
        {"id": "cust2", "name": "Fatima Begum", "phone": "01851234567", "email": "fatima@gmail.com", "address": "Gulshan, Dhaka"}
      ],
      "products": [
        {"id": "p1", "name": "Coca-Cola 250ml", "barcode": "88010203040", "categoryId": "c1", "brand": "Coca-Cola", "buyingPrice": 0.28, "sellingPrice": 0.38, "currentStock": 120.0, "minimumStock": 30.0, "unit": "pcs", "supplierId": "s1", "description": "Soft drink can.", "isArchived": false, "isFavorite": true},
        {"id": "p2", "name": "Sprite 250ml", "barcode": "88010203045", "categoryId": "c1", "brand": "Coca-Cola", "buyingPrice": 0.28, "sellingPrice": 0.38, "currentStock": 80.0, "minimumStock": 20.0, "unit": "pcs", "supplierId": "s1", "description": "Lemony soft drink.", "isArchived": false, "isFavorite": false},
        {"id": "p3", "name": "Bashundhara Flour 2kg", "barcode": "88010203052", "categoryId": "c4", "brand": "Bashundhara", "buyingPrice": 1.20, "sellingPrice": 1.50, "currentStock": 40.0, "minimumStock": 10.0, "unit": "bag", "supplierId": "s2", "description": "All purpose white flour.", "isArchived": false, "isFavorite": true},
        {"id": "p4", "name": "Miniket White Rice 25kg", "barcode": "88010203058", "categoryId": "c4", "brand": "Rashid Rice", "buyingPrice": 16.00, "sellingPrice": 19.50, "currentStock": 8.0, "minimumStock": 15.0, "unit": "bag", "supplierId": "s2", "description": "Polished long grain rice.", "isArchived": false, "isFavorite": true},
        {"id": "p5", "name": "Lay's Potato Chips Magic Masala", "barcode": "88010203061", "categoryId": "c2", "brand": "PepsiCo", "buyingPrice": 0.18, "sellingPrice": 0.25, "currentStock": 15.0, "minimumStock": 25.0, "unit": "pcs", "supplierId": "s1", "description": "Spicy Indian-flavor chips.", "isArchived": false, "isFavorite": false},
        {"id": "p6", "name": "Lipton Black Tea 100 bags", "barcode": "88010203070", "categoryId": "c3", "brand": "Unilever", "buyingPrice": 2.20, "sellingPrice": 2.90, "currentStock": 25.0, "minimumStock": 5.0, "unit": "pcs", "supplierId": "s1", "description": "High quality black tea bags.", "isArchived": false, "isFavorite": false}
      ]
    }
    ''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Demo Conveniences Data?'),
        content: const Text('Warning: This action will completely erase your existing products, categories, suppliers, and sales data tables, replacing them with a premium convenience store inventory list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(settingsControllerProvider.notifier).importFromJson(demoJson);
                // invalidate providers to reload UI
                ref.invalidate(productsListProvider);
                ref.invalidate(categoriesControllerProvider);
                ref.invalidate(suppliersControllerProvider);
                ref.invalidate(salesHistoryProvider);
                ref.invalidate(dashboardMetricsProvider);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo Convenience Shop dataset loaded successfully! Check Dashboard and Products.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to load demo dataset: $e')),
                );
              }
            },
            child: const Text('Load Demo Data'),
          ),
        ],
      ),
    );
  }
}
