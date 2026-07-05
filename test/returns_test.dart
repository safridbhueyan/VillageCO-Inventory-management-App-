import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';
import 'package:villageco/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Test Return items restocked path', () async {
    final now = DateTime.now();
    final productId = const Uuid().v4();

    // 1. Insert product
    await db.into(db.products).insert(
      ProductsCompanion(
        id: Value(productId),
        name: const Value('Coke'),
        buyingPrice: const Value(50.0),
        sellingPrice: const Value(60.0),
        currentStock: const Value(20.0),
        minimumStock: const Value(5.0),
        unit: const Value('pcs'),
      ),
    );

    // 2. Perform a sale of 2 units
    final saleId = const Uuid().v4();
    await db.into(db.sales).insert(
      SalesCompanion(
        id: Value(saleId),
        date: Value(now),
        subtotal: const Value(120.0),
        discount: const Value(0.0),
        total: const Value(120.0),
        paymentMethod: const Value('Cash'),
      ),
    );

    await db.into(db.saleItems).insert(
      SaleItemsCompanion(
        id: Value(const Uuid().v4()),
        saleId: Value(saleId),
        productId: Value(productId),
        quantity: const Value(2.0),
        price: const Value(60.0),
        cost: const Value(50.0),
      ),
    );

    // Update stock levels
    await (db.update(db.products)..where((t) => t.id.equals(productId))).write(
      const ProductsCompanion(currentStock: Value(18.0)),
    );

    // 3. Perform a return of 2 units (RESTOCKED)
    final returnId = const Uuid().v4();
    await db.into(db.salesReturns).insert(
      SalesReturnsCompanion(
        id: Value(returnId),
        saleId: Value(saleId),
        date: Value(now),
        refundAmount: const Value(120.0),
        reason: const Value('Changed mind'),
      ),
    );

    await db.into(db.salesReturnItems).insert(
      SalesReturnItemsCompanion(
        id: Value(const Uuid().v4()),
        returnId: Value(returnId),
        productId: Value(productId),
        quantity: const Value(2.0),
        price: const Value(60.0),
        cost: const Value(50.0),
        isRestocked: const Value(true),
      ),
    );

    // Update stock levels due to restock
    final prod = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
    final updatedStock = prod.currentStock + 2.0;
    await (db.update(db.products)..where((t) => t.id.equals(productId))).write(
      ProductsCompanion(currentStock: Value(updatedStock)),
    );

    // 4. Verify stock returned to 20.0
    final checkProd = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
    expect(checkProd.currentStock, 20.0);
  });

  test('Test Return items wasted/damaged path', () async {
    final now = DateTime.now();
    final productId = const Uuid().v4();

    // 1. Insert product
    await db.into(db.products).insert(
      ProductsCompanion(
        id: Value(productId),
        name: const Value('Sprite'),
        buyingPrice: const Value(50.0),
        sellingPrice: const Value(60.0),
        currentStock: const Value(20.0),
        minimumStock: const Value(5.0),
        unit: const Value('pcs'),
      ),
    );

    // 2. Perform a sale of 2 units
    final saleId = const Uuid().v4();
    await db.into(db.sales).insert(
      SalesCompanion(
        id: Value(saleId),
        date: Value(now),
        subtotal: const Value(120.0),
        discount: const Value(0.0),
        total: const Value(120.0),
        paymentMethod: const Value('Cash'),
      ),
    );

    await db.into(db.saleItems).insert(
      SaleItemsCompanion(
        id: Value(const Uuid().v4()),
        saleId: Value(saleId),
        productId: Value(productId),
        quantity: const Value(2.0),
        price: const Value(60.0),
        cost: const Value(50.0),
      ),
    );

    // Update stock levels
    await (db.update(db.products)..where((t) => t.id.equals(productId))).write(
      const ProductsCompanion(currentStock: Value(18.0)),
    );

    // 3. Perform a return of 2 units (WASTED / NOT RESTOCKED)
    final returnId = const Uuid().v4();
    await db.into(db.salesReturns).insert(
      SalesReturnsCompanion(
        id: Value(returnId),
        saleId: Value(saleId),
        date: Value(now),
        refundAmount: const Value(120.0),
      ),
    );

    await db.into(db.salesReturnItems).insert(
      SalesReturnItemsCompanion(
        id: Value(const Uuid().v4()),
        returnId: Value(returnId),
        productId: Value(productId),
        quantity: const Value(2.0),
        price: const Value(60.0),
        cost: const Value(50.0),
        isRestocked: const Value(false),
      ),
    );

    // Stock should NOT be incremented because isRestocked is false
    final checkProd = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
    expect(checkProd.currentStock, 18.0);
  });
}
