import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../features/sales/pos_controller.dart';
import '../../features/settings/settings_controller.dart';
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';
import 'database.dart';
import 'database_providers.dart';
import 'package:drift/drift.dart' as drift;

class FirebaseSyncService {
  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _cachedStoreDocId = '';
  String _cachedShopID = '';

  FirebaseSyncService(this._db);

  /// Dynamic Unique ID generator (with _vc001, _vc002, etc. suffixes)
  Future<Map<String, String>> getStoreDocIdAndShopID(String shopName) async {
    final cleanName = shopName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final baseName = cleanName.isEmpty ? 'defaultinventory' : cleanName;

    if (_cachedStoreDocId.isNotEmpty) {
      return {
        'storeDocId': _cachedStoreDocId,
        'shopID': _cachedShopID,
      };
    }

    final directory = await getApplicationDocumentsDirectory();
    final configFile = File(p.join(directory.path, 'shop_config.json'));
    final legacyConfigFile = File(p.join(directory.path, 'shop_config_${baseName}.json'));
    File? activeConfigFile;

    if (await configFile.exists()) {
      activeConfigFile = configFile;
    } else if (await legacyConfigFile.exists()) {
      activeConfigFile = legacyConfigFile;
      try {
        await legacyConfigFile.copy(configFile.path);
        await legacyConfigFile.delete();
      } catch (_) {}
    } else {
      try {
        final list = directory.listSync();
        for (final entity in list) {
          if (entity is File && p.basename(entity.path).startsWith('shop_config_') && entity.path.endsWith('.json')) {
            activeConfigFile = entity;
            await entity.copy(configFile.path);
            await entity.delete();
            break;
          }
        }
      } catch (_) {}
    }

    if (activeConfigFile != null && await activeConfigFile.exists()) {
      try {
        final data = jsonDecode(await activeConfigFile.readAsString());
        _cachedStoreDocId = data['storeDocId'] ?? '';
        _cachedShopID = data['shopID'] ?? '';
        if (_cachedStoreDocId.isNotEmpty) {
          return {
            'storeDocId': _cachedStoreDocId,
            'shopID': _cachedShopID,
          };
        }
      } catch (_) {}
    }

    // Check online for next dynamic suffix
    String finalShopID = 'vc001';
    String finalStoreDocId = '${baseName}_vc001';

    try {
      final querySnapshot = await _firestore
          .collection('stores')
          .get()
          .timeout(const Duration(seconds: 4));
      
      int maxNum = 0;
      for (final doc in querySnapshot.docs) {
        final id = doc.id;
        final match = RegExp(r'_vc(\d+)$').firstMatch(id);
        if (match != null) {
          final numStr = match.group(1);
          if (numStr != null) {
            final num = int.tryParse(numStr);
            if (num != null && num > maxNum) {
              maxNum = num;
            }
          }
        }
      }
      
      final nextNum = maxNum + 1;
      finalShopID = 'vc${nextNum.toString().padLeft(3, '0')}';
      finalStoreDocId = '${baseName}_$finalShopID';
    } catch (e) {
      debugPrint('Error querying Firestore for unique shop ID suffix (using default): $e');
    }

    // Cache locally
    _cachedStoreDocId = finalStoreDocId;
    _cachedShopID = finalShopID;
    try {
      await configFile.writeAsString(jsonEncode({
        'storeDocId': finalStoreDocId,
        'shopID': finalShopID,
      }));
    } catch (_) {}

    return {
      'storeDocId': finalStoreDocId,
      'shopID': finalShopID,
    };
  }

  /// Reset cache so that when shop name changes, it dynamically regenerates the Store ID.
  void clearIdCache() {
    _cachedStoreDocId = '';
    _cachedShopID = '';
  }

  /// Manually update and write the store config
  Future<void> updateStoreConfig({required String storeDocId, required String shopID}) async {
    _cachedStoreDocId = storeDocId;
    _cachedShopID = shopID;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final configFile = File(p.join(directory.path, 'shop_config.json'));
      await configFile.writeAsString(jsonEncode({
        'storeDocId': storeDocId,
        'shopID': shopID,
      }));
    } catch (e) {
      debugPrint('Error writing store config manually: $e');
    }
  }

  /// Manually delete the store config file and clear memory cache
  Future<void> deleteStoreConfig() async {
    _cachedStoreDocId = '';
    _cachedShopID = '';
    try {
      final directory = await getApplicationDocumentsDirectory();
      final configFile = File(p.join(directory.path, 'shop_config.json'));
      if (await configFile.exists()) {
        await configFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting store config: $e');
    }
  }

  /// Check if store config exists locally
  Future<bool> isStoreConfigured() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final configFile = File(p.join(directory.path, 'shop_config.json'));
      return await configFile.exists();
    } catch (_) {
      return false;
    }
  }


  /// Moves/renames a Firestore store document and all its subcollections.
  Future<void> moveFirestoreStore(String oldDocId, String newDocId) async {
    final oldDocRef = _firestore.collection('stores').doc(oldDocId);
    final newDocRef = _firestore.collection('stores').doc(newDocId);

    final docSnap = await oldDocRef.get();
    if (!docSnap.exists) return;

    // 1. Copy the main document fields
    await newDocRef.set(docSnap.data()!);

    // 2. Copy and delete subcollections in parallel
    final subcollections = [
      'categories',
      'suppliers',
      'customers',
      'products',
      'sales',
      'expenses',
      'stockHistory',
      'supplierOrders',
      'damagedItems',
      'inventoryDetails',
      'reports'
    ];

    final List<Future> subTasks = [];
    for (final sub in subcollections) {
      subTasks.add(() async {
        final snap = await oldDocRef.collection(sub).get();
        final List<Future> docTasks = [];
        for (final doc in snap.docs) {
          docTasks.add(newDocRef.collection(sub).doc(doc.id).set(doc.data()));
          docTasks.add(doc.reference.delete());
        }
        await Future.wait(docTasks);
      }());
    }
    await Future.wait(subTasks);

    // 3. Finally delete the old main document
    await oldDocRef.delete();
  }

  /// Syncs all database data, including the new unified inventoryDetails field
  Future<void> syncAllData(AppSettingsTableData settings) async {
    final docInfo = await getStoreDocIdAndShopID(settings.shopName);
    var storeDocId = docInfo['storeDocId']!;
    var shopID = docInfo['shopID']!;

    // Check if the shop name has changed compared to the name prefix in the document ID
    final cleanNewName = settings.shopName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final newBaseName = cleanNewName.isEmpty ? 'defaultinventory' : cleanNewName;

    String oldBaseName = '';
    String oldShopID = 'vc001';
    final parts = storeDocId.split('_');
    if (parts.length >= 2) {
      oldShopID = parts.last;
      oldBaseName = parts.sublist(0, parts.length - 1).join('_');
    }

    if (oldBaseName.isNotEmpty && oldBaseName != newBaseName) {
      final newStoreDocId = '${newBaseName}_$oldShopID';
      
      String targetStoreDocId = newStoreDocId;
      String targetShopID = oldShopID;

      // Check collision with timeout to prevent hanging when offline
      bool exists = false;
      try {
        final checkSnap = await _firestore
            .collection('stores')
            .doc(newStoreDocId)
            .get()
            .timeout(const Duration(seconds: 3));
        exists = checkSnap.exists;
      } catch (_) {
        // Safe fallback if offline/error
      }

      if (exists) {
        try {
          final querySnapshot = await _firestore
              .collection('stores')
              .get()
              .timeout(const Duration(seconds: 3));
          int maxNum = 0;
          for (final doc in querySnapshot.docs) {
            final id = doc.id;
            final match = RegExp(r'_vc(\d+)$').firstMatch(id);
            if (match != null) {
              final numStr = match.group(1);
              if (numStr != null) {
                final num = int.tryParse(numStr);
                if (num != null && num > maxNum) {
                  maxNum = num;
                }
              }
            }
          }
          final nextNum = maxNum + 1;
          targetShopID = 'vc${nextNum.toString().padLeft(3, '0')}';
          targetStoreDocId = '${newBaseName}_$targetShopID';
        } catch (_) {
          // Safe fallback
        }
      }

      // Rename in Firestore (with timeout to prevent hanging)
      try {
        await moveFirestoreStore(storeDocId, targetStoreDocId).timeout(const Duration(seconds: 8));
        
        // Update local configuration file and cached fields
        await updateStoreConfig(storeDocId: targetStoreDocId, shopID: targetShopID);
        
        storeDocId = targetStoreDocId;
        shopID = targetShopID;
      } catch (e) {
        debugPrint('Firestore store rename failed or timed out: $e. Syncing to old document to prevent block.');
      }
    }
    
    final storeRef = _firestore.collection('stores').doc(storeDocId);

    // Fetch Products
    final products = await _db.select(_db.products).get();

    // 1. Sync store settings (without inventoryDetails field)
    await storeRef.set({
      'shopName': settings.shopName,
      'shopID': shopID,
      'currency': settings.currency,
      'language': settings.language,
      'taxRate': settings.taxRate,
      'adminPin': settings.adminPin,
      'isDarkMode': settings.isDarkMode,
      'lastSyncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 1.5 Sync inventoryDetails subcollection under store
    for (final p in products) {
      final invRef = storeRef.collection('inventoryDetails').doc(p.id);
      if (p.isArchived) {
        await invRef.delete();
      } else {
        await invRef.set({
          'productId': p.id,
          'name': p.name,
          'quantity': p.currentStock,
          'sellingPrice': p.sellingPrice,
          'buyingPrice': p.buyingPrice,
          'unit': p.unit,
          'barcode': p.barcode,
        });
      }
    }

    // 2. Sync Categories
    final categories = await _db.select(_db.categories).get();
    for (final cat in categories) {
      await storeRef.collection('categories').doc(cat.id).set({
        'id': cat.id,
        'name': cat.name,
        'icon': cat.icon,
        'color': cat.color,
      });
    }

    // 3. Sync Suppliers
    final suppliers = await _db.select(_db.suppliers).get();
    for (final sup in suppliers) {
      await storeRef.collection('suppliers').doc(sup.id).set({
        'id': sup.id,
        'name': sup.name,
        'phone': sup.phone,
        'email': sup.email,
        'address': sup.address,
        'imagePath': sup.imagePath,
      });
    }

    // 4. Sync Customers
    final customers = await _db.select(_db.customers).get();
    for (final cust in customers) {
      await storeRef.collection('customers').doc(cust.id).set({
        'id': cust.id,
        'name': cust.name,
        'phone': cust.phone,
        'email': cust.email,
        'address': cust.address,
      });
    }

    // 5. Sync Products
    for (final prod in products) {
      String? firestoreImageUrl = prod.imagePath;

      // If local file path, upload to Firebase Storage first
      if (prod.imagePath != null &&
          prod.imagePath!.isNotEmpty &&
          !prod.imagePath!.startsWith('http://') &&
          !prod.imagePath!.startsWith('https://')) {
        final networkUrl = await uploadProductImage(storeDocId, prod.id, prod.imagePath!);
        if (networkUrl != null) {
          firestoreImageUrl = networkUrl;
          // Update the local database to use the network URL from now on
          await (_db.update(_db.products)..where((p) => p.id.equals(prod.id))).write(
            ProductsCompanion(imagePath: drift.Value(networkUrl)),
          );
        }
      }

      await storeRef.collection('products').doc(prod.id).set({
        'id': prod.id,
        'name': prod.name,
        'barcode': prod.barcode,
        'categoryId': prod.categoryId,
        'brand': prod.brand,
        'buyingPrice': prod.buyingPrice,
        'sellingPrice': prod.sellingPrice,
        'currentStock': prod.currentStock,
        'quantity': prod.currentStock,
        'minimumStock': prod.minimumStock,
        'unit': prod.unit,
        'supplierId': prod.supplierId,
        'imagePath': firestoreImageUrl,
        'description': prod.description,
        'isArchived': prod.isArchived,
        'isFavorite': prod.isFavorite,
        'createdAt': prod.createdAt?.toIso8601String(),
      });
    }

    // 6. Sync Sales & Sale Items
    final sales = await _db.select(_db.sales).get();
    final saleItems = await _db.select(_db.saleItems).get();
    for (final sale in sales) {
      final items = saleItems.where((i) => i.saleId == sale.id).map((i) => {
        'id': i.id,
        'productId': i.productId,
        'quantity': i.quantity,
        'price': i.price,
        'cost': i.cost,
      }).toList();

      // Retrieve existing sale document to preserve PDF receipt URL if already generated
      final saleDoc = await storeRef.collection('sales').doc(sale.id).get();
      String? existingPdfUrl;
      if (saleDoc.exists) {
        try {
          existingPdfUrl = saleDoc.get('receiptPdfUrl') as String?;
        } catch (_) {}
      }

      await storeRef.collection('sales').doc(sale.id).set({
        'id': sale.id,
        'date': Timestamp.fromDate(sale.date),
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'total': sale.total,
        'paymentMethod': sale.paymentMethod,
        'customerId': sale.customerId,
        'items': items,
        if (existingPdfUrl != null) 'receiptPdfUrl': existingPdfUrl,
      }, SetOptions(merge: true));
    }

    // 7. Sync Expenses
    final expenses = await _db.select(_db.expenses).get();
    for (final exp in expenses) {
      await storeRef.collection('expenses').doc(exp.id).set({
        'id': exp.id,
        'name': exp.name,
        'amount': exp.amount,
        'category': exp.category,
        'date': Timestamp.fromDate(exp.date),
        'description': exp.description,
      });
    }

    // 8. Sync StockHistory
    final stockHistory = await _db.select(_db.stockHistory).get();
    for (final hist in stockHistory) {
      await storeRef.collection('stockHistory').doc(hist.id).set({
        'id': hist.id,
        'productId': hist.productId,
        'changeAmount': hist.changeAmount,
        'reason': hist.reason,
        'supplierId': hist.supplierId,
        'date': Timestamp.fromDate(hist.date),
      });
    }

    // 9. Sync SupplierOrders
    final supplierOrders = await _db.select(_db.supplierOrders).get();
    for (final order in supplierOrders) {
      final orderData = {
        'id': order.id,
        'supplierId': order.supplierId,
        'productId': order.productId,
        'quantityOrdered': order.quantityOrdered,
        'quantityReceived': order.quantityReceived,
        'totalCost': order.totalCost,
        'amountPaid': order.amountPaid,
        'date': Timestamp.fromDate(order.date),
        'status': order.status,
        'unitCost': order.unitCost,
        'pdfUrl': order.pdfUrl,
      };
      await storeRef.collection('supplierOrders').doc(order.id).set(orderData, SetOptions(merge: true));
      await storeRef
          .collection('suppliers')
          .doc(order.supplierId)
          .collection('supplierOrders')
          .doc(order.id)
          .set(orderData, SetOptions(merge: true));
    }

    // 10. Sync DamagedItems
    final damagedItems = await _db.select(_db.damagedItems).get();
    for (final dmg in damagedItems) {
      final dmgData = {
        'id': dmg.id,
        'supplierId': dmg.supplierId,
        'productId': dmg.productId,
        'quantity': dmg.quantity,
        'status': dmg.status,
        'date': Timestamp.fromDate(dmg.date),
        'resolutionDate': dmg.resolutionDate != null ? Timestamp.fromDate(dmg.resolutionDate!) : null,
        'notes': dmg.notes,
        'pdfUrl': dmg.pdfUrl,
      };
      await storeRef.collection('damagedItems').doc(dmg.id).set(dmgData, SetOptions(merge: true));
      await storeRef
          .collection('suppliers')
          .doc(dmg.supplierId)
          .collection('damagedItems')
          .doc(dmg.id)
          .set(dmgData, SetOptions(merge: true));
    }
  }

  /// Automatically syncs a single sale, generates and uploads its receipt PDF in the background.
  Future<void> syncSaleOnComplete({
    required Sale sale,
    required List<CartItem> items,
    required double paidAmount,
    required String customerName,
    required AppSettingsTableData settings,
  }) async {
    try {
      final docInfo = await getStoreDocIdAndShopID(settings.shopName);
      final storeDocId = docInfo['storeDocId']!;

      final storeRef = _firestore.collection('stores').doc(storeDocId);

      // 1. Re-sync metadata and the unified inventoryDetails array to reflect updated stock levels for sold items IMMEDIATELY
      final List<String> soldProductIds = items.map((item) => item.product.id).toList();
      await syncProductsStock(soldProductIds, settings);

      // 2. Generate the PDF receipt automatically in the background
      final itemsMappedForPdf = items.map((item) => {
        'name': item.product.name,
        'qty': '${Formatters.number(item.quantity)} ${item.product.unit}',
        'total': Formatters.currency(item.subtotal),
      }).toList();

      final reportPath = await PdfGenerator.generateAndSaveTextReceipt(
        saleId: sale.id,
        dateStr: Formatters.dateTime(sale.date),
        paymentMethod: sale.paymentMethod == 'Cash'
            ? 'ক্যাশ'
            : (sale.paymentMethod == 'Card' ? 'কার্ড' : 'মোবাইল ব্যাংকিং'),
        customerName: customerName,
        items: itemsMappedForPdf,
        subtotal: items.fold(0.0, (sum, i) => sum + i.subtotal),
        discount: sale.discount,
        total: sale.total,
        paidAmount: paidAmount,
        customSavePath: settings.pdfSavePath,
      );

      String? pdfUrl;
      if (reportPath != null) {
        pdfUrl = await uploadReceiptPdf(storeDocId, reportPath);
      }

      // 3. Sync the sale document
      final itemsMappedForFirestore = items.map((item) => {
        'id': const Uuid().v4(),
        'productId': item.product.id,
        'quantity': item.quantity,
        'price': item.customPrice,
        'cost': item.product.buyingPrice,
      }).toList();

      await storeRef.collection('sales').doc(sale.id).set({
        'id': sale.id,
        'date': Timestamp.fromDate(sale.date),
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'total': sale.total,
        'paymentMethod': sale.paymentMethod,
        'customerId': sale.customerId,
        'items': itemsMappedForFirestore,
        'receiptPdfUrl': pdfUrl,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Background sale sync failed: $e');
    }
  }

  /// Syncs only the stock level of specific products to Firestore (fast path)
  Future<void> syncProductsStock(List<String> productIds, AppSettingsTableData settings) async {
    try {
      final docInfo = await getStoreDocIdAndShopID(settings.shopName);
      final storeDocId = docInfo['storeDocId']!;
      final storeRef = _firestore.collection('stores').doc(storeDocId);

      for (final id in productIds) {
        final dbProduct = await (_db.select(_db.products)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (dbProduct != null) {
          // Update in products collection
          await storeRef.collection('products').doc(id).set({
            'currentStock': dbProduct.currentStock,
            'quantity': dbProduct.currentStock,
          }, SetOptions(merge: true));

          // Update in inventoryDetails collection
          await storeRef.collection('inventoryDetails').doc(id).set({
            'quantity': dbProduct.currentStock,
          }, SetOptions(merge: true));
        }
      }
      
      // Update store sync timestamp
      await storeRef.set({
        'lastSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync products stock to Firestore: $e');
      rethrow;
    }
  }


  /// Uploads daily transaction PDF report file to Firebase Storage.
  Future<String?> uploadReportPdf(String storeId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Report PDF file does not exist at path: $localPath');
        return null;
      }
      
      final fileName = p.basename(localPath);
      final ref = _storage.ref().child('stores/$storeId/reports/$fileName');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload daily report PDF: $e');
      return null;
    }
  }

  /// Uploads a receipt PDF file to Firebase Storage.
  Future<String?> uploadReceiptPdf(String storeId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Receipt PDF file does not exist at path: $localPath');
        return null;
      }
      
      final fileName = p.basename(localPath);
      final ref = _storage.ref().child('stores/$storeId/receipts/$fileName');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload receipt PDF: $e');
      return null;
    }
  }

  /// Uploads a product image file to Firebase Storage.
  Future<String?> uploadProductImage(String storeId, String productId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Product image file does not exist at path: $localPath');
        return null;
      }
      final ref = _storage.ref().child('stores/$storeId/products/$productId.jpg');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload product image to Storage: $e');
      return null;
    }
  }

  /// Uploads a supplier profile image file to Firebase Storage.
  Future<String?> uploadSupplierProfilePic(String storeId, String supplierId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Supplier profile pic file does not exist at path: $localPath');
        return null;
      }
      final ref = _storage.ref().child('stores/$storeId/suppliers/$supplierId/profile.jpg');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload supplier profile pic: $e');
      return null;
    }
  }

  /// Uploads a supply order chalan image file to Firebase Storage.
  Future<String?> uploadChalanPic(String storeId, String supplierId, String orderId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Chalan pic file does not exist at path: $localPath');
        return null;
      }
      final ref = _storage.ref().child('stores/$storeId/suppliers/$supplierId/orders/$orderId/chalan.jpg');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload chalan pic: $e');
      return null;
    }
  }

  /// Saves the report metadata and download link inside Firestore `/stores/{storeId}/reports` subcollection.
  Future<void> saveReportMetadata(
    String storeId, {
    required double todaySales,
    required double totalExpenses,
    required double netProfit,
    required int totalTransactionsCount,
    required String? pdfUrl,
    required String reportPath,
  }) async {
    final reportId = p.basenameWithoutExtension(reportPath);
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('reports')
        .doc(reportId)
        .set({
      'id': reportId,
      'title': 'Daily Sales Report',
      'date': Timestamp.now(),
      'todaySales': todaySales,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'totalTransactionsCount': totalTransactionsCount,
      'pdfUrl': pdfUrl,
    });
  }

  /// Pulls the latest products, categories, suppliers, and customers from Firestore and upserts them locally.
  Future<void> pullAndUpsertCatalog(AppSettingsTableData settings) async {
    try {
      final docInfo = await getStoreDocIdAndShopID(settings.shopName).timeout(const Duration(seconds: 4));
      final storeDocId = docInfo['storeDocId']!;
      if (storeDocId.isEmpty) return;

      final docRef = _firestore.collection('stores').doc(storeDocId);

      // Fetch collections from Firestore
      final categoriesSnap = await docRef.collection('categories').get().timeout(const Duration(seconds: 5));
      final suppliersSnap = await docRef.collection('suppliers').get().timeout(const Duration(seconds: 5));
      final customersSnap = await docRef.collection('customers').get().timeout(const Duration(seconds: 5));
      final productsSnap = await docRef.collection('products').get().timeout(const Duration(seconds: 5));

      await _db.transaction(() async {
        // Upsert Categories
        for (var doc in categoriesSnap.docs) {
          final d = doc.data();
          await _db.into(_db.categories).insert(
            CategoriesCompanion(
              id: drift.Value(d['id']),
              name: drift.Value(d['name'] ?? ''),
              icon: drift.Value(d['icon'] ?? 'category'),
              color: drift.Value(d['color'] ?? '0xFF008060'),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }

        // Upsert Suppliers
        for (var doc in suppliersSnap.docs) {
          final d = doc.data();
          await _db.into(_db.suppliers).insert(
            SuppliersCompanion(
              id: drift.Value(d['id']),
              name: drift.Value(d['name'] ?? ''),
              phone: drift.Value(d['phone'] ?? ''),
              email: drift.Value(d['email']),
              address: drift.Value(d['address']),
              imagePath: drift.Value(d['imagePath']),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }

        // Upsert Customers
        for (var doc in customersSnap.docs) {
          final d = doc.data();
          await _db.into(_db.customers).insert(
            CustomersCompanion(
              id: drift.Value(d['id']),
              name: drift.Value(d['name'] ?? ''),
              phone: drift.Value(d['phone'] ?? ''),
              email: drift.Value(d['email']),
              address: drift.Value(d['address']),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }

        // Upsert Products
        for (var doc in productsSnap.docs) {
          final d = doc.data();
          await _db.into(_db.products).insert(
            ProductsCompanion(
              id: drift.Value(d['id']),
              name: drift.Value(d['name'] ?? ''),
              barcode: drift.Value(d['barcode']),
              categoryId: drift.Value(d['categoryId']),
              brand: drift.Value(d['brand']),
              buyingPrice: drift.Value((d['buyingPrice'] as num?)?.toDouble() ?? 0.0),
              sellingPrice: drift.Value((d['sellingPrice'] as num?)?.toDouble() ?? 0.0),
              currentStock: drift.Value((d['currentStock'] as num?)?.toDouble() ?? 0.0),
              minimumStock: drift.Value((d['minimumStock'] as num?)?.toDouble() ?? 0.0),
              unit: drift.Value(d['unit'] ?? 'pcs'),
              supplierId: drift.Value(d['supplierId']),
              imagePath: drift.Value(d['imagePath']),
              description: drift.Value(d['description']),
              isArchived: drift.Value(d['isArchived'] ?? false),
              isFavorite: drift.Value(d['isFavorite'] ?? false),
              createdAt: drift.Value(d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : DateTime.now()),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }
      });
    } catch (e) {
      debugPrint('Failed to pull and upsert catalog from Firestore: $e');
      rethrow;
    }
  }

  Future<String?> uploadSupplierOrderPdf(String storeId, String supplierId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Supplier order PDF file does not exist at path: $localPath');
        return null;
      }
      
      final fileName = p.basename(localPath);
      final ref = _storage.ref().child('stores/$storeId/suppliers/$supplierId/orders/$fileName');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload supplier order PDF: $e');
      return null;
    }
  }

  Future<void> syncSupplierOrderOnComplete({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
    required AppSettingsTableData settings,
  }) async {
    try {
      final docInfo = await getStoreDocIdAndShopID(settings.shopName);
      final storeDocId = docInfo['storeDocId']!;

      // 1. Generate PDF in background
      final localPdfPath = await PdfGenerator.generateAndSaveSupplierOrderPdf(
        order: order,
        supplier: supplier,
        product: product,
        customSavePath: settings.pdfSavePath,
      );

      String? pdfUrl;
      if (localPdfPath != null) {
        // 2. Upload to Firebase Storage
        pdfUrl = await uploadSupplierOrderPdf(storeDocId, supplier.id, localPdfPath);
      }

      // 3. Update pdfUrl locally in SQLite
      if (pdfUrl != null) {
        await (_db.update(_db.supplierOrders)..where((t) => t.id.equals(order.id))).write(
          SupplierOrdersCompanion(pdfUrl: drift.Value(pdfUrl)),
        );
      }

      // 4. Sync to Firestore in BOTH locations
      final storeRef = _firestore.collection('stores').doc(storeDocId);
      final orderData = {
        'id': order.id,
        'supplierId': order.supplierId,
        'productId': order.productId,
        'quantityOrdered': order.quantityOrdered,
        'quantityReceived': order.quantityReceived,
        'totalCost': order.totalCost,
        'amountPaid': order.amountPaid,
        'date': Timestamp.fromDate(order.date),
        'status': order.status,
        'unitCost': order.unitCost,
        'pdfUrl': pdfUrl ?? order.pdfUrl,
        'chalanPic': order.chalanPic,
      };

      // General collection
      await storeRef.collection('supplierOrders').doc(order.id).set(orderData, SetOptions(merge: true));

      // Supplier subcollection
      await storeRef
          .collection('suppliers')
          .doc(supplier.id)
          .collection('supplierOrders')
          .doc(order.id)
          .set(orderData, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Background supplier order sync failed: $e');
    }
  }

  Future<String?> uploadDamagedItemPdf(String storeId, String supplierId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Damaged record PDF file does not exist at path: $localPath');
        return null;
      }
      
      final fileName = p.basename(localPath);
      final ref = _storage.ref().child('stores/$storeId/suppliers/$supplierId/damages/$fileName');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload damaged item PDF: $e');
      return null;
    }
  }

  Future<void> syncDamagedItemOnComplete({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
    required AppSettingsTableData settings,
  }) async {
    try {
      final docInfo = await getStoreDocIdAndShopID(settings.shopName);
      final storeDocId = docInfo['storeDocId']!;

      // 1. Generate PDF in background
      final localPdfPath = await PdfGenerator.generateAndSaveDamagedItemPdf(
        damage: damage,
        supplier: supplier,
        product: product,
        customSavePath: settings.pdfSavePath,
      );

      String? pdfUrl;
      if (localPdfPath != null) {
        // 2. Upload to Firebase Storage
        pdfUrl = await uploadDamagedItemPdf(storeDocId, supplier.id, localPdfPath);
      }

      // 3. Update pdfUrl locally in SQLite
      if (pdfUrl != null) {
        await (_db.update(_db.damagedItems)..where((t) => t.id.equals(damage.id))).write(
          DamagedItemsCompanion(pdfUrl: drift.Value(pdfUrl)),
        );
      }

      // 4. Sync to Firestore in BOTH locations
      final storeRef = _firestore.collection('stores').doc(storeDocId);
      final dmgData = {
        'id': damage.id,
        'supplierId': damage.supplierId,
        'productId': damage.productId,
        'quantity': damage.quantity,
        'status': damage.status,
        'date': Timestamp.fromDate(damage.date),
        'resolutionDate': damage.resolutionDate != null ? Timestamp.fromDate(damage.resolutionDate!) : null,
        'notes': damage.notes,
        'pdfUrl': pdfUrl ?? damage.pdfUrl,
      };

      // General collection
      await storeRef.collection('damagedItems').doc(damage.id).set(dmgData, SetOptions(merge: true));

      // Supplier subcollection
      await storeRef
          .collection('suppliers')
          .doc(supplier.id)
          .collection('damagedItems')
          .doc(damage.id)
          .set(dmgData, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Background damaged item sync failed: $e');
    }
  }
}

final firebaseSyncServiceProvider = Provider<FirebaseSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return FirebaseSyncService(db);
});

void triggerAutoSync(dynamic ref) {
  final AsyncValue<AppSettingsTableData> settingsVal =
      ref.read(settingsControllerProvider) as AsyncValue<AppSettingsTableData>;
  final settings = settingsVal.valueOrNull;
  if (settings != null) {
    ref.read(firebaseSyncServiceProvider).syncAllData(settings).catchError((e) {
      debugPrint('Auto sync failed: $e');
    });
  }
}
