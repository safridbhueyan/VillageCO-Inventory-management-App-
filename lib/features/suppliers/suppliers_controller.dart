import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/firebase_sync_service.dart';
import '../products/products_controller.dart';
import '../settings/settings_controller.dart';

class SuppliersController extends AsyncNotifier<List<Supplier>> {
  late AppDatabase _db;

  @override
  Future<List<Supplier>> build() async {
    _db = ref.watch(databaseProvider);
    return _fetchSuppliers();
  }

  Future<List<Supplier>> _fetchSuppliers() async {
    return _db.select(_db.suppliers).get();
  }

  Future<void> addSupplier(String name, String phone, String? email, String? address) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final companion = SuppliersCompanion(
        id: Value(const Uuid().v4()),
        name: Value(name),
        phone: Value(phone),
        email: Value(email),
        address: Value(address),
      );
      await _db.into(_db.suppliers).insert(companion);
      triggerAutoSync(ref);
      return _fetchSuppliers();
    });
  }

  Future<void> updateSupplier(String id, String name, String phone, String? email, String? address) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await (_db.update(_db.suppliers)..where((t) => t.id.equals(id))).write(
        SuppliersCompanion(
          name: Value(name),
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
        ),
      );
      triggerAutoSync(ref);
      return _fetchSuppliers();
    });
  }

  Future<void> deleteSupplier(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Set supplierId to null for all products referencing this supplier
      await (_db.update(_db.products)..where((t) => t.supplierId.equals(id))).write(
        const ProductsCompanion(supplierId: Value(null)),
      );
      
      await (_db.delete(_db.suppliers)..where((t) => t.id.equals(id))).go();
      triggerAutoSync(ref);
      return _fetchSuppliers();
    });
  }

  Future<void> addSupplierOrder({
    required String supplierId,
    required String productId,
    required double qtyOrdered,
    required double qtyReceived,
    required double totalCost,
    required double amtPaid,
    required DateTime date,
    required String status,
    double? newBuyingPrice,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final orderId = const Uuid().v4();
      final companion = SupplierOrdersCompanion(
        id: Value(orderId),
        supplierId: Value(supplierId),
        productId: Value(productId),
        quantityOrdered: Value(qtyOrdered),
        quantityReceived: Value(qtyReceived),
        totalCost: Value(totalCost),
        amountPaid: Value(amtPaid),
        date: Value(date),
        status: Value(status),
        unitCost: Value(newBuyingPrice),
      );
      await _db.into(_db.supplierOrders).insert(companion);

      final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
      
      // Update stock and buying price in products table if we are receiving stock now
      final newStock = product.currentStock + qtyReceived;
      await (_db.update(_db.products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          currentStock: Value(newStock),
          buyingPrice: (qtyReceived > 0 && newBuyingPrice != null) ? Value(newBuyingPrice) : const Value.absent(),
        ),
      );

      if (qtyReceived > 0) {
        await _db.into(_db.stockHistory).insert(
          StockHistoryCompanion(
            id: Value(const Uuid().v4()),
            productId: Value(productId),
            changeAmount: Value(qtyReceived),
            reason: Value('Supplier Order (New)'),
            supplierId: Value(supplierId),
            date: Value(DateTime.now()),
          ),
        );
      }

      // Trigger background PDF generation and upload/sync!
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(supplierId))).getSingle();
      final updatedProduct = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
      final createdOrder = await (_db.select(_db.supplierOrders)..where((t) => t.id.equals(orderId))).getSingle();

      if (settings != null) {
        ref.read(firebaseSyncServiceProvider).syncSupplierOrderOnComplete(
          order: createdOrder,
          supplier: supplier,
          product: updatedProduct,
          settings: settings,
        ).catchError((e) {
          debugPrint('Failed to sync supplier order: $e');
        });
      }

      ref.invalidate(productsListProvider);
      ref.invalidate(allActiveProductsProvider);
      ref.invalidate(supplierOrdersProvider(supplierId));
      triggerAutoSync(ref);
      return _fetchSuppliers();
    });
  }

  Future<void> updateSupplierOrderPaidAndReceived({
    required String orderId,
    required String supplierId,
    required double addedReceived,
    required double addedPaid,
    required String status,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final existing = await (_db.select(_db.supplierOrders)..where((t) => t.id.equals(orderId))).getSingle();
      final updatedReceived = existing.quantityReceived + addedReceived;
      final updatedPaid = existing.amountPaid + addedPaid;
      
      await (_db.update(_db.supplierOrders)..where((t) => t.id.equals(orderId))).write(
        SupplierOrdersCompanion(
          quantityReceived: Value(updatedReceived),
          amountPaid: Value(updatedPaid),
          status: Value(status),
        ),
      );

      final product = await (_db.select(_db.products)..where((t) => t.id.equals(existing.productId))).getSingle();

      if (addedReceived > 0) {
        final newStock = product.currentStock + addedReceived;
        
        // If order had a custom unit cost, we update the product's buyingPrice now since we are receiving the stock!
        await (_db.update(_db.products)..where((t) => t.id.equals(existing.productId))).write(
          ProductsCompanion(
            currentStock: Value(newStock),
            buyingPrice: existing.unitCost != null ? Value(existing.unitCost!) : const Value.absent(),
          ),
        );

        await _db.into(_db.stockHistory).insert(
          StockHistoryCompanion(
            id: Value(const Uuid().v4()),
            productId: Value(existing.productId),
            changeAmount: Value(addedReceived),
            reason: Value('Supplier Order (Update)'),
            supplierId: Value(supplierId),
            date: Value(DateTime.now()),
          ),
        );
      }

      // Trigger background PDF generation and upload/sync!
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(supplierId))).getSingle();
      final updatedProduct = await (_db.select(_db.products)..where((t) => t.id.equals(existing.productId))).getSingle();
      final updatedOrder = await (_db.select(_db.supplierOrders)..where((t) => t.id.equals(orderId))).getSingle();

      if (settings != null) {
        ref.read(firebaseSyncServiceProvider).syncSupplierOrderOnComplete(
          order: updatedOrder,
          supplier: supplier,
          product: updatedProduct,
          settings: settings,
        ).catchError((e) {
          debugPrint('Failed to sync updated supplier order: $e');
        });
      }

      ref.invalidate(productsListProvider);
      ref.invalidate(allActiveProductsProvider);
      ref.invalidate(supplierOrdersProvider(supplierId));
      triggerAutoSync(ref);
      return _fetchSuppliers();
    });
  }

  Future<void> addDamagedItem({
    required String supplierId,
    required String productId,
    required double quantity,
    required String status,
    required String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final damageId = const Uuid().v4();
      final companion = DamagedItemsCompanion(
        id: Value(damageId),
        supplierId: Value(supplierId),
        productId: Value(productId),
        quantity: Value(quantity),
        status: Value(status),
        notes: Value(notes),
        date: Value(DateTime.now()),
      );
      await _db.into(_db.damagedItems).insert(companion);

      final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
      final isInitialReplaced = status == 'Replaced';

      if (!isInitialReplaced) {
        final newStock = product.currentStock - quantity;
        await (_db.update(_db.products)..where((t) => t.id.equals(productId))).write(
          ProductsCompanion(currentStock: Value(newStock)),
        );

        await _db.into(_db.stockHistory).insert(
          StockHistoryCompanion(
            id: Value(const Uuid().v4()),
            productId: Value(productId),
            changeAmount: Value(-quantity),
            reason: Value('Damaged Item Logged'),
            supplierId: Value(supplierId),
            date: Value(DateTime.now()),
          ),
        );
      }

      // Trigger background PDF generation and upload/sync!
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(supplierId))).getSingle();
      final updatedProduct = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
      final createdDamage = await (_db.select(_db.damagedItems)..where((t) => t.id.equals(damageId))).getSingle();

      if (settings != null) {
        ref.read(firebaseSyncServiceProvider).syncDamagedItemOnComplete(
          damage: createdDamage,
          supplier: supplier,
          product: updatedProduct,
          settings: settings,
        ).catchError((e) {
          debugPrint('Failed to sync damaged item: $e');
        });
      }

      ref.invalidate(productsListProvider);
      ref.invalidate(allActiveProductsProvider);
      ref.invalidate(supplierDamagesProvider(supplierId));
      triggerAutoSync(ref);
      return _fetchSuppliers();
    });
  }

  Future<void> updateDamagedItemStatus({
    required String id,
    required String supplierId,
    required String status,
    DateTime? resolutionDate,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final oldDamage = await (_db.select(_db.damagedItems)..where((t) => t.id.equals(id))).getSingle();
      final oldStatus = oldDamage.status;

      await (_db.update(_db.damagedItems)..where((t) => t.id.equals(id))).write(
        DamagedItemsCompanion(
          status: Value(status),
          resolutionDate: Value(resolutionDate),
          notes: notes != null ? Value(notes) : const Value.absent(),
        ),
      );

      final product = await (_db.select(_db.products)..where((t) => t.id.equals(oldDamage.productId))).getSingle();

      // If transition is to Replaced: increase stock (since supplier replaced items)
      if (status == 'Replaced' && oldStatus != 'Replaced') {
        final newStock = product.currentStock + oldDamage.quantity;
        await (_db.update(_db.products)..where((t) => t.id.equals(oldDamage.productId))).write(
          ProductsCompanion(currentStock: Value(newStock)),
        );
        await _db.into(_db.stockHistory).insert(
          StockHistoryCompanion(
            id: Value(const Uuid().v4()),
            productId: Value(oldDamage.productId),
            changeAmount: Value(oldDamage.quantity),
            reason: Value('Damaged Item Replaced'),
            supplierId: Value(supplierId),
            date: Value(DateTime.now()),
          ),
        );
      } 
      // If transition is away from Replaced: decrease stock (undo)
      else if (status != 'Replaced' && oldStatus == 'Replaced') {
        final newStock = product.currentStock - oldDamage.quantity;
        await (_db.update(_db.products)..where((t) => t.id.equals(oldDamage.productId))).write(
          ProductsCompanion(currentStock: Value(newStock)),
        );
        await _db.into(_db.stockHistory).insert(
          StockHistoryCompanion(
            id: Value(const Uuid().v4()),
            productId: Value(oldDamage.productId),
            changeAmount: Value(-oldDamage.quantity),
            reason: Value('Reverted Damaged Replacement'),
            supplierId: Value(supplierId),
            date: Value(DateTime.now()),
          ),
        );
      }

      // Trigger background PDF generation and upload/sync!
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(supplierId))).getSingle();
      final updatedDamage = await (_db.select(_db.damagedItems)..where((t) => t.id.equals(id))).getSingle();
      final updatedProduct = await (_db.select(_db.products)..where((t) => t.id.equals(updatedDamage.productId))).getSingle();

      if (settings != null) {
        ref.read(firebaseSyncServiceProvider).syncDamagedItemOnComplete(
          damage: updatedDamage,
          supplier: supplier,
          product: updatedProduct,
          settings: settings,
        ).catchError((e) {
          debugPrint('Failed to sync updated damaged item: $e');
        });
      }

      ref.invalidate(productsListProvider);
      ref.invalidate(allActiveProductsProvider);
      ref.invalidate(supplierDamagesProvider(supplierId));
      triggerAutoSync(ref);
      return _fetchSuppliers();
    });
  }
}

final suppliersControllerProvider = AsyncNotifierProvider<SuppliersController, List<Supplier>>(() {
  return SuppliersController();
});

// Products associated with a supplier
final productsBySupplierProvider = FutureProvider.family<List<Product>, String>((ref, supplierId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.products)..where((t) => t.supplierId.equals(supplierId) & t.isArchived.equals(false))).get();
});

// Supplier purchase history provider
final supplierPurchasesProvider = FutureProvider.family<List<Purchase>, String>((ref, supplierId) async {
  final db = ref.watch(databaseProvider);
  final list = await (db.select(db.purchases)..where((t) => t.supplierId.equals(supplierId))).get();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
});

// Supplier orders provider
final supplierOrdersProvider = FutureProvider.family<List<SupplierOrder>, String>((ref, supplierId) async {
  final db = ref.watch(databaseProvider);
  final list = await (db.select(db.supplierOrders)..where((t) => t.supplierId.equals(supplierId))).get();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
});

// Supplier damages provider
final supplierDamagesProvider = FutureProvider.family<List<DamagedItem>, String>((ref, supplierId) async {
  final db = ref.watch(databaseProvider);
  final list = await (db.select(db.damagedItems)..where((t) => t.supplierId.equals(supplierId))).get();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
});
