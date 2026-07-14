import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/firebase_sync_service.dart';
import '../settings/settings_controller.dart';

class SupplyChainOrder {
  final String id;
  final String fromStoreId;
  final String fromStoreName;
  final String toStoreId;
  final String toStoreName;
  final String productId;
  final String productName;
  final String productBarcode;
  final String productBrand;
  final String productUnit;
  final double productBuyingPrice;
  final double productSellingPrice;
  final String productCategoryName;
  final String productDescription;
  final double quantityRequested;
  final double quantitySent;
  final double quantityReceived;
  final double totalPrice;
  final double amountPaid;
  final double paymentDue;
  final String paymentStatus; // 'Unpaid', 'Partially Paid', 'Paid'
  final String status; // 'Pending Approval', 'Approved', 'Rejected'
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool approvedByAdmin;
  final DateTime? approvedAt;

  SupplyChainOrder({
    required this.id,
    required this.fromStoreId,
    required this.fromStoreName,
    required this.toStoreId,
    required this.toStoreName,
    required this.productId,
    required this.productName,
    required this.productBarcode,
    required this.productBrand,
    required this.productUnit,
    required this.productBuyingPrice,
    required this.productSellingPrice,
    required this.productCategoryName,
    required this.productDescription,
    required this.quantityRequested,
    required this.quantitySent,
    required this.quantityReceived,
    required this.totalPrice,
    required this.amountPaid,
    required this.paymentDue,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.approvedByAdmin,
    this.approvedAt,
  });

  factory SupplyChainOrder.fromJson(Map<String, dynamic> json, String docId) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    final double qtyReq = (json['quantityRequested'] as num?)?.toDouble() ?? 0.0;
    final double qtySent = (json['quantitySent'] as num?)?.toDouble() ?? 0.0;
    final double qtyRec = (json['quantityReceived'] as num?)?.toDouble() ?? 0.0;
    final double total = (json['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final double paid = (json['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final double due = (json['paymentDue'] as num?)?.toDouble() ?? 0.0;

    return SupplyChainOrder(
      id: docId,
      fromStoreId: json['fromStoreId'] ?? '',
      fromStoreName: json['fromStoreName'] ?? '',
      toStoreId: json['toStoreId'] ?? '',
      toStoreName: json['toStoreName'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      productBarcode: json['productBarcode'] ?? '',
      productBrand: json['productBrand'] ?? '',
      productUnit: json['productUnit'] ?? '',
      productBuyingPrice: (json['productBuyingPrice'] as num?)?.toDouble() ?? 0.0,
      productSellingPrice: (json['productSellingPrice'] as num?)?.toDouble() ?? 0.0,
      productCategoryName: json['productCategoryName'] ?? '',
      productDescription: json['productDescription'] ?? '',
      quantityRequested: qtyReq,
      quantitySent: qtySent,
      quantityReceived: qtyRec,
      totalPrice: total,
      amountPaid: paid,
      paymentDue: due,
      paymentStatus: json['paymentStatus'] ?? 'Unpaid',
      status: json['status'] ?? 'Pending Approval',
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      approvedByAdmin: json['approvedByAdmin'] ?? false,
      approvedAt: json['approvedAt'] != null ? parseDate(json['approvedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromStoreId': fromStoreId,
      'fromStoreName': fromStoreName,
      'toStoreId': toStoreId,
      'toStoreName': toStoreName,
      'productId': productId,
      'productName': productName,
      'productBarcode': productBarcode,
      'productBrand': productBrand,
      'productUnit': productUnit,
      'productBuyingPrice': productBuyingPrice,
      'productSellingPrice': productSellingPrice,
      'productCategoryName': productCategoryName,
      'productDescription': productDescription,
      'quantityRequested': quantityRequested,
      'quantitySent': quantitySent,
      'quantityReceived': quantityReceived,
      'totalPrice': totalPrice,
      'amountPaid': amountPaid,
      'paymentDue': paymentDue,
      'paymentStatus': paymentStatus,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'approvedByAdmin': approvedByAdmin,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    };
  }
}

// Current Branch Info Provider (Fetches docId and shopID of currently active local branch)
final currentBranchInfoProvider = FutureProvider<Map<String, String>>((ref) async {
  final syncService = ref.read(firebaseSyncServiceProvider);
  final settingsAsync = await ref.watch(settingsControllerProvider.future);
  return syncService.getStoreDocIdAndShopID(settingsAsync.shopName);
});

// Stream Provider for other stores/branches in Firestore
final otherBranchesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentBranchAsync = ref.watch(currentBranchInfoProvider);
  return currentBranchAsync.when(
    data: (info) {
      final currentDocId = info['storeDocId'] ?? '';
      return FirebaseFirestore.instance
          .collection('stores')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .where((doc) => doc.id != currentDocId)
                .map((doc) => {
                      'storeDocId': doc.id,
                      'shopName': doc.data()['shopName'] ?? 'Unnamed Shop',
                      'shopID': doc.data()['shopID'] ?? '',
                    })
                .toList();
          });
    },
    loading: () => Stream.value([]),
    error: (e, s) => Stream.value([]),
  );
});

// Stream Provider for products from a selected other store
final branchProductsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, branchDocId) {
  if (branchDocId.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('stores')
      .doc(branchDocId)
      .collection('products')
      .where('isArchived', isEqualTo: false)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'barcode': data['barcode'] ?? '',
            'brand': data['brand'] ?? '',
            'unit': data['unit'] ?? 'pcs',
            'buyingPrice': (data['buyingPrice'] as num?)?.toDouble() ?? 0.0,
            'sellingPrice': (data['sellingPrice'] as num?)?.toDouble() ?? 0.0,
            'currentStock': (data['currentStock'] as num?)?.toDouble() ?? 0.0,
            'description': data['description'] ?? '',
            'categoryName': data['categoryName'] ?? '',
          };
        }).toList();
      });
});

// Stream Provider for all Supply Chain Orders involving the current branch
final supplyChainOrdersProvider = StreamProvider<List<SupplyChainOrder>>((ref) {
  final currentBranchAsync = ref.watch(currentBranchInfoProvider);
  return currentBranchAsync.when(
    data: (info) {
      final currentDocId = info['storeDocId'] ?? '';
      if (currentDocId.isEmpty) return Stream.value([]);

      return FirebaseFirestore.instance
          .collection('supply_chain_orders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => SupplyChainOrder.fromJson(doc.data(), doc.id))
                .where((order) =>
                    order.fromStoreId == currentDocId || order.toStoreId == currentDocId)
                .toList();
          });
    },
    loading: () => Stream.value([]),
    error: (e, s) => Stream.value([]),
  );
});

// Stream Provider for ALL Supply Chain Orders (used by Super Admin)
final allSupplyChainOrdersProvider = StreamProvider<List<SupplyChainOrder>>((ref) {
  return FirebaseFirestore.instance
      .collection('supply_chain_orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => SupplyChainOrder.fromJson(doc.data(), doc.id))
            .toList();
      });
});

// Supply Chain Service class to trigger operations
class SupplyChainService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Place a product request to another branch
  Future<void> createRequest({
    required Map<String, String> currentBranchInfo,
    required String currentBranchName,
    required String targetBranchDocId,
    required String targetBranchName,
    required Map<String, dynamic> productData,
    required double quantityRequested,
  }) async {
    final docId = const Uuid().v4();
    final currentDocId = currentBranchInfo['storeDocId']!;
    final unitPrice = (productData['sellingPrice'] as num).toDouble();
    final totalPrice = quantityRequested * unitPrice;

    final newOrder = SupplyChainOrder(
      id: docId,
      fromStoreId: currentDocId,
      fromStoreName: currentBranchName,
      toStoreId: targetBranchDocId,
      toStoreName: targetBranchName,
      productId: productData['id'],
      productName: productData['name'],
      productBarcode: productData['barcode'],
      productBrand: productData['brand'],
      productUnit: productData['unit'],
      productBuyingPrice: (productData['buyingPrice'] as num).toDouble(),
      productSellingPrice: unitPrice,
      productCategoryName: productData['categoryName'],
      productDescription: productData['description'],
      quantityRequested: quantityRequested,
      quantitySent: 0.0,
      quantityReceived: 0.0,
      totalPrice: totalPrice,
      amountPaid: 0.0,
      paymentDue: totalPrice,
      paymentStatus: 'Unpaid',
      status: 'Pending Approval',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      approvedByAdmin: false,
    );

    await _firestore.collection('supply_chain_orders').doc(docId).set(newOrder.toJson());
  }

  /// Update the payment amount on a supply chain order
  Future<void> updatePayment(String orderId, double amountPaid) async {
    final orderDoc = await _firestore.collection('supply_chain_orders').doc(orderId).get();
    if (!orderDoc.exists) return;

    final data = orderDoc.data()!;
    final double totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
    
    final newAmountPaid = amountPaid;
    final newPaymentDue = totalPrice - newAmountPaid;
    
    String paymentStatus = 'Unpaid';
    if (newAmountPaid >= totalPrice) {
      paymentStatus = 'Paid';
    } else if (newAmountPaid > 0) {
      paymentStatus = 'Partially Paid';
    }

    await _firestore.collection('supply_chain_orders').doc(orderId).update({
      'amountPaid': newAmountPaid,
      'paymentDue': newPaymentDue,
      'paymentStatus': paymentStatus,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Super Admin: Approve a request, deduct from supplying store, add/create in requesting store
  Future<void> approveRequest(String orderId, double quantitySent, double quantityReceived) async {
    final orderDoc = await _firestore.collection('supply_chain_orders').doc(orderId).get();
    if (!orderDoc.exists) return;

    final order = SupplyChainOrder.fromJson(orderDoc.data()!, orderDoc.id);
    if (order.approvedByAdmin) return; // Already approved

    // Perform atomic transaction
    await _firestore.runTransaction((transaction) async {
      // 1. Update the supplying store's stock
      final supplyingProductRef = _firestore
          .collection('stores')
          .doc(order.toStoreId)
          .collection('products')
          .doc(order.productId);

      final supplyingProductSnap = await transaction.get(supplyingProductRef);
      if (supplyingProductSnap.exists) {
        final currentStock = (supplyingProductSnap.data()?['currentStock'] as num?)?.toDouble() ?? 0.0;
        final newStock = currentStock - quantitySent;
        
        transaction.update(supplyingProductRef, {
          'currentStock': newStock,
          'quantity': newStock,
        });

        // Also update inventoryDetails subcollection
        final supplyingInvRef = _firestore
            .collection('stores')
            .doc(order.toStoreId)
            .collection('inventoryDetails')
            .doc(order.productId);
        transaction.set(supplyingInvRef, {
          'quantity': newStock,
        }, SetOptions(merge: true));

        // Create stockHistory in supplying store
        final supplyingHistId = const Uuid().v4();
        final supplyingHistRef = _firestore
            .collection('stores')
            .doc(order.toStoreId)
            .collection('stockHistory')
            .doc(supplyingHistId);

        transaction.set(supplyingHistRef, {
          'id': supplyingHistId,
          'productId': order.productId,
          'changeAmount': -quantitySent,
          'reason': 'সাপ্লাই চেইন রপ্তানি',
          'date': Timestamp.now(),
        });
      }

      // 2. Update/Create the requesting store's stock
      final requestingProductsColl = _firestore
          .collection('stores')
          .doc(order.fromStoreId)
          .collection('products');

      final barcodeQuery = await requestingProductsColl
          .where('barcode', isEqualTo: order.productBarcode)
          .where('isArchived', isEqualTo: false)
          .get();

      String targetProductId = '';
      if (barcodeQuery.docs.isNotEmpty) {
        // Product exists in requesting branch, increment stock
        final doc = barcodeQuery.docs.first;
        targetProductId = doc.id;
        final currentStock = (doc.data()['currentStock'] as num?)?.toDouble() ?? 0.0;
        final newStock = currentStock + quantityReceived;

        transaction.update(doc.reference, {
          'currentStock': newStock,
          'quantity': newStock,
        });

        // Update inventoryDetails subcollection
        final requestingInvRef = _firestore
            .collection('stores')
            .doc(order.fromStoreId)
            .collection('inventoryDetails')
            .doc(targetProductId);
        transaction.set(requestingInvRef, {
          'quantity': newStock,
        }, SetOptions(merge: true));
      } else {
        // Product does not exist, copy from supplying store product and create new
        targetProductId = const Uuid().v4();
        final newProductRef = requestingProductsColl.doc(targetProductId);
        
        transaction.set(newProductRef, {
          'id': targetProductId,
          'name': order.productName,
          'barcode': order.productBarcode,
          'brand': order.productBrand,
          'unit': order.productUnit,
          'buyingPrice': order.productBuyingPrice,
          'sellingPrice': order.productSellingPrice,
          'currentStock': quantityReceived,
          'quantity': quantityReceived,
          'minimumStock': 5.0,
          'description': order.productDescription,
          'isArchived': false,
          'isFavorite': false,
          'createdAt': DateTime.now().toIso8601String(),
        });

        // Set inventoryDetails
        final requestingInvRef = _firestore
            .collection('stores')
            .doc(order.fromStoreId)
            .collection('inventoryDetails')
            .doc(targetProductId);
        transaction.set(requestingInvRef, {
          'productId': targetProductId,
          'name': order.productName,
          'quantity': quantityReceived,
          'sellingPrice': order.productSellingPrice,
          'buyingPrice': order.productBuyingPrice,
          'unit': order.productUnit,
          'barcode': order.productBarcode,
        });
      }

      // Create stock history for requesting store
      final requestingHistId = const Uuid().v4();
      final requestingHistRef = _firestore
          .collection('stores')
          .doc(order.fromStoreId)
          .collection('stockHistory')
          .doc(requestingHistId);

      transaction.set(requestingHistRef, {
        'id': requestingHistId,
        'productId': targetProductId,
        'changeAmount': quantityReceived,
        'reason': 'সাপ্লাই চেইন আমদানি',
        'date': Timestamp.now(),
      });

      // 3. Update the order status and values
      final double totalPrice = quantitySent * order.productSellingPrice;
      transaction.update(orderDoc.reference, {
        'quantitySent': quantitySent,
        'quantityReceived': quantityReceived,
        'totalPrice': totalPrice,
        'paymentDue': totalPrice - order.amountPaid,
        'paymentStatus': order.amountPaid >= totalPrice
            ? 'Paid'
            : (order.amountPaid > 0 ? 'Partially Paid' : 'Unpaid'),
        'status': 'Approved',
        'approvedByAdmin': true,
        'approvedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Super Admin: Reject a supply chain request
  Future<void> rejectRequest(String orderId) async {
    await _firestore.collection('supply_chain_orders').doc(orderId).update({
      'status': 'Rejected',
      'updatedAt': Timestamp.now(),
    });
  }
}

final supplyChainServiceProvider = Provider((ref) => SupplyChainService());

class NewRequestState {
  final String selectedBranchDocId;
  final String selectedBranchName;
  final Map<String, dynamic>? selectedProduct;
  final String productSearchQuery;

  NewRequestState({
    this.selectedBranchDocId = '',
    this.selectedBranchName = '',
    this.selectedProduct,
    this.productSearchQuery = '',
  });

  NewRequestState copyWith({
    String? selectedBranchDocId,
    String? selectedBranchName,
    Map<String, dynamic>? selectedProduct,
    bool clearProduct = false,
    String? productSearchQuery,
  }) {
    return NewRequestState(
      selectedBranchDocId: selectedBranchDocId ?? this.selectedBranchDocId,
      selectedBranchName: selectedBranchName ?? this.selectedBranchName,
      selectedProduct: clearProduct ? null : (selectedProduct ?? this.selectedProduct),
      productSearchQuery: productSearchQuery ?? this.productSearchQuery,
    );
  }
}

class NewRequestController extends AutoDisposeNotifier<NewRequestState> {
  @override
  NewRequestState build() => NewRequestState();

  void selectBranch(String docId, String name) {
    state = state.copyWith(
      selectedBranchDocId: docId,
      selectedBranchName: name,
      clearProduct: true,
    );
  }

  void selectProduct(Map<String, dynamic>? product) {
    state = state.copyWith(selectedProduct: product);
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(productSearchQuery: query.trim().toLowerCase());
  }
}

final newRequestControllerProvider =
    AutoDisposeNotifierProvider<NewRequestController, NewRequestState>(NewRequestController.new);
