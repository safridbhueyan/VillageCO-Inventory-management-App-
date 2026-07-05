import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

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
      
      // Delete supplier
      await (_db.delete(_db.suppliers)..where((t) => t.id.equals(id))).go();
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
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final companion = SupplierOrdersCompanion(
        id: Value(const Uuid().v4()),
        supplierId: Value(supplierId),
        productId: Value(productId),
        quantityOrdered: Value(qtyOrdered),
        quantityReceived: Value(qtyReceived),
        totalCost: Value(totalCost),
        amountPaid: Value(amtPaid),
        date: Value(date),
        status: Value(status),
      );
      await _db.into(_db.supplierOrders).insert(companion);
      ref.invalidate(supplierOrdersProvider(supplierId));
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
      ref.invalidate(supplierOrdersProvider(supplierId));
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
      final companion = DamagedItemsCompanion(
        id: Value(const Uuid().v4()),
        supplierId: Value(supplierId),
        productId: Value(productId),
        quantity: Value(quantity),
        status: Value(status),
        notes: Value(notes),
        date: Value(DateTime.now()),
      );
      await _db.into(_db.damagedItems).insert(companion);
      ref.invalidate(supplierDamagesProvider(supplierId));
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
      await (_db.update(_db.damagedItems)..where((t) => t.id.equals(id))).write(
        DamagedItemsCompanion(
          status: Value(status),
          resolutionDate: Value(resolutionDate),
          notes: notes != null ? Value(notes) : const Value.absent(),
        ),
      );
      ref.invalidate(supplierDamagesProvider(supplierId));
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
