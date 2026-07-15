import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/database.dart';
import '../../features/supply_chain/supply_chain_controller.dart';

import 'pdf/pdf_helper.dart';
import 'pdf/receipt_pdf.dart';
import 'pdf/profit_loss_pdf.dart';
import 'pdf/daily_report_pdf.dart';
import 'pdf/suppliers_report_pdf.dart';
import 'pdf/supplier_order_pdf.dart';
import 'pdf/damaged_item_pdf.dart';
import 'pdf/supply_chain_order_pdf.dart';

class PdfGenerator {
  // Receipt / POS PDF
  static Future<String?> generateAndSaveTextReceipt({
    required String saleId,
    required String dateStr,
    required String paymentMethod,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
    String? customSavePath,
  }) {
    return ReceiptPdfGenerator.generateAndSaveTextReceipt(
      saleId: saleId,
      dateStr: dateStr,
      paymentMethod: paymentMethod,
      customerName: customerName,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paidAmount: paidAmount,
      customSavePath: customSavePath,
    );
  }

  static Future<void> printTextReceipt({
    required String saleId,
    required String dateStr,
    required String paymentMethod,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
  }) {
    return ReceiptPdfGenerator.printTextReceipt(
      saleId: saleId,
      dateStr: dateStr,
      paymentMethod: paymentMethod,
      customerName: customerName,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paidAmount: paidAmount,
    );
  }

  // Profit & Loss PDF
  static Future<String?> generateAndSaveTextProfitLoss({
    required double todaySales,
    required double inventoryValue,
    required double totalExpenses,
    required double netProfit,
    required double todayExpenses,
    required double todayGrossProfit,
    required double todayNetProfit,
    required double totalSales,
    required double todayCOGS,
    required double totalCOGS,
    required double grossProfit,
    String? customSavePath,
  }) {
    return ProfitLossPdfGenerator.generateAndSaveTextProfitLoss(
      todaySales: todaySales,
      inventoryValue: inventoryValue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      todayExpenses: todayExpenses,
      todayGrossProfit: todayGrossProfit,
      todayNetProfit: todayNetProfit,
      totalSales: totalSales,
      todayCOGS: todayCOGS,
      totalCOGS: totalCOGS,
      grossProfit: grossProfit,
      customSavePath: customSavePath,
    );
  }

  static Future<void> printTextProfitLoss({
    required double todaySales,
    required double inventoryValue,
    required double totalExpenses,
    required double netProfit,
    required double todayExpenses,
    required double todayGrossProfit,
    required double todayNetProfit,
    required double totalSales,
    required double todayCOGS,
    required double totalCOGS,
    required double grossProfit,
  }) {
    return ProfitLossPdfGenerator.printTextProfitLoss(
      todaySales: todaySales,
      inventoryValue: inventoryValue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      todayExpenses: todayExpenses,
      todayGrossProfit: todayGrossProfit,
      todayNetProfit: todayNetProfit,
      totalSales: totalSales,
      todayCOGS: todayCOGS,
      totalCOGS: totalCOGS,
      grossProfit: grossProfit,
    );
  }

  // Daily Report PDF
  static Future<String?> generateAndSaveDailyTransactionReport({
    required double todaySales,
    required double totalExpenses,
    required double netProfit,
    required int totalTransactionsCount,
    required List<Map<String, dynamic>> todaySalesList,
    String? customSavePath,
  }) {
    return DailyReportPdfGenerator.generateAndSaveDailyTransactionReport(
      todaySales: todaySales,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      totalTransactionsCount: totalTransactionsCount,
      todaySalesList: todaySalesList,
      customSavePath: customSavePath,
    );
  }

  // Suppliers Stock & Transaction Report PDF
  static Future<void> printSuppliersReport({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
  }) {
    return SuppliersReportPdfGenerator.printSuppliersReport(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );
  }

  static Future<String?> generateAndSaveSuppliersReport({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
    String? customSavePath,
  }) {
    return SuppliersReportPdfGenerator.generateAndSaveSuppliersReport(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
      customSavePath: customSavePath,
    );
  }

  @visibleForTesting
  static Future<pw.Document> buildSuppliersReportPdfDocumentForTesting({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
  }) {
    return SuppliersReportPdfGenerator.buildSuppliersReportPdfDocumentForTesting(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );
  }

  // Supplier Order Memo PDF
  static Future<String?> generateAndSaveSupplierOrderPdf({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
    String? customSavePath,
  }) {
    return SupplierOrderPdfGenerator.generateAndSaveSupplierOrderPdf(
      order: order,
      supplier: supplier,
      product: product,
      customSavePath: customSavePath,
    );
  }

  static Future<void> printSupplierOrder({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
  }) {
    return SupplierOrderPdfGenerator.printSupplierOrder(
      order: order,
      supplier: supplier,
      product: product,
    );
  }

  // Damaged Item Record PDF
  static Future<String?> generateAndSaveDamagedItemPdf({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
    String? customSavePath,
  }) {
    return DamagedItemPdfGenerator.generateAndSaveDamagedItemPdf(
      damage: damage,
      supplier: supplier,
      product: product,
      customSavePath: customSavePath,
    );
  }

  static Future<void> printDamagedItem({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
  }) {
    return DamagedItemPdfGenerator.printDamagedItem(
      damage: damage,
      supplier: supplier,
      product: product,
    );
  }

  // Branch Supply Chain Order PDF
  static Future<void> printSupplyChainOrder(SupplyChainOrder order) {
    return SupplyChainOrderPdfGenerator.printSupplyChainOrder(order);
  }

  // Directory Helpers
  static Future<Directory> getCsvSaveDirectory(String? customSavePath) {
    return PdfHelper.getCsvSaveDirectory(customSavePath);
  }
}
