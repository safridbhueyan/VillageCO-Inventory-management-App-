import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show leftOuterJoin;

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

class StockHistoryWithDetails {
  final StockHistoryData log;
  final Product product;
  final Supplier? supplier;

  StockHistoryWithDetails({
    required this.log,
    required this.product,
    this.supplier,
  });
}

final stockHistoryListProvider = FutureProvider<List<StockHistoryWithDetails>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final query = db.select(db.stockHistory).join([
    leftOuterJoin(db.products, db.products.id.equalsExp(db.stockHistory.productId)),
    leftOuterJoin(db.suppliers, db.suppliers.id.equalsExp(db.stockHistory.supplierId)),
  ]);

  final rows = await query.get();

  final list = rows.map((row) {
    return StockHistoryWithDetails(
      log: row.readTable(db.stockHistory),
      product: row.readTable(db.products),
      supplier: row.readTableOrNull(db.suppliers),
    );
  }).toList();

  list.sort((a, b) => b.log.date.compareTo(a.log.date));
  return list;
});
