import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/products/products_controller.dart';
import '../../features/reports/reports_controller.dart';
import '../../features/categories/categories_controller.dart';
import '../../features/suppliers/suppliers_controller.dart';
import '../../core/database/firebase_sync_service.dart';

class AdminImpersonationState {
  final bool isImpersonating;
  final String? originalShopName;
  final String? originalAdminPin;
  final String? currentShopDocId;
  final String? currentShopName;

  AdminImpersonationState({
    this.isImpersonating = false,
    this.originalShopName,
    this.originalAdminPin,
    this.currentShopDocId,
    this.currentShopName,
  });

  AdminImpersonationState copyWith({
    bool? isImpersonating,
    String? originalShopName,
    String? originalAdminPin,
    String? currentShopDocId,
    String? currentShopName,
  }) {
    return AdminImpersonationState(
      isImpersonating: isImpersonating ?? this.isImpersonating,
      originalShopName: originalShopName ?? this.originalShopName,
      originalAdminPin: originalAdminPin ?? this.originalAdminPin,
      currentShopDocId: currentShopDocId ?? this.currentShopDocId,
      currentShopName: currentShopName ?? this.currentShopName,
    );
  }
}

class AdminImpersonationNotifier extends StateNotifier<AdminImpersonationState> {
  AdminImpersonationNotifier() : super(AdminImpersonationState());

  void startImpersonation({
    required String shopDocId,
    required String shopName,
    required String originalShopName,
    required String originalAdminPin,
  }) {
    state = AdminImpersonationState(
      isImpersonating: true,
      originalShopName: originalShopName,
      originalAdminPin: originalAdminPin,
      currentShopDocId: shopDocId,
      currentShopName: shopName,
    );
  }

  void stopImpersonation() {
    state = AdminImpersonationState();
  }
}

final adminImpersonationProvider = StateNotifierProvider<AdminImpersonationNotifier, AdminImpersonationState>((ref) {
  return AdminImpersonationNotifier();
});

class AdminRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Ref _ref;

  AdminRepository(this._db, this._ref);

  /// Fetch all shops from Firestore
  Stream<QuerySnapshot<Map<String, dynamic>>> getShopsStream() {
    return _firestore.collection('stores').snapshots();
  }

  /// Create a new shop in Firestore
  Future<void> createShop({
    required String name,
    required String pin,
    required String currency,
    required double taxRate,
  }) async {
    final cleanName = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final baseName = cleanName.isEmpty ? 'defaultinventory' : cleanName;

    String finalShopID = 'vc001';
    String finalStoreDocId = '${baseName}_vc001';

    final querySnapshot = await _firestore.collection('stores').get();
    int maxNum = 0;
    final regex = RegExp(r'_vc(\d+)$');
    for (final doc in querySnapshot.docs) {
      final id = doc.id;
      final match = regex.firstMatch(id);
      if (match != null) {
        final suffixStr = match.group(1);
        if (suffixStr != null) {
          final num = int.tryParse(suffixStr);
          if (num != null && num > maxNum) {
            maxNum = num;
          }
        }
      }
    }
    
    final nextNum = maxNum + 1;
    finalShopID = 'vc${nextNum.toString().padLeft(3, '0')}';
    finalStoreDocId = '${baseName}_$finalShopID';

    // Set store document
    await _firestore.collection('stores').doc(finalStoreDocId).set({
      'shopName': name,
      'shopID': finalShopID,
      'currency': currency,
      'language': 'en',
      'taxRate': taxRate,
      'adminPin': pin,
      'isDarkMode': false,
      'lastSyncedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Edit existing shop details on Firestore
  Future<void> editShop({
    required String storeDocId,
    required String newName,
    required String newPin,
    required String currency,
    required double taxRate,
  }) async {
    final docRef = _firestore.collection('stores').doc(storeDocId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final oldName = docSnap.data()?['shopName'] ?? '';
    final oldClean = oldName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final newClean = newName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (oldClean != newClean) {
      final shopID = docSnap.data()?['shopID'] ?? 'vc001';
      final baseName = newClean.isEmpty ? 'defaultinventory' : newClean;
      final newStoreDocId = '${baseName}_$shopID';

      String targetStoreDocId = newStoreDocId;
      String targetShopID = shopID;

      // Check collision
      final checkSnap = await _firestore.collection('stores').doc(newStoreDocId).get();
      if (checkSnap.exists) {
        final querySnapshot = await _firestore.collection('stores').get();
        int maxNum = 0;
        for (final doc in querySnapshot.docs) {
          final id = doc.id;
          final match = RegExp(r'_vc(\d+)$').firstMatch(id);
          if (match != null) {
            final numStr = match.group(1);
            if (numStr != null) {
              final num = int.tryParse(numStr);
              if (num != null && num > maxNum) {
                maxNum = num;
              }
            }
          }
        }
        final nextNum = maxNum + 1;
        targetShopID = 'vc${nextNum.toString().padLeft(3, '0')}';
        targetStoreDocId = '${baseName}_$targetShopID';
      }

      // Copy and delete old document/subcollections
      final syncService = _ref.read(firebaseSyncServiceProvider);
      await syncService.moveFirestoreStore(storeDocId, targetStoreDocId);

      // Update the new document fields to make sure the edited name/settings are applied
      await _firestore.collection('stores').doc(targetStoreDocId).update({
        'shopName': newName,
        'adminPin': newPin,
        'currency': currency,
        'taxRate': taxRate,
        'shopID': targetShopID,
      });
    } else {
      // Just update existing document
      await docRef.update({
        'shopName': newName,
        'adminPin': newPin,
        'currency': currency,
        'taxRate': taxRate,
      });
    }
  }

  /// Delete shop from Firestore (including all subcollections)
  Future<void> deleteShop(String storeDocId) async {
    final docRef = _firestore.collection('stores').doc(storeDocId);

    // Delete categories subcollection
    final categories = await docRef.collection('categories').get();
    for (var doc in categories.docs) {
      await doc.reference.delete();
    }

    // Delete suppliers
    final suppliers = await docRef.collection('suppliers').get();
    for (var doc in suppliers.docs) {
      await doc.reference.delete();
    }

    // Delete customers
    final customers = await docRef.collection('customers').get();
    for (var doc in customers.docs) {
      await doc.reference.delete();
    }

    // Delete products
    final products = await docRef.collection('products').get();
    for (var doc in products.docs) {
      await doc.reference.delete();
    }

    // Delete sales
    final sales = await docRef.collection('sales').get();
    for (var doc in sales.docs) {
      await doc.reference.delete();
    }

    // Delete expenses
    final expenses = await docRef.collection('expenses').get();
    for (var doc in expenses.docs) {
      await doc.reference.delete();
    }

    // Delete stockHistory
    final stockHistory = await docRef.collection('stockHistory').get();
    for (var doc in stockHistory.docs) {
      await doc.reference.delete();
    }

    // Delete supplierOrders
    final supplierOrders = await docRef.collection('supplierOrders').get();
    for (var doc in supplierOrders.docs) {
      await doc.reference.delete();
    }

    // Delete damagedItems
    final damagedItems = await docRef.collection('damagedItems').get();
    for (var doc in damagedItems.docs) {
      await doc.reference.delete();
    }

    // Finally delete the main document
    await docRef.delete();
  }

  /// Pull a shop's data from Firestore and insert it into SQLite Drift
  Future<void> pullShopData(String storeDocId) async {
    final docRef = _firestore.collection('stores').doc(storeDocId);
    final storeDoc = await docRef.get();
    if (!storeDoc.exists) return;
    
    final storeData = storeDoc.data()!;
    final shopID = storeData['shopID'] ?? 'vc001';

    // Update the local sync configuration file and memory cache
    final syncService = _ref.read(firebaseSyncServiceProvider);
    await syncService.updateStoreConfig(storeDocId: storeDocId, shopID: shopID);

    final categoriesSnap = await docRef.collection('categories').get();
    final suppliersSnap = await docRef.collection('suppliers').get();
    final customersSnap = await docRef.collection('customers').get();
    final productsSnap = await docRef.collection('products').get();
    final salesSnap = await docRef.collection('sales').get();
    final expensesSnap = await docRef.collection('expenses').get();
    final stockHistorySnap = await docRef.collection('stockHistory').get();
    final supplierOrdersSnap = await docRef.collection('supplierOrders').get();
    final damagedItemsSnap = await docRef.collection('damagedItems').get();

    await _db.transaction(() async {
      // Clear current database tables
      await _db.delete(_db.categories).go();
      await _db.delete(_db.products).go();
      await _db.delete(_db.suppliers).go();
      await _db.delete(_db.customers).go();
      await _db.delete(_db.sales).go();
      await _db.delete(_db.saleItems).go();
      await _db.delete(_db.purchases).go();
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.stockHistory).go();
      await _db.delete(_db.supplierOrders).go();
      await _db.delete(_db.damagedItems).go();
      await _db.delete(_db.appSettingsTable).go();

      // Write app settings
      await _db.into(_db.appSettingsTable).insert(AppSettingsTableCompanion(
        id: const Value(1),
        shopName: Value(storeData['shopName'] ?? 'VillageCO Inventory'),
        currency: Value(storeData['currency'] ?? 'USD'),
        language: Value(storeData['language'] ?? 'en'),
        taxRate: Value((storeData['taxRate'] as num?)?.toDouble() ?? 0.0),
        adminPin: Value(storeData['adminPin'] ?? '1234'),
        isDarkMode: Value(storeData['isDarkMode'] ?? false),
      ));

      // Categories
      for (var doc in categoriesSnap.docs) {
        final d = doc.data();
        await _db.into(_db.categories).insert(CategoriesCompanion(
          id: Value(d['id']),
          name: Value(d['name'] ?? ''),
          icon: Value(d['icon'] ?? 'category'),
          color: Value(d['color'] ?? '0xFF008060'),
        ));
      }

      // Suppliers
      for (var doc in suppliersSnap.docs) {
        final d = doc.data();
        await _db.into(_db.suppliers).insert(SuppliersCompanion(
          id: Value(d['id']),
          name: Value(d['name'] ?? ''),
          phone: Value(d['phone'] ?? ''),
          email: Value(d['email']),
          address: Value(d['address']),
        ));
      }

      // Customers
      for (var doc in customersSnap.docs) {
        final d = doc.data();
        await _db.into(_db.customers).insert(CustomersCompanion(
          id: Value(d['id']),
          name: Value(d['name'] ?? ''),
          phone: Value(d['phone'] ?? ''),
          email: Value(d['email']),
          address: Value(d['address']),
        ));
      }

      // Products
      for (var doc in productsSnap.docs) {
        final d = doc.data();
        await _db.into(_db.products).insert(ProductsCompanion(
          id: Value(d['id']),
          name: Value(d['name'] ?? ''),
          barcode: Value(d['barcode']),
          categoryId: Value(d['categoryId']),
          brand: Value(d['brand']),
          buyingPrice: Value((d['buyingPrice'] as num?)?.toDouble() ?? 0.0),
          sellingPrice: Value((d['sellingPrice'] as num?)?.toDouble() ?? 0.0),
          currentStock: Value((d['currentStock'] as num?)?.toDouble() ?? 0.0),
          minimumStock: Value((d['minimumStock'] as num?)?.toDouble() ?? 0.0),
          unit: Value(d['unit'] ?? 'pcs'),
          supplierId: Value(d['supplierId']),
          imagePath: Value(d['imagePath']),
          description: Value(d['description']),
          isArchived: Value(d['isArchived'] ?? false),
          isFavorite: Value(d['isFavorite'] ?? false),
          createdAt: Value(d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : DateTime.now()),
        ));
      }

      // Sales & SaleItems
      for (var doc in salesSnap.docs) {
        final d = doc.data();
        final saleId = d['id'];
        
        DateTime saleDate = DateTime.now();
        if (d['date'] != null) {
          if (d['date'] is Timestamp) {
            saleDate = (d['date'] as Timestamp).toDate();
          } else if (d['date'] is String) {
            saleDate = DateTime.tryParse(d['date']) ?? DateTime.now();
          }
        }

        await _db.into(_db.sales).insert(SalesCompanion(
          id: Value(saleId),
          date: Value(saleDate),
          subtotal: Value((d['subtotal'] as num?)?.toDouble() ?? 0.0),
          discount: Value((d['discount'] as num?)?.toDouble() ?? 0.0),
          total: Value((d['total'] as num?)?.toDouble() ?? 0.0),
          paymentMethod: Value(d['paymentMethod'] ?? 'Cash'),
          customerId: Value(d['customerId']),
        ));

        final List<dynamic> items = d['items'] ?? [];
        for (var item in items) {
          await _db.into(_db.saleItems).insert(SaleItemsCompanion(
            id: Value(item['id'] ?? const Uuid().v4()),
            saleId: Value(saleId),
            productId: Value(item['productId'] ?? ''),
            quantity: Value((item['quantity'] as num?)?.toDouble() ?? 0.0),
            price: Value((item['price'] as num?)?.toDouble() ?? 0.0),
            cost: Value((item['cost'] as num?)?.toDouble() ?? 0.0),
          ));
        }
      }

      // Expenses
      for (var doc in expensesSnap.docs) {
        final d = doc.data();
        
        DateTime expDate = DateTime.now();
        if (d['date'] != null) {
          if (d['date'] is Timestamp) {
            expDate = (d['date'] as Timestamp).toDate();
          } else if (d['date'] is String) {
            expDate = DateTime.tryParse(d['date']) ?? DateTime.now();
          }
        }

        await _db.into(_db.expenses).insert(ExpensesCompanion(
          id: Value(d['id']),
          name: Value(d['name'] ?? ''),
          amount: Value((d['amount'] as num?)?.toDouble() ?? 0.0),
          category: Value(d['category'] ?? ''),
          date: Value(expDate),
          description: Value(d['description']),
        ));
      }

      // StockHistory
      for (var doc in stockHistorySnap.docs) {
        final d = doc.data();
        
        DateTime histDate = DateTime.now();
        if (d['date'] != null) {
          if (d['date'] is Timestamp) {
            histDate = (d['date'] as Timestamp).toDate();
          } else if (d['date'] is String) {
            histDate = DateTime.tryParse(d['date']) ?? DateTime.now();
          }
        }

        await _db.into(_db.stockHistory).insert(StockHistoryCompanion(
          id: Value(d['id']),
          productId: Value(d['productId'] ?? ''),
          changeAmount: Value((d['changeAmount'] as num?)?.toDouble() ?? 0.0),
          reason: Value(d['reason'] ?? 'Adjust Stock'),
          supplierId: Value(d['supplierId']),
          date: Value(histDate),
        ));
      }

      // SupplierOrders
      for (var doc in supplierOrdersSnap.docs) {
        final d = doc.data();
        
        DateTime ordDate = DateTime.now();
        if (d['date'] != null) {
          if (d['date'] is Timestamp) {
            ordDate = (d['date'] as Timestamp).toDate();
          } else if (d['date'] is String) {
            ordDate = DateTime.tryParse(d['date']) ?? DateTime.now();
          }
        }

         await _db.into(_db.supplierOrders).insert(SupplierOrdersCompanion(
          id: Value(d['id']),
          supplierId: Value(d['supplierId'] ?? ''),
          productId: Value(d['productId'] ?? ''),
          quantityOrdered: Value((d['quantityOrdered'] as num?)?.toDouble() ?? 0.0),
          quantityReceived: Value((d['quantityReceived'] as num?)?.toDouble() ?? 0.0),
          totalCost: Value((d['totalCost'] as num?)?.toDouble() ?? 0.0),
          amountPaid: Value((d['amountPaid'] as num?)?.toDouble() ?? 0.0),
          status: Value(d['status'] ?? 'Pending'),
          date: Value(ordDate),
          unitCost: Value(d['unitCost'] != null ? (d['unitCost'] as num).toDouble() : null),
          pdfUrl: Value(d['pdfUrl']),
        ));
      }

      // DamagedItems
      for (var doc in damagedItemsSnap.docs) {
        final d = doc.data();
        
        DateTime dmgDate = DateTime.now();
        if (d['date'] != null) {
          if (d['date'] is Timestamp) {
            dmgDate = (d['date'] as Timestamp).toDate();
          } else if (d['date'] is String) {
            dmgDate = DateTime.tryParse(d['date']) ?? DateTime.now();
          }
        }

        DateTime? resDate;
        if (d['resolutionDate'] != null) {
          if (d['resolutionDate'] is Timestamp) {
            resDate = (d['resolutionDate'] as Timestamp).toDate();
          } else if (d['resolutionDate'] is String) {
            resDate = DateTime.tryParse(d['resolutionDate']);
          }
        }

        await _db.into(_db.damagedItems).insert(DamagedItemsCompanion(
          id: Value(d['id']),
          supplierId: Value(d['supplierId'] ?? ''),
          productId: Value(d['productId'] ?? ''),
          quantity: Value((d['quantity'] as num?)?.toDouble() ?? 0.0),
          status: Value(d['status'] ?? 'Pending Replacement'),
          notes: Value(d['notes']),
          date: Value(dmgDate),
          resolutionDate: Value(resDate),
          pdfUrl: Value(d['pdfUrl']),
        ));
      }
    });

    _invalidateAllProviders();
  }

  /// Completely clear local SQLite database cache
  Future<void> clearLocalDatabase() async {
    await _db.transaction(() async {
      await _db.delete(_db.categories).go();
      await _db.delete(_db.products).go();
      await _db.delete(_db.suppliers).go();
      await _db.delete(_db.customers).go();
      await _db.delete(_db.sales).go();
      await _db.delete(_db.saleItems).go();
      await _db.delete(_db.purchases).go();
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.stockHistory).go();
      await _db.delete(_db.supplierOrders).go();
      await _db.delete(_db.damagedItems).go();
      await _db.delete(_db.appSettingsTable).go();
    });

    // Delete the local config file and clear memory cache
    final syncService = _ref.read(firebaseSyncServiceProvider);
    await syncService.deleteStoreConfig();

    _invalidateAllProviders();
  }

  /// Invalidate all database-dependent Riverpod providers
  void _invalidateAllProviders() {
    _ref.invalidate(settingsControllerProvider);
    _ref.invalidate(allActiveProductsProvider);
    _ref.invalidate(productsListProvider);
    _ref.invalidate(dashboardMetricsProvider);
    _ref.invalidate(categoriesControllerProvider);
    _ref.invalidate(suppliersControllerProvider);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AdminRepository(db, ref);
});
