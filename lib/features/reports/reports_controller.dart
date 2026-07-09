import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/firebase_sync_service.dart';

class DashboardMetrics {
  final int totalProducts;
  final int totalCategories;
  final int lowStockProducts;
  final int outOfStockProducts;
  final double todaySales;
  final double monthlySales;
  final double inventoryValue;
  final double totalExpenses;
  final double grossProfit;
  final double netProfit;
  final double todayExpenses;
  final double todayGrossProfit;
  final double todayNetProfit;
  final double totalSales;
  final double todayCOGS;
  final double totalCOGS;

  DashboardMetrics({
    required this.totalProducts,
    required this.totalCategories,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.todaySales,
    required this.monthlySales,
    required this.inventoryValue,
    required this.totalExpenses,
    required this.grossProfit,
    required this.netProfit,
    required this.todayExpenses,
    required this.todayGrossProfit,
    required this.todayNetProfit,
    required this.totalSales,
    required this.todayCOGS,
    required this.totalCOGS,
  });
}

// Chart Data Point
class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint(this.label, this.value);
}

// Sales Filters
class SalesFilterState {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? paymentMethod;
  final String searchQuery;

  SalesFilterState({
    this.startDate,
    this.endDate,
    this.paymentMethod,
    this.searchQuery = '',
  });

  SalesFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? searchQuery,
    bool clearDates = false,
  }) {
    return SalesFilterState(
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final salesFilterProvider = StateProvider<SalesFilterState>((ref) {
  return SalesFilterState();
});

// Providers
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // 1. Products
  final products = await db.select(db.products).get();
  final nonArchivedProducts = products.where((p) => !p.isArchived).toList();
  final lowStock = nonArchivedProducts.where((p) => p.currentStock > 0 && p.currentStock <= p.minimumStock).length;
  final outOfStock = nonArchivedProducts.where((p) => p.currentStock <= 0).length;
  
  // 2. Categories
  final categories = await db.select(db.categories).get();
  
  // 3. Sales & Profits
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);
  
  final sales = await db.select(db.sales).get();
  final saleItems = await db.select(db.saleItems).get();
  final returnsList = await db.select(db.salesReturns).get();
  final returnItems = await db.select(db.salesReturnItems).get();

  double todayReturns = 0;
  double monthlyReturns = 0;
  double totalReturns = 0;
  for (final ret in returnsList) {
    if (ret.date.isAfter(todayStart)) {
      todayReturns += ret.refundAmount;
    }
    if (ret.date.isAfter(monthStart)) {
      monthlyReturns += ret.refundAmount;
    }
    totalReturns += ret.refundAmount;
  }
  
  double todaySales = 0;
  double monthlySales = 0;
  double totalSales = 0;
  for (final sale in sales) {
    if (sale.date.isAfter(todayStart)) {
      todaySales += sale.total;
    }
    if (sale.date.isAfter(monthStart)) {
      monthlySales += sale.total;
    }
    totalSales += sale.total;
  }

  todaySales = todaySales - todayReturns;
  monthlySales = monthlySales - monthlyReturns;
  totalSales = totalSales - totalReturns;

  // Inventory value: Sum of (stock * buyingPrice)
  double invValue = 0;
  for (final p in nonArchivedProducts) {
    if (p.currentStock > 0) {
      invValue += p.currentStock * p.buyingPrice;
    }
  }

  // Expenses
  final expenses = await db.select(db.expenses).get();
  double todayExpenses = 0;
  double totalExpenses = 0;
  for (final exp in expenses) {
    if (exp.date.isAfter(todayStart)) {
      todayExpenses += exp.amount;
    }
    totalExpenses += exp.amount;
  }

  // Maps to associate sales and returns dates
  final saleDateMap = {for (final s in sales) s.id: s.date};
  final returnDateMap = {for (final r in returnsList) r.id: r.date};

  // Gross profit & COGS calculations
  double todayCOGS = 0;
  double totalCOGS = 0;
  double todayGrossProfit = 0;
  double totalGrossProfit = 0;

  for (final item in saleItems) {
    final saleDate = saleDateMap[item.saleId];
    final itemCost = item.cost * item.quantity;
    final profit = (item.price - item.cost) * item.quantity;

    if (saleDate != null && saleDate.isAfter(todayStart)) {
      todayCOGS += itemCost;
      todayGrossProfit += profit;
    }
    totalCOGS += itemCost;
    totalGrossProfit += profit;
  }

  for (final ret in returnItems) {
    final returnDate = returnDateMap[ret.returnId];
    final retCost = ret.isRestocked ? (ret.cost * ret.quantity) : 0.0;
    
    double deduction = 0;
    if (ret.isRestocked) {
      deduction = (ret.price - ret.cost) * ret.quantity;
    } else {
      deduction = ret.price * ret.quantity;
    }

    if (returnDate != null && returnDate.isAfter(todayStart)) {
      todayCOGS -= retCost;
      todayGrossProfit -= deduction;
    }
    totalCOGS -= retCost;
    totalGrossProfit -= deduction;
  }

  double todayNetProfit = todayGrossProfit - todayExpenses;
  double totalNetProfit = totalGrossProfit - totalExpenses;

  return DashboardMetrics(
    totalProducts: nonArchivedProducts.length,
    totalCategories: categories.length,
    lowStockProducts: lowStock,
    outOfStockProducts: outOfStock,
    todaySales: todaySales,
    monthlySales: monthlySales,
    inventoryValue: invValue,
    totalExpenses: totalExpenses,
    grossProfit: totalGrossProfit,
    netProfit: totalNetProfit,
    todayExpenses: todayExpenses,
    todayGrossProfit: todayGrossProfit,
    todayNetProfit: todayNetProfit,
    totalSales: totalSales,
    todayCOGS: todayCOGS,
    totalCOGS: totalCOGS,
  );
});

// Sales logs with filters
class SaleWithDetails {
  final Sale sale;
  final Customer? customer;
  final List<SaleItemWithProduct> items;

  SaleWithDetails({required this.sale, this.customer, required this.items});
}

class SaleItemWithProduct {
  final SaleItem item;
  final Product product;

  SaleItemWithProduct({required this.item, required this.product});
}

final salesHistoryProvider = FutureProvider<List<SaleWithDetails>>((ref) async {
  final db = ref.watch(databaseProvider);
  final filters = ref.watch(salesFilterProvider);

  // Fetch sales
  final salesQuery = db.select(db.sales);
  final salesList = await salesQuery.get();

  // Fetch all items, products, customers
  final items = await db.select(db.saleItems).get();
  final products = await db.select(db.products).get();
  final customers = await db.select(db.customers).get();

  List<SaleWithDetails> results = [];
  for (final sale in salesList) {
    final customer = customers.where((c) => c.id == sale.customerId).firstOrNull;
    
    final saleItems = items.where((i) => i.saleId == sale.id).map((i) {
      final product = products.where((p) => p.id == i.productId).firstOrNull ??
          Product(
            id: i.productId,
            name: 'অজানা পণ্য (Unknown Product)',
            buyingPrice: i.cost,
            sellingPrice: i.price,
            currentStock: 0,
            minimumStock: 0,
            unit: 'pcs',
            isArchived: true,
            isFavorite: false,
          );
      return SaleItemWithProduct(item: i, product: product);
    }).toList();

    results.add(SaleWithDetails(
      sale: sale,
      customer: customer,
      items: saleItems,
    ));
  }

  // Apply filters in Dart for simplicity and robustness
  if (filters.paymentMethod != null) {
    results = results.where((s) => s.sale.paymentMethod == filters.paymentMethod).toList();
  }

  if (filters.startDate != null) {
    results = results.where((s) => s.sale.date.isAfter(filters.startDate!)).toList();
  }

  if (filters.endDate != null) {
    results = results.where((s) => s.sale.date.isBefore(filters.endDate!)).toList();
  }

  if (filters.searchQuery.isNotEmpty) {
    final query = filters.searchQuery.toLowerCase();
    results = results.where((s) {
      final customerMatch = s.customer?.name.toLowerCase().contains(query) ?? false;
      final saleIdMatch = s.sale.id.toLowerCase().contains(query);
      final productMatch = s.items.any((i) => i.product.name.toLowerCase().contains(query));
      return customerMatch || saleIdMatch || productMatch;
    }).toList();
  }

  // Sort by date descending
  results.sort((a, b) => b.sale.date.compareTo(a.sale.date));

  return results;
});

// Expenses Notifier
class ExpensesController extends AsyncNotifier<List<Expense>> {
  late AppDatabase _db;

  @override
  Future<List<Expense>> build() async {
    _db = ref.watch(databaseProvider);
    return _fetchExpenses();
  }

  Future<List<Expense>> _fetchExpenses() async {
    final list = await _db.select(_db.expenses).get();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> addExpense(String name, double amount, String category, DateTime date, String? description) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final companion = ExpensesCompanion(
        id: Value(const Uuid().v4()),
        name: Value(name),
        amount: Value(amount),
        category: Value(category),
        date: Value(date),
        description: Value(description),
      );
      await _db.into(_db.expenses).insert(companion);
      
      // Invalidate dashboard metrics as well
      ref.invalidate(dashboardMetricsProvider);
      
      triggerAutoSync(ref);
      return _fetchExpenses();
    });
  }

  Future<void> deleteExpense(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
      
      ref.invalidate(dashboardMetricsProvider);
      
      triggerAutoSync(ref);
      return _fetchExpenses();
    });
  }
}

final expensesControllerProvider = AsyncNotifierProvider<ExpensesController, List<Expense>>(() {
  return ExpensesController();
});

// Top Selling Products Provider
class ProductSaleAggregation {
  final Product product;
  final double quantitySold;
  final double totalRevenue;

  ProductSaleAggregation({
    required this.product,
    required this.quantitySold,
    required this.totalRevenue,
  });
}

final topSellingProductsProvider = FutureProvider<List<ProductSaleAggregation>>((ref) async {
  final db = ref.watch(databaseProvider);
  final items = await db.select(db.saleItems).get();
  final products = await db.select(db.products).get();
  final returnItems = await db.select(db.salesReturnItems).get();

  final Map<String, double> quantityMap = {};
  final Map<String, double> revenueMap = {};

  for (final item in items) {
    quantityMap[item.productId] = (quantityMap[item.productId] ?? 0) + item.quantity;
    revenueMap[item.productId] = (revenueMap[item.productId] ?? 0) + (item.price * item.quantity);
  }

  for (final ret in returnItems) {
    quantityMap[ret.productId] = (quantityMap[ret.productId] ?? 0) - ret.quantity;
    revenueMap[ret.productId] = (revenueMap[ret.productId] ?? 0) - (ret.price * ret.quantity);
  }

  final List<ProductSaleAggregation> list = [];
  for (final entry in quantityMap.entries) {
    final product = products.where((p) => p.id == entry.key).firstOrNull;
    if (product != null) {
      list.add(ProductSaleAggregation(
        product: product,
        quantitySold: entry.value,
        totalRevenue: revenueMap[entry.key] ?? 0,
      ));
    }
  }

  // Sort by quantity descending
  list.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
  return list;
});

class SalesReturnItemWithProduct {
  final SalesReturnItem item;
  final Product product;

  SalesReturnItemWithProduct({required this.item, required this.product});
}

class SalesReturnWithDetails {
  final SalesReturn salesReturn;
  final String originalSaleId;
  final List<SalesReturnItemWithProduct> items;

  SalesReturnWithDetails({
    required this.salesReturn,
    required this.originalSaleId,
    required this.items,
  });
}

final returnsHistoryProvider = FutureProvider<List<SalesReturnWithDetails>>((ref) async {
  final db = ref.watch(databaseProvider);

  final returnsList = await db.select(db.salesReturns).get();
  final returnItems = await db.select(db.salesReturnItems).get();
  final products = await db.select(db.products).get();

  // Sort returns by date descending (most recent first)
  returnsList.sort((a, b) => b.date.compareTo(a.date));

  List<SalesReturnWithDetails> results = [];
  for (final ret in returnsList) {
    final itemsMapped = returnItems.where((item) => item.returnId == ret.id).map((item) {
      final product = products.where((p) => p.id == item.productId).firstOrNull ??
          Product(
            id: item.productId,
            name: 'অজানা পণ্য (Unknown Product)',
            buyingPrice: item.cost,
            sellingPrice: item.price,
            currentStock: 0,
            minimumStock: 0,
            unit: 'pcs',
            isArchived: true,
            isFavorite: false,
          );
      return SalesReturnItemWithProduct(item: item, product: product);
    }).toList();

    results.add(SalesReturnWithDetails(
      salesReturn: ret,
      originalSaleId: ret.saleId,
      items: itemsMapped,
    ));
  }

  return results;
});
