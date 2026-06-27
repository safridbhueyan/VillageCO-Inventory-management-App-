import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

class CategoriesController extends AsyncNotifier<List<Category>> {
  late final AppDatabase _db;

  @override
  Future<List<Category>> build() async {
    _db = ref.watch(databaseProvider);
    return _db.select(_db.categories).get();
  }

  Future<void> addCategory(String name, String icon, String colorHex) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final companion = CategoriesCompanion(
        id: Value(const Uuid().v4()),
        name: Value(name),
        icon: Value(icon),
        color: Value(colorHex),
      );
      await _db.into(_db.categories).insert(companion);
      return _db.select(_db.categories).get();
    });
  }

  Future<void> updateCategory(String id, String name, String icon, String colorHex) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name),
          icon: Value(icon),
          color: Value(colorHex),
        ),
      );
      return _db.select(_db.categories).get();
    });
  }

  Future<void> deleteCategory(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Set categoryId to null for all products referencing this category
      await (_db.update(_db.products)..where((t) => t.categoryId.equals(id))).write(
        const ProductsCompanion(categoryId: Value(null)),
      );
      
      // Delete category
      await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
      return _db.select(_db.categories).get();
    });
  }
}

final categoriesControllerProvider = AsyncNotifierProvider<CategoriesController, List<Category>>(() {
  return CategoriesController();
});
