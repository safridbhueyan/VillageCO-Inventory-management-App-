import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../products/products_controller.dart';

class CartItem {
  final Product product;
  final double quantity;
  final double customPrice;

  CartItem({
    required this.product,
    this.quantity = 1.0,
    required this.customPrice,
  });

  double get subtotal => quantity * customPrice;
  double get totalBuyingCost => quantity * product.buyingPrice;

  CartItem copyWith({
    Product? product,
    double? quantity,
    double? customPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      customPrice: customPrice ?? this.customPrice,
    );
  }
}

class PosCartState {
  final List<CartItem> items;
  final double discount;
  final bool isPercentageDiscount;
  final Customer? selectedCustomer;
  final String paymentMethod; // 'Cash', 'Mobile Banking', 'Card'

  PosCartState({
    this.items = const [],
    this.discount = 0.0,
    this.isPercentageDiscount = false,
    this.selectedCustomer,
    this.paymentMethod = 'Cash',
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  
  double get discountAmount {
    if (isPercentageDiscount) {
      return subtotal * (discount / 100.0);
    }
    return discount;
  }

  double get total {
    final net = subtotal - discountAmount;
    return net < 0 ? 0.0 : net;
  }

  double get totalBuyingCost => items.fold(0.0, (sum, item) => sum + item.totalBuyingCost);

  PosCartState copyWith({
    List<CartItem>? items,
    double? discount,
    bool? isPercentageDiscount,
    Customer? selectedCustomer,
    bool clearCustomer = false,
    String? paymentMethod,
  }) {
    return PosCartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      isPercentageDiscount: isPercentageDiscount ?? this.isPercentageDiscount,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class PosCartNotifier extends StateNotifier<PosCartState> {
  final AppDatabase _db;
  final Ref _ref;

  PosCartNotifier(this._db, this._ref) : super(PosCartState());

  void addItem(Product product, {double qty = 1.0}) {
    if (product.currentStock <= 0) {
      return;
    }

    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final existingItem = state.items[existingIndex];
      final updatedQuantity = existingItem.quantity + qty;
      final double finalQty = updatedQuantity > product.currentStock
          ? product.currentStock
          : updatedQuantity;
      
      final updatedList = List<CartItem>.from(state.items);
      updatedList[existingIndex] = existingItem.copyWith(quantity: finalQty);
      state = state.copyWith(items: updatedList);
    } else {
      final double finalQty = qty > product.currentStock ? product.currentStock : qty;
      if (finalQty > 0) {
        final newItem = CartItem(
          product: product,
          quantity: finalQty,
          customPrice: product.sellingPrice,
        );
        state = state.copyWith(items: [...state.items, newItem]);
      }
    }
  }

  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        final double finalQty = quantity > item.product.currentStock
            ? item.product.currentStock
            : quantity;
        return item.copyWith(quantity: finalQty);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items.where((item) => item.product.id != productId).toList(),
    );
  }

  void applyDiscount(double amount, {bool isPercentage = false}) {
    state = state.copyWith(
      discount: amount,
      isPercentageDiscount: isPercentage,
    );
  }

  void setCustomer(Customer? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(selectedCustomer: customer);
    }
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void clearCart() {
    state = PosCartState();
  }

  Future<Sale> completeSale() async {
    if (state.items.isEmpty) {
      throw Exception('Cannot complete sale with an empty cart.');
    }

    final saleId = const Uuid().v4();
    final now = DateTime.now();

    final saleCompanion = SalesCompanion(
      id: Value(saleId),
      date: Value(now),
      subtotal: Value(state.subtotal),
      discount: Value(state.discountAmount),
      total: Value(state.total),
      paymentMethod: Value(state.paymentMethod),
      customerId: Value(state.selectedCustomer?.id),
    );

    await _db.transaction(() async {
      // 1. Insert Sales entry
      await _db.into(_db.sales).insert(saleCompanion);

      // 2. Process each cart item
      for (final item in state.items) {
        final itemId = const Uuid().v4();
        final saleItemCompanion = SaleItemsCompanion(
          id: Value(itemId),
          saleId: Value(saleId),
          productId: Value(item.product.id),
          quantity: Value(item.quantity),
          price: Value(item.customPrice),
          cost: Value(item.product.buyingPrice),
        );
        await _db.into(_db.saleItems).insert(saleItemCompanion);

        // 3. Subtract stock level from Products (fetching latest stock to prevent stale overrides)
        final dbProduct = await (_db.select(_db.products)..where((t) => t.id.equals(item.product.id))).getSingle();
        final newStock = dbProduct.currentStock - item.quantity;
        await (_db.update(_db.products)..where((t) => t.id.equals(item.product.id))).write(
          ProductsCompanion(currentStock: Value(newStock)),
        );

        // 4. Log StockHistory entry (with negative adjustment)
        final historyId = const Uuid().v4();
        final stockHistoryCompanion = StockHistoryCompanion(
          id: Value(historyId),
          productId: Value(item.product.id),
          changeAmount: Value(-item.quantity),
          reason: Value('Sale (${state.paymentMethod})'),
          date: Value(now),
        );
        await _db.into(_db.stockHistory).insert(stockHistoryCompanion);
      }
    });

    // Invalidate product queries to trigger updates
    _ref.invalidate(productsListProvider);

    final completedSale = await (_db.select(_db.sales)..where((t) => t.id.equals(saleId))).getSingle();
    
    // Reset cart state
    clearCart();
    
    return completedSale;
  }
}

final posCartProvider = StateNotifierProvider<PosCartNotifier, PosCartState>((ref) {
  final db = ref.watch(databaseProvider);
  return PosCartNotifier(db, ref);
});
