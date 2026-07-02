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
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';
import 'database.dart';
import 'database_providers.dart';

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

    if (_cachedStoreDocId.isNotEmpty && _cachedStoreDocId.startsWith(baseName)) {
      return {
        'storeDocId': _cachedStoreDocId,
        'shopID': _cachedShopID,
      };
    }

    final directory = await getApplicationDocumentsDirectory();
    final configFile = File(p.join(directory.path, 'shop_config_${baseName}.json'));

    if (await configFile.exists()) {
      try {
        final data = jsonDecode(await configFile.readAsString());
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
        if (id.startsWith('${baseName}_vc')) {
          final suffix = id.substring('${baseName}_vc'.length);
          final num = int.tryParse(suffix);
          if (num != null && num > maxNum) {
            maxNum = num;
          }
        }
      }
      
      if (maxNum > 0) {
        final nextNum = maxNum + 1;
        finalShopID = 'vc${nextNum.toString().padLeft(3, '0')}';
        finalStoreDocId = '${baseName}_$finalShopID';
      }
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

  /// Syncs all database data, including the new unified inventoryDetails field
  Future<void> syncAllData(AppSettingsTableData settings) async {
    final docInfo = await getStoreDocIdAndShopID(settings.shopName);
    final storeDocId = docInfo['storeDocId']!;
    final shopID = docInfo['shopID']!;
    
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
      await storeRef.collection('products').doc(prod.id).set({
        'id': prod.id,
        'name': prod.name,
        'barcode': prod.barcode,
        'categoryId': prod.categoryId,
        'brand': prod.brand,
        'buyingPrice': prod.buyingPrice,
        'sellingPrice': prod.sellingPrice,
        'currentStock': prod.currentStock,
        'minimumStock': prod.minimumStock,
        'unit': prod.unit,
        'supplierId': prod.supplierId,
        'imagePath': prod.imagePath,
        'description': prod.description,
        'isArchived': prod.isArchived,
        'isFavorite': prod.isFavorite,
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

      // Generate the PDF receipt automatically in the background
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

      // Sync the sale document
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

      // Re-sync metadata and the unified inventoryDetails array to reflect updated stock levels
      await syncAllData(settings);
    } catch (e) {
      debugPrint('Background sale sync failed: $e');
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
}

final firebaseSyncServiceProvider = Provider<FirebaseSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return FirebaseSyncService(db);
});
