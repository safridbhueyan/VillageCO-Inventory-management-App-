import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get brand => text().nullable()();
  RealColumn get buyingPrice => real()();
  RealColumn get sellingPrice => real()();
  RealColumn get currentStock => real()();
  RealColumn get minimumStock => real()();
  TextColumn get unit => text()();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get imagePath => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get imagePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real()();
  RealColumn get total => real()();
  TextColumn get paymentMethod => text()(); // 'Cash', 'Mobile Banking', 'Card'
  TextColumn get customerId => text().nullable().references(Customers, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get cost => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get cost => real()();
  RealColumn get quantity => real()();
  TextColumn get invoiceNo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()(); // 'Rent', 'Electricity', etc.
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class StockHistory extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get changeAmount => real()();
  TextColumn get reason => text()(); // 'Stock In', 'Stock Out', 'Adjust Stock', 'Sale'
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  DateTimeColumn get date => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get shopName => text().withDefault(const Constant('VillageCO Inventory'))();
  TextColumn get shopLogo => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get language => text().withDefault(const Constant('en'))();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  TextColumn get adminPin => text().withDefault(const Constant('1234'))();
  BoolColumn get isDarkMode => boolean().withDefault(const Constant(false))();
  TextColumn get pdfSavePath => text().nullable()();
  TextColumn get csvSavePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SupplierOrders extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantityOrdered => real()();
  RealColumn get quantityReceived => real().withDefault(const Constant(0.0))();
  RealColumn get totalCost => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => text().withDefault(const Constant('Pending'))(); // 'Pending', 'Partially Received', 'Received'
  RealColumn get unitCost => real().nullable()();
  TextColumn get pdfUrl => text().nullable()();
  TextColumn get chalanPic => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DamagedItems extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  TextColumn get status => text().withDefault(const Constant('Pending Replacement'))(); // 'Pending Replacement', 'Replaced', 'Refunded', 'Pending Refund'
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get resolutionDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get pdfUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SalesReturns extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get refundAmount => real()();
  TextColumn get reason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SalesReturnItems extends Table {
  TextColumn get id => text()();
  TextColumn get returnId => text().references(SalesReturns, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get cost => real()();
  BoolColumn get isRestocked => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class SupplierPayments extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get orderId => text().nullable().references(SupplierOrders, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Categories,
  Products,
  Suppliers,
  Customers,
  Sales,
  SaleItems,
  Purchases,
  Expenses,
  StockHistory,
  AppSettingsTable,
  SupplierOrders,
  DamagedItems,
  SalesReturns,
  SalesReturnItems,
  SupplierPayments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(appSettingsTable, appSettingsTable.pdfSavePath);
            await migrator.addColumn(appSettingsTable, appSettingsTable.csvSavePath);
          }
          if (from < 3) {
            await migrator.createTable(supplierOrders);
            await migrator.createTable(damagedItems);
          }
          if (from < 4) {
            await migrator.createTable(salesReturns);
            await migrator.createTable(salesReturnItems);
          }
          if (from < 5) {
            await migrator.addColumn(products, products.batchNumber);
            await migrator.addColumn(products, products.expiryDate);
          }
          if (from < 6) {
            await migrator.addColumn(products, products.createdAt);
          }
          if (from < 7) {
            await migrator.addColumn(supplierOrders, supplierOrders.unitCost);
            await migrator.addColumn(supplierOrders, supplierOrders.pdfUrl);
          }
          if (from < 8) {
            await migrator.addColumn(damagedItems, damagedItems.pdfUrl);
          }
          if (from < 9) {
            await migrator.createTable(supplierPayments);
          }
          if (from < 10) {
            await migrator.addColumn(suppliers, suppliers.imagePath);
            await migrator.addColumn(supplierOrders, supplierOrders.chalanPic);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'villageco_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
