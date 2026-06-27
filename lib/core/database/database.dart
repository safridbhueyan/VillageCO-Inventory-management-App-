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

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();

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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'villageco_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
