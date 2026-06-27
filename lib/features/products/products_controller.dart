import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

class ProductWithDetails {
  final Product product;
  final Category? category;
  final Supplier? supplier;

  ProductWithDetails({
    required this.product,
    this.category,
    this.supplier,
  });
}

class ProductsFilterState {
  final String searchQuery;
  final String? categoryId;
  final String? stockStatus; // 'Healthy', 'Low', 'Critical', 'OutOfStock'
  final bool favoritesOnly;
  final String sortBy; // 'name_asc', 'name_desc', 'stock_asc', 'stock_desc', 'price_asc', 'price_desc'
  final Set<String> selectedIds;

  ProductsFilterState({
    this.searchQuery = '',
    this.categoryId,
    this.stockStatus,
    this.favoritesOnly = false,
    this.sortBy = 'name_asc',
    Set<String>? selectedIds,
  }) : selectedIds = selectedIds ?? {};

  ProductsFilterState copyWith({
    String? searchQuery,
    String? categoryId,
    String? stockStatus,
    bool? favoritesOnly,
    String? sortBy,
    Set<String>? selectedIds,
  }) {
    return ProductsFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryId: categoryId ?? this.categoryId,
      stockStatus: stockStatus ?? this.stockStatus,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sortBy: sortBy ?? this.sortBy,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

final productsFilterProvider = StateProvider<ProductsFilterState>((ref) {
  return ProductsFilterState();
});

final productsListProvider = FutureProvider<List<ProductWithDetails>>((ref) async {
  final db = ref.watch(databaseProvider);
  final filters = ref.watch(productsFilterProvider);

  final query = db.select(db.products).join([
    leftOuterJoin(db.categories, db.categories.id.equalsExp(db.products.categoryId)),
    leftOuterJoin(db.suppliers, db.suppliers.id.equalsExp(db.products.supplierId)),
  ]);

  // Don't show archived products in standard lists
  query.where(db.products.isArchived.equals(false));

  if (filters.favoritesOnly) {
    query.where(db.products.isFavorite.equals(true));
  }

  if (filters.categoryId != null) {
    query.where(db.products.categoryId.equals(filters.categoryId!));
  }

  if (filters.searchQuery.isNotEmpty) {
    final search = '%${filters.searchQuery.toLowerCase()}%';
    query.where(
      db.products.name.lower().like(search) |
      db.products.brand.lower().like(search) |
      db.products.barcode.lower().like(search)
    );
  }

  final rows = await query.get();
  
  var list = rows.map((row) {
    return ProductWithDetails(
      product: row.readTable(db.products),
      category: row.readTableOrNull(db.categories),
      supplier: row.readTableOrNull(db.suppliers),
    );
  }).toList();

  if (filters.stockStatus != null) {
    list = list.where((item) {
      final status = _getStockStatus(item.product.currentStock, item.product.minimumStock);
      return status.toLowerCase() == filters.stockStatus!.toLowerCase();
    }).toList();
  }

  switch (filters.sortBy) {
    case 'name_asc':
      list.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
      break;
    case 'name_desc':
      list.sort((a, b) => b.product.name.toLowerCase().compareTo(a.product.name.toLowerCase()));
      break;
    case 'stock_asc':
      list.sort((a, b) => a.product.currentStock.compareTo(b.product.currentStock));
      break;
    case 'stock_desc':
      list.sort((a, b) => b.product.currentStock.compareTo(a.product.currentStock));
      break;
    case 'price_asc':
      list.sort((a, b) => a.product.sellingPrice.compareTo(b.product.sellingPrice));
      break;
    case 'price_desc':
      list.sort((a, b) => b.product.sellingPrice.compareTo(a.product.sellingPrice));
      break;
  }

  return list;
});

String _getStockStatus(double current, double min) {
  if (current <= 0) return 'OutOfStock';
  if (current <= min * 0.5) return 'Critical';
  if (current <= min) return 'Low';
  return 'Healthy';
}

final productsRepositoryProvider = Provider((ref) => ProductsRepository(ref.watch(databaseProvider), ref));

class ProductsRepository {
  final AppDatabase _db;
  final Ref _ref;

  ProductsRepository(this._db, this._ref);

  Future<void> addProduct(ProductsCompanion product) async {
    await _db.into(_db.products).insert(product);
    
    if (product.currentStock.present && product.currentStock.value > 0) {
      await _logStockHistory(
        productId: product.id.value,
        changeAmount: product.currentStock.value,
        reason: 'Initial Stock',
        supplierId: product.supplierId.value,
      );
    }
    
    _ref.invalidate(productsListProvider);
  }

  Future<void> updateProduct(String id, ProductsCompanion product) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(product);
    _ref.invalidate(productsListProvider);
  }

  Future<void> deleteProduct(String id) async {
    await (_db.delete(_db.stockHistory)..where((t) => t.productId.equals(id))).go();
    await (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
    _ref.invalidate(productsListProvider);
  }

  Future<void> duplicateProduct(String productId) async {
    final existing = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
    final newId = const Uuid().v4();
    final duplicate = ProductsCompanion(
      id: Value(newId),
      name: Value('${existing.name} (Copy)'),
      barcode: Value(existing.barcode != null ? '${existing.barcode}_copy' : null),
      categoryId: Value(existing.categoryId),
      brand: Value(existing.brand),
      buyingPrice: Value(existing.buyingPrice),
      sellingPrice: Value(existing.sellingPrice),
      currentStock: Value(existing.currentStock),
      minimumStock: Value(existing.minimumStock),
      unit: Value(existing.unit),
      supplierId: Value(existing.supplierId),
      imagePath: Value(existing.imagePath),
      description: Value(existing.description),
      isFavorite: Value(existing.isFavorite),
      isArchived: Value(existing.isArchived),
    );
    await _db.into(_db.products).insert(duplicate);
    
    if (existing.currentStock > 0) {
      await _logStockHistory(
        productId: newId,
        changeAmount: existing.currentStock,
        reason: 'Duplicate Stock Offset',
        supplierId: existing.supplierId,
      );
    }
    _ref.invalidate(productsListProvider);
  }

  Future<void> archiveProduct(String id, bool archive) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(isArchived: Value(archive)),
    );
    _ref.invalidate(productsListProvider);
  }

  Future<void> toggleFavorite(String id, bool favorite) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(isFavorite: Value(favorite)),
    );
    _ref.invalidate(productsListProvider);
  }

  Future<void> bulkDelete(List<String> ids) async {
    await _db.transaction(() async {
      for (final id in ids) {
        await (_db.delete(_db.stockHistory)..where((t) => t.productId.equals(id))).go();
        await (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
      }
    });
    _ref.invalidate(productsListProvider);
  }

  Future<void> bulkStockUpdate(List<String> ids, double adjustmentAmount, String reason) async {
    await _db.transaction(() async {
      for (final id in ids) {
        final product = await (_db.select(_db.products)..where((t) => t.id.equals(id))).getSingle();
        final newStock = product.currentStock + adjustmentAmount;
        await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
          ProductsCompanion(currentStock: Value(newStock)),
        );
        await _logStockHistory(
          productId: id,
          changeAmount: adjustmentAmount,
          reason: reason,
          supplierId: product.supplierId,
        );
      }
    });
    _ref.invalidate(productsListProvider);
  }

  Future<void> adjustStock(String productId, double difference, String reason, {String? supplierId}) async {
    final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
    final newStock = product.currentStock + difference;
    
    await (_db.update(_db.products)..where((t) => t.id.equals(productId))).write(
      ProductsCompanion(currentStock: Value(newStock)),
    );
    await _logStockHistory(
      productId: productId,
      changeAmount: difference,
      reason: reason,
      supplierId: supplierId ?? product.supplierId,
    );
    _ref.invalidate(productsListProvider);
  }

  Future<void> _logStockHistory({
    required String productId,
    required double changeAmount,
    required String reason,
    String? supplierId,
  }) async {
    final entry = StockHistoryCompanion(
      id: Value(const Uuid().v4()),
      productId: Value(productId),
      changeAmount: Value(changeAmount),
      reason: Value(reason),
      supplierId: Value(supplierId),
      date: Value(DateTime.now()),
    );
    await _db.into(_db.stockHistory).insert(entry);
  }
}
