import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

class SuppliersController extends AsyncNotifier<List<Supplier>> {
  late final AppDatabase _db;

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
}

final suppliersControllerProvider = AsyncNotifierProvider<SuppliersController, List<Supplier>>(() {
  return SuppliersController();
});

// Purchases associated with a supplier
class PurchaseWithProduct {
  final Purchase purchase;
  final Product product;

  PurchaseWithProduct({required this.purchase, required this.product});
}

// Supplier purchase history provider
final supplierPurchasesProvider = FutureProvider.family<List<Purchase>, String>((ref, supplierId) async {
  final db = ref.watch(databaseProvider);
  final list = await (db.select(db.purchases)..where((t) => t.supplierId.equals(supplierId))).get();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
});
