import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

class SettingsController extends AsyncNotifier<AppSettingsTableData> {
  late final AppDatabase _db;

  @override
  Future<AppSettingsTableData> build() async {
    _db = ref.watch(databaseProvider);
    return _getOrInitSettings();
  }

  Future<AppSettingsTableData> _getOrInitSettings() async {
    final settingsList = await _db.select(_db.appSettingsTable).get();
    if (settingsList.isEmpty) {
      const defaultSettings = AppSettingsTableCompanion(
        id: Value(1),
        shopName: Value('VillageCO Inventory'),
        currency: Value('USD'),
        language: Value('en'),
        taxRate: Value(0.0),
        adminPin: Value('1234'),
        isDarkMode: Value(false),
      );
      await _db.into(_db.appSettingsTable).insert(defaultSettings);
      return (await _db.select(_db.appSettingsTable).get()).first;
    }
    return settingsList.first;
  }

  Future<void> updateSettings(AppSettingsTableCompanion companion) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await (_db.update(_db.appSettingsTable)
            ..where((t) => t.id.equals(1)))
          .write(companion);
      return _getOrInitSettings();
    });
  }

  Future<void> setDarkMode(bool value) async {
    await updateSettings(AppSettingsTableCompanion(isDarkMode: Value(value)));
  }

  Future<void> setAdminPin(String value) async {
    await updateSettings(AppSettingsTableCompanion(adminPin: Value(value)));
  }

  Future<void> updateShopDetails(String name, double taxRate, String currency) async {
    await updateSettings(AppSettingsTableCompanion(
      shopName: Value(name),
      taxRate: Value(taxRate),
      currency: Value(currency),
    ));
  }

  // Backup data to JSON
  Future<String> exportToJson() async {
    final categories = await _db.select(_db.categories).get();
    final products = await _db.select(_db.products).get();
    final suppliers = await _db.select(_db.suppliers).get();
    final customers = await _db.select(_db.customers).get();
    final sales = await _db.select(_db.sales).get();
    final saleItems = await _db.select(_db.saleItems).get();
    final purchases = await _db.select(_db.purchases).get();
    final expenses = await _db.select(_db.expenses).get();
    final stockHistory = await _db.select(_db.stockHistory).get();
    final settings = await _db.select(_db.appSettingsTable).get();

    final data = {
      'categories': categories.map((e) => e.toJson()).toList(),
      'products': products.map((e) => e.toJson()).toList(),
      'suppliers': suppliers.map((e) => e.toJson()).toList(),
      'customers': customers.map((e) => e.toJson()).toList(),
      'sales': sales.map((e) => e.toJson()).toList(),
      'saleItems': saleItems.map((e) => e.toJson()).toList(),
      'purchases': purchases.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'stockHistory': stockHistory.map((e) => e.toJson()).toList(),
      'settings': settings.map((e) => e.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String?> _downloadProductImage(String url, String id) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final productsDir = Directory('${appDir.path}/products');
      if (!await productsDir.exists()) {
        await productsDir.create(recursive: true);
      }
      final file = File('${productsDir.path}/$id.jpg');
      
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      print('Error downloading product image: $e');
    }
    return null;
  }

  // Restore data from JSON
  Future<void> importFromJson(String jsonStr) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    
    await _db.transaction(() async {
      // Clear all records
      await _db.delete(_db.categories).go();
      await _db.delete(_db.products).go();
      await _db.delete(_db.suppliers).go();
      await _db.delete(_db.customers).go();
      await _db.delete(_db.sales).go();
      await _db.delete(_db.saleItems).go();
      await _db.delete(_db.purchases).go();
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.stockHistory).go();
      await _db.delete(_db.appSettingsTable).go();

      // Insert Categories
      if (data['categories'] != null) {
        for (var item in data['categories']) {
          await _db.into(_db.categories).insert(Category.fromJson(item));
        }
      }
      // Insert Suppliers
      if (data['suppliers'] != null) {
        for (var item in data['suppliers']) {
          await _db.into(_db.suppliers).insert(Supplier.fromJson(item));
        }
      }
      // Insert Customers
      if (data['customers'] != null) {
        for (var item in data['customers']) {
          await _db.into(_db.customers).insert(Customer.fromJson(item));
        }
      }
      // Insert Products
      if (data['products'] != null) {
        for (var item in data['products']) {
          String? imagePath;
          if (item['imageUrl'] != null) {
            imagePath = await _downloadProductImage(item['imageUrl'], item['id']);
          }
          final Map<String, dynamic> productJson = Map<String, dynamic>.from(item);
          if (imagePath != null) {
            productJson['imagePath'] = imagePath;
          }
          await _db.into(_db.products).insert(Product.fromJson(productJson));
        }
      }
      // Insert Sales
      if (data['sales'] != null) {
        for (var item in data['sales']) {
          await _db.into(_db.sales).insert(Sale.fromJson(item));
        }
      }
      // Insert SaleItems
      if (data['saleItems'] != null) {
        for (var item in data['saleItems']) {
          await _db.into(_db.saleItems).insert(SaleItem.fromJson(item));
        }
      }
      // Insert Purchases
      if (data['purchases'] != null) {
        for (var item in data['purchases']) {
          await _db.into(_db.purchases).insert(Purchase.fromJson(item));
        }
      }
      // Insert Expenses
      if (data['expenses'] != null) {
        for (var item in data['expenses']) {
          await _db.into(_db.expenses).insert(Expense.fromJson(item));
        }
      }
      // Insert StockHistory
      if (data['stockHistory'] != null) {
        for (var item in data['stockHistory']) {
          await _db.into(_db.stockHistory).insert(StockHistoryData.fromJson(item));
        }
      }
      // Insert Settings
      if (data['settings'] != null) {
        for (var item in data['settings']) {
          await _db.into(_db.appSettingsTable).insert(AppSettingsTableData.fromJson(item));
        }
      }
    });

    ref.invalidateSelf();
  }
}

final settingsControllerProvider = AsyncNotifierProvider<SettingsController, AppSettingsTableData>(() {
  return SettingsController();
});
